import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/consent.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/rules/streak.dart';
import '../../domain/rules/username.dart';
import 'sync_op.dart';

export '../../domain/rules/streak.dart'
    show nextStreak, nextStreakTick, StreakTick, isoWeekKey;
export '../../domain/rules/username.dart';

/// Offline-first local store: account/profiles/consent, per-child progress and
/// reward balances, and the outbound sync queue. Every learning write lands
/// here first; the [SyncEngine] drains the queue when the API is reachable
/// (docs/15-offline-sync.md).
///
/// Hive keeps this portable across Android/iOS/Web and trivially testable;
/// the drift/SQLite + Firebase-auth upgrade slots in behind this interface.

class OfflineStore {
  OfflineStore._(this._progress, this._queue, this._stats, this._account);

  final Box<String>
  _progress; // 'lesson:<child>:<id>' / 'quiz:<child>:<id>' -> JSON
  final Box<String> _queue; // clientOpId -> SyncOp JSON
  final Box<int> _stats; // 'xp:<child>' -> balance
  final Box<String>
  _account; // onboarding, pin, consent, profiles, active child

  static const _uuid = Uuid();

  static Future<OfflineStore> open({bool inMemory = false}) async {
    Future<Box<T>> openBox<T>(String name) => inMemory
        ? Hive.openBox<T>(name, bytes: Uint8List(0))
        : Hive.openBox<T>(name);
    return OfflineStore._(
      await openBox<String>('progress'),
      await openBox<String>('sync_queue'),
      await openBox<int>('stats'),
      await openBox<String>('account'),
    );
  }

  // ---------------------------------------------------------------- account

  bool get onboardingComplete => _account.get('onboardingComplete') == 'true';

  String? get activeChildId => _account.get('activeChildId');

  Future<void> setActiveChild(String childId) =>
      _account.put('activeChildId', childId);

  /// Persisted UI/content language ('en' | 'fr' | 'sw'), or null before the
  /// family has chosen one. Restored on launch so the app reopens in the
  /// language they picked rather than always defaulting to English.
  String? get localeCode => _account.get('localeCode');

  Future<void> setLocaleCode(String code) => _account.put('localeCode', code);

  /// Stable device id for sync headers (generated once, persisted).
  String get deviceId {
    final existing = _account.get('deviceId');
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    // Fire-and-forget persist; getter stays sync for API construction.
    unawaited(_account.put('deviceId', id));
    return id;
  }

  Future<void> ensureDeviceId() async {
    if (_account.get('deviceId') != null) return;
    await _account.put('deviceId', _uuid.v4());
  }

  /// Last curriculum stage (1–10) the child used. Lets home skip the age
  /// picker on subsequent taps so play starts in one touch.
  int? preferredStage(String childId) {
    final raw = _account.get('preferredStage:$childId');
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setPreferredStage(String childId, int stage) =>
      _account.put('preferredStage:$childId', '$stage');

  /// Bonus XP for finishing today's daily challenge (design doc §12.1: 5).
  static const int dailyChallengeBonusXp = 5;

  /// Whether [childId] already claimed today's daily-challenge bonus.
  bool isDailyChallengeDone(String childId, {DateTime? now}) =>
      _account.get(_dailyDoneKey(childId, now ?? DateTime.now())) != null;

  /// Item id that earned today's daily-challenge bonus, if any.
  String? dailyChallengeCompletedItemId(String childId, {DateTime? now}) =>
      _account.get(_dailyDoneKey(childId, now ?? DateTime.now()));

  /// The pinned target activity for today (stable for the whole day once set).
  String? dailyChallengeTargetId(String childId, {DateTime? now}) =>
      _account.get(_dailyTargetKey(childId, now ?? DateTime.now()));

  /// Pins [itemId] as today's challenge the first time it is resolved.
  Future<void> setDailyChallengeTarget(
    String childId,
    String itemId, {
    DateTime? now,
  }) async {
    final key = _dailyTargetKey(childId, now ?? DateTime.now());
    if (_account.get(key) != null) return;
    await _account.put(key, itemId);
  }

  /// Marks the daily challenge complete and grants bonus XP once per day.
  /// Returns the XP granted (0 if already claimed).
  Future<int> markDailyChallengeDone(
    String childId,
    String itemId, {
    DateTime? now,
  }) async {
    final when = now ?? DateTime.now();
    final key = _dailyDoneKey(childId, when);
    if (_account.get(key) != null) return 0;
    await _account.put(key, itemId);
    // Keep target pinned so the home card stays on the same activity.
    await setDailyChallengeTarget(childId, itemId, now: when);
    await _grantXp(childId, dailyChallengeBonusXp);
    return dailyChallengeBonusXp;
  }

  /// Lifetime count of daily challenges completed (for badges).
  int dailyChallengeTotalCount(String childId) => _account.keys
      .where((k) => (k as String).startsWith('dailyDone:$childId:'))
      .length;

  String _dailyDoneKey(String childId, DateTime now) =>
      'dailyDone:$childId:${_dayKey(now)}';

  String _dailyTargetKey(String childId, DateTime now) =>
      'dailyTarget:$childId:${_dayKey(now)}';

  bool get hasPin => _account.get('pinHash') != null;

  /// Local parent gate. A salted SHA-256 keeps the PIN out of plaintext on
  /// device; the production design uses argon2id server-side (docs/16 §16.1).
  /// Soft gate only — not high-security authentication.
  Future<void> setPin(String pin) async {
    await _account.put('pinSalt', _uuid.v4());
    await _account.put('pinHash', _hashPin(pin));
    await clearPinFailures();
  }

  bool verifyPin(String pin) =>
      hasPin && _hashPin(pin) == _account.get('pinHash');

  /// Max wrong PIN tries before a temporary lockout.
  static const int pinMaxAttempts = 5;

  /// Lockout duration after [pinMaxAttempts] failures.
  static const Duration pinLockoutDuration = Duration(minutes: 2);

  int get pinFailCount =>
      int.tryParse(_account.get('pinFailCount') ?? '') ?? 0;

  DateTime? get pinLockedUntil {
    final raw = _account.get('pinLockedUntil');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool get isPinLocked {
    final until = pinLockedUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  Duration? get pinLockRemaining {
    final until = pinLockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  Future<void> clearPinFailures() async {
    await _account.delete('pinFailCount');
    await _account.delete('pinLockedUntil');
  }

  /// Verifies PIN with lockout. Returns:
  /// - `ok` on success
  /// - `wrong` on bad PIN (increments fail count)
  /// - `locked` when still in lockout window
  Future<String> tryPin(String pin) async {
    if (isPinLocked) return 'locked';
    // Clear expired lockout.
    if (pinLockedUntil != null && !isPinLocked) {
      await clearPinFailures();
    }
    if (verifyPin(pin)) {
      await clearPinFailures();
      return 'ok';
    }
    final fails = pinFailCount + 1;
    await _account.put('pinFailCount', '$fails');
    if (fails >= pinMaxAttempts) {
      final until = DateTime.now().add(pinLockoutDuration);
      await _account.put('pinLockedUntil', until.toIso8601String());
    }
    return isPinLocked ? 'locked' : 'wrong';
  }

  String _hashPin(String pin) {
    final salt = _account.get('pinSalt') ?? '';
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  // ----- parent account (local; a Firebase-backed AuthService swaps in later) -

  /// A local parent account is an alternative to the PIN: families who create
  /// one are never asked for a PIN. Single-device model for now — the password
  /// is salted-SHA-256 hashed (same caveat as the PIN; argon2id server-side).
  bool get hasAccount => _account.get('accountEmail') != null;

  String? get accountEmail => _account.get('accountEmail');

  /// Whether a parent session is currently active (persisted across launches).
  bool get isLoggedIn => _account.get('loggedIn') == 'true';

  Future<void> createAccount(String email, String password) async {
    await _account.put('accountEmail', email.trim().toLowerCase());
    await _account.put('accountSalt', _uuid.v4());
    await _account.put('accountHash', _hashAccount(password));
    await _account.put('loggedIn', 'true');
  }

  bool verifyAccount(String password) =>
      hasAccount && _hashAccount(password) == _account.get('accountHash');

  /// Starts a session when [email]/[password] match the local account.
  Future<bool> signIn(String email, String password) async {
    if (email.trim().toLowerCase() != (accountEmail ?? '').toLowerCase()) {
      return false;
    }
    if (!verifyAccount(password)) return false;
    await _account.put('loggedIn', 'true');
    return true;
  }

  Future<void> signOut() => _account.put('loggedIn', 'false');

  String _hashAccount(String password) {
    final salt = _account.get('accountSalt') ?? '';
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  /// Password reset codes expire after 1 hour.
  static const Duration passwordResetTtl = Duration(hours: 1);

  /// Begins a local password reset: stores a hashed one-time code and returns
  /// the plain code for the reset email body. Throws if email is unknown.
  Future<String> beginPasswordReset(String email) async {
    final registered = (accountEmail ?? '').toLowerCase();
    if (!hasAccount || email.trim().toLowerCase() != registered) {
      throw StateError('No account for that email on this device.');
    }
    final code = _sixDigitCode();
    final salt = _uuid.v4();
    final hash = sha256.convert(utf8.encode('$salt:$code')).toString();
    final exp =
        DateTime.now().toUtc().add(passwordResetTtl).toIso8601String();
    await _account.put('pwResetSalt', salt);
    await _account.put('pwResetHash', hash);
    await _account.put('pwResetExp', exp);
    await _account.put('pwResetEmail', registered);
    return code;
  }

  /// Completes local password reset when [code] matches a non-expired token.
  Future<void> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw StateError('Password too short.');
    }
    final registered = (accountEmail ?? '').toLowerCase();
    final target = email.trim().toLowerCase();
    if (!hasAccount || target != registered) {
      throw StateError('Invalid reset request.');
    }
    if ((_account.get('pwResetEmail') ?? '') != registered) {
      throw StateError('Invalid or expired reset code.');
    }
    final expRaw = _account.get('pwResetExp');
    final exp = expRaw == null ? null : DateTime.tryParse(expRaw);
    if (exp == null || exp.isBefore(DateTime.now().toUtc())) {
      await _clearPasswordReset();
      throw StateError('Reset code expired. Request a new one.');
    }
    final salt = _account.get('pwResetSalt') ?? '';
    final expected = _account.get('pwResetHash');
    final got = sha256.convert(utf8.encode('$salt:$code')).toString();
    if (expected == null || got != expected) {
      throw StateError('Invalid reset code.');
    }
    await _account.put('accountSalt', _uuid.v4());
    await _account.put('accountHash', _hashAccount(newPassword));
    await _clearPasswordReset();
  }

  Future<void> _clearPasswordReset() async {
    await _account.delete('pwResetSalt');
    await _account.delete('pwResetHash');
    await _account.delete('pwResetExp');
    await _account.delete('pwResetEmail');
  }

  String _sixDigitCode() {
    final n = DateTime.now().microsecondsSinceEpoch ^ _uuid.v4().hashCode;
    final code = (n.abs() % 1000000).toString().padLeft(6, '0');
    return code;
  }

  /// Sets a new parent PIN after the caller has verified adult authority
  /// (password and/or parent gate).
  Future<void> resetPin(String newPin) async {
    final digits = newPin.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4 || digits.length > 6) {
      throw StateError('PIN must be 4–6 digits.');
    }
    await setPin(digits);
  }

  /// Resets PIN only when the current account password is correct.
  Future<void> resetPinWithPassword({
    required String password,
    required String newPin,
  }) async {
    if (!verifyAccount(password)) {
      throw StateError('Wrong password.');
    }
    await resetPin(newPin);
  }

  // ------------------------------------------------------------- settings

  /// App-wide text-size multiplier layered on top of the OS text scale, so
  /// families can enlarge everything for young or low-vision readers. 1.0 =
  /// default; the accessibility control offers 1.0 / 1.3 / 1.6.
  double get textScale =>
      double.tryParse(_account.get('textScale') ?? '') ?? 1.0;

  Future<void> setTextScale(double scale) =>
      _account.put('textScale', scale.toString());

  /// Whether spoken narration (TTS) is on. Default on — the 0–5 band is
  /// audio-first, so pre-readers depend on it.
  bool get narrationEnabled => _account.get('narrationEnabled') != 'false';

  Future<void> setNarrationEnabled(bool enabled) =>
      _account.put('narrationEnabled', enabled ? 'true' : 'false');

  /// Reading-ease mode: larger letter-spacing + line height (no extra font asset).
  bool get dyslexiaFriendly => _account.get('dyslexiaFriendly') == 'true';

  Future<void> setDyslexiaFriendly(bool v) =>
      _account.put('dyslexiaFriendly', v ? 'true' : 'false');

  /// High-contrast theme tokens for low-vision readers.
  bool get highContrast => _account.get('highContrast') == 'true';

  Future<void> setHighContrast(bool v) =>
      _account.put('highContrast', v ? 'true' : 'false');

  /// Prefer reduced motion (mascot idle, celebrations).
  bool get reducedMotion => _account.get('reducedMotion') == 'true';

  Future<void> setReducedMotion(bool v) =>
      _account.put('reducedMotion', v ? 'true' : 'false');

  /// Parent opt-in for privacy-preserving product analytics (default off).
  bool get analyticsOptIn => _account.get('analyticsOptIn') == 'true';

  Future<void> setAnalyticsOptIn(bool v) =>
      _account.put('analyticsOptIn', v ? 'true' : 'false');

  ConsentRecord get consent {
    final raw = _account.get('consent');
    if (raw == null) return ConsentRecord.empty;
    return ConsentRecord.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  Future<void> saveConsent(ConsentRecord consent) =>
      _account.put('consent', jsonEncode(consent.toJson()));

  List<ChildProfile> get children {
    return _account.keys
        .where((k) => (k as String).startsWith('child:'))
        .map(
          (k) => ChildProfile.fromJson(
            (jsonDecode(_account.get(k)!) as Map).cast<String, dynamic>(),
          ),
        )
        .toList()
      ..sort(
        (a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
      );
  }

  ChildProfile? childById(String id) {
    final raw = _account.get('child:$id');
    if (raw == null) return null;
    return ChildProfile.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  Future<ChildProfile> addChild({
    required String nickname,
    required String avatarKey,
    required int birthYear,
  }) async {
    final child = ChildProfile(
      id: _uuid.v4(),
      nickname: nickname,
      avatarKey: avatarKey,
      birthYear: birthYear,
      ageBand: ageBandForBirthYear(birthYear),
      // Null until first rename — parents may fix the initial nickname once.
    );
    await _account.put('child:${child.id}', jsonEncode(child.toJson()));
    return child;
  }

  Future<void> updateChild(ChildProfile child) =>
      _account.put('child:${child.id}', jsonEncode(child.toJson()));

  /// Renames a child profile if the 90-day cooldown has elapsed.
  /// Returns the updated profile. Throws [StateError] when blocked.
  Future<ChildProfile> updateChildNickname({
    required String childId,
    required String nickname,
    DateTime? now,
  }) async {
    final child = childById(childId);
    if (child == null) throw StateError('Child not found.');
    final name = nickname.trim();
    if (name.isEmpty) throw StateError('Nickname required.');
    if (name == child.nickname) return child;
    final when = now ?? DateTime.now().toUtc();
    if (!canChangeNickname(child.nicknameChangedAt, now: when)) {
      final days =
          nicknameCooldownDaysRemaining(child.nicknameChangedAt, now: when);
      throw StateError('Nickname can be changed again in $days days.');
    }
    final updated = child.copyWith(
      nickname: name,
      nicknameChangedAt: when,
    );
    await updateChild(updated);
    return updated;
  }

  /// Whether the parent may edit this child's nickname now.
  bool canEditChildNickname(String childId, {DateTime? now}) {
    final child = childById(childId);
    if (child == null) return false;
    return canChangeNickname(child.nicknameChangedAt, now: now);
  }

  /// Persists the full first-run result atomically enough for local use:
  /// consent, a parent gate (a PIN *or* a local account), first child, then
  /// marks onboarding complete + active child. Exactly one of [pin] /
  /// ([accountEmail] + [accountPassword]) is expected.
  Future<ChildProfile> completeOnboarding({
    required ConsentRecord consent,
    String? pin,
    String? accountEmail,
    String? accountPassword,
    required String nickname,
    required String avatarKey,
    required int birthYear,
  }) async {
    await saveConsent(consent);
    if (pin != null && pin.isNotEmpty) await setPin(pin);
    if (accountEmail != null && accountPassword != null) {
      await createAccount(accountEmail, accountPassword);
    }
    final child = await addChild(
      nickname: nickname,
      avatarKey: avatarKey,
      birthYear: birthYear,
    );
    await setActiveChild(child.id);
    await _account.put('onboardingComplete', 'true');
    return child;
  }

  // --------------------------------------------------------------- learning

  int xpFor(String childId) => _stats.get('xp:$childId', defaultValue: 0)!;

  /// Consecutive days [childId] has learned (today or yesterday keeps the run
  /// alive; a longer gap resets it). Surfaced on the home 🔥 pill.
  int streakFor(String childId) =>
      _stats.get('streak:$childId', defaultValue: 0)!;

  /// Records that [childId] was active "today" and rolls the streak forward.
  /// Called from every learning write; idempotent within a calendar day.
  /// Uses one free weekly **streak shield** if the child missed exactly one day.
  Future<void> _touchStreak(String childId, DateTime now) async {
    final todayKey = _dayKey(now);
    final lastKey = _account.get('streakDate:$childId');
    if (lastKey == todayKey) return; // already counted today
    final week = isoWeekKey(now);
    final shieldUsedThisWeek =
        _account.get('streakShieldWeek:$childId') == week;
    final tick = nextStreakTick(
      lastDayKey: lastKey,
      todayKey: todayKey,
      yesterdayKey: _dayKey(now.subtract(const Duration(days: 1))),
      dayBeforeYesterdayKey:
          _dayKey(now.subtract(const Duration(days: 2))),
      current: streakFor(childId),
      shieldAvailable: !shieldUsedThisWeek,
    );
    await _stats.put('streak:$childId', tick.streak);
    await _account.put('streakDate:$childId', todayKey);
    if (tick.usedShield) {
      await _account.put('streakShieldWeek:$childId', week);
      await _account.put('streakShieldUsedAt:$childId', todayKey);
      _shieldJustUsed = true;
    }
  }

  /// Set when the last learning write spent the weekly shield to cover a
  /// missed day. Silently rescuing a streak wastes the best moment the streak
  /// system has, so the reward pipeline reads this and tells the child.
  bool _shieldJustUsed = false;

  /// Reads *and clears* the "a shield just saved this run" flag.
  bool takeShieldJustUsed() {
    final used = _shieldJustUsed;
    _shieldJustUsed = false;
    return used;
  }

  /// True if a streak shield already protected this child in the current ISO week.
  bool streakShieldUsedThisWeek(String childId, {DateTime? now}) {
    final week = isoWeekKey(now ?? DateTime.now());
    return _account.get('streakShieldWeek:$childId') == week;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic>? progressFor(String childId, String lessonId) =>
      _read('lesson:$childId:$lessonId');

  Map<String, dynamic>? lastQuizAttempt(String childId, String quizId) =>
      _read('quiz:$childId:$quizId');

  bool hasReadStory(String childId, String storyId) =>
      _read('story:$childId:$storyId') != null;

  Map<String, dynamic>? _read(String key) {
    final raw = _progress.get(key);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  /// Queued ops, oldest first.
  List<SyncOp> get pendingOps {
    final ops = _queue.values
        .map(
          (raw) =>
              SyncOp.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>()),
        )
        .toList();
    ops.sort((a, b) => a.clientUpdatedAt.compareTo(b.clientUpdatedAt));
    return ops;
  }

  /// Records a lesson completion for [childId] and enqueues the sync op.
  Future<void> recordLessonCompleted({
    required String childId,
    required String lessonId,
    required int scorePct,
    required int timeSpentS,
    required int xpEarned,
  }) async {
    final now = DateTime.now().toUtc();
    await _progress.put(
      'lesson:$childId:$lessonId',
      jsonEncode({
        'lessonId': lessonId,
        'status': 'completed',
        'scorePct': scorePct,
        'timeSpentS': timeSpentS,
        'clientUpdatedAt': now.toIso8601String(),
      }),
    );
    await _grantXp(childId, xpEarned);
    await _touchStreak(childId, DateTime.now());
    await _enqueue(
      SyncOp(
        clientOpId: _uuid.v4(),
        opType: 'lesson_progress',
        payload: {
          'lessonId': lessonId,
          'status': 'completed',
          'scorePct': scorePct,
          'timeSpentS': timeSpentS,
        },
        clientUpdatedAt: now,
      ),
    );
  }

  /// Records a quiz attempt (pass or fail — attempts are data) and enqueues
  /// it for server-side authoritative re-grading. [stars] is 0–3 quality.
  Future<void> recordQuizAttempt({
    required String childId,
    required String quizId,
    required int scorePct,
    required bool passed,
    required List<Map<String, dynamic>> answers,
    required int durationS,
    required int xpEarned,
    int stars = 0,
  }) async {
    final now = DateTime.now().toUtc();
    final prev = lastQuizAttempt(childId, quizId);
    final prevStars = (prev?['stars'] as int?) ?? 0;
    final bestStars = stars > prevStars ? stars : prevStars;
    await _progress.put(
      'quiz:$childId:$quizId',
      jsonEncode({
        'quizId': quizId,
        'scorePct': scorePct,
        'passed': passed,
        'stars': bestStars,
        'attemptedAt': now.toIso8601String(),
      }),
    );
    final delta = bestStars - prevStars;
    if (delta > 0) {
      await _stats.put('stars:$childId', totalStars(childId) + delta);
    }
    await _grantXp(childId, xpEarned);
    await _touchStreak(childId, DateTime.now());
    await _enqueue(
      SyncOp(
        clientOpId: _uuid.v4(),
        opType: 'quiz_attempt',
        payload: {
          'quizId': quizId,
          'answers': answers,
          'durationS': durationS,
          'scorePct': scorePct,
          'passed': passed,
          'stars': bestStars,
        },
        clientUpdatedAt: now,
      ),
    );
  }

  /// Records that [childId] finished reading [storyId] (idempotent on the
  /// key; XP is granted only the first time) and enqueues the sync op.
  Future<void> recordStoryRead({
    required String childId,
    required String storyId,
    required int xpEarned,
  }) async {
    if (hasReadStory(childId, storyId)) return; // already read — no double XP
    final now = DateTime.now().toUtc();
    await _progress.put(
      'story:$childId:$storyId',
      jsonEncode({'storyId': storyId, 'readAt': now.toIso8601String()}),
    );
    await _grantXp(childId, xpEarned);
    await _touchStreak(childId, DateTime.now());
    await _enqueue(
      SyncOp(
        clientOpId: _uuid.v4(),
        opType: 'story_read',
        payload: {'storyId': storyId},
        clientUpdatedAt: now,
      ),
    );
  }

  /// Counts for the parent dashboard.
  int completedLessonCount(String childId) => _progress.keys
      .where((k) => (k as String).startsWith('lesson:$childId:'))
      .length;

  int completedStoryCount(String childId) => _progress.keys
      .where((k) => (k as String).startsWith('story:$childId:'))
      .length;

  /// True when the child has finished a library item of any type (used by the
  /// daily challenge and "continue learning" surfaces).
  bool hasCompletedLibraryItem(String childId, String itemId, String type) {
    switch (type) {
      case 'lesson':
        return progressFor(childId, itemId) != null;
      case 'quiz':
        return lastQuizAttempt(childId, itemId) != null;
      case 'story':
        return hasReadStory(childId, itemId);
      default:
        return false;
    }
  }

  /// Flattened progress rows for weekly parent snapshots.
  List<({String kind, DateTime? at, int? timeSpentS, int? stars})>
      progressEntriesFor(String childId) {
    final out =
        <({String kind, DateTime? at, int? timeSpentS, int? stars})>[];
    for (final key in _progress.keys) {
      final k = key as String;
      if (!k.contains(':$childId:')) continue;
      final m = _read(k);
      if (m == null) continue;
      DateTime? at;
      for (final field in ['clientUpdatedAt', 'attemptedAt', 'readAt']) {
        final raw = m[field] as String?;
        if (raw != null) {
          at = DateTime.tryParse(raw)?.toLocal();
          break;
        }
      }
      if (k.startsWith('lesson:')) {
        out.add((
          kind: 'lesson',
          at: at,
          timeSpentS: m['timeSpentS'] as int?,
          stars: null,
        ));
      } else if (k.startsWith('quiz:')) {
        out.add((
          kind: 'quiz',
          at: at,
          timeSpentS: null,
          stars: m['stars'] as int?,
        ));
      } else if (k.startsWith('story:')) {
        out.add((kind: 'story', at: at, timeSpentS: null, stars: null));
      }
    }
    return out;
  }

  // --------------------------------------------------------------- tour / badges

  /// First-session guided tour not yet finished for this child.
  bool needsGuidedTour(String childId) =>
      _account.get('tourDone:$childId') != 'true';

  Future<void> markGuidedTourDone(String childId) =>
      _account.put('tourDone:$childId', 'true');

  /// Whether home should open the "Let's play!" tour card once.
  bool tourPromptPending(String childId) =>
      needsGuidedTour(childId) &&
      _account.get('tourPrompted:$childId') != 'true';

  Future<void> markTourPrompted(String childId) =>
      _account.put('tourPrompted:$childId', 'true');

  Set<String> seenBadgeIds(String childId) {
    final raw = _account.get('seenBadges:$childId');
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Future<void> markBadgesSeen(String childId, Iterable<String> ids) async {
    final set = seenBadgeIds(childId)..addAll(ids);
    await _account.put('seenBadges:$childId', set.join(','));
  }

  int lastKnownLevel(String childId) =>
      _stats.get('lastLevel:$childId', defaultValue: 1)!;

  Future<void> setLastKnownLevel(String childId, int level) =>
      _stats.put('lastLevel:$childId', level);

  Future<void> _grantXp(String childId, int amount) async {
    if (amount > 0) await _stats.put('xp:$childId', xpFor(childId) + amount);
  }

  // ------------------------------------------------------------ reminders

  /// Practice reminders. **Off unless a grown-up turns them on** — docs/12
  /// §12.6 forbids pushing anything to a child, so these are parent-facing
  /// and opt-in, never a default.
  bool get remindersEnabled => _account.get('remindersEnabled') == 'true';

  Future<void> setRemindersEnabled(bool on) =>
      _account.put('remindersEnabled', on ? 'true' : 'false');

  /// Local wall-clock hour for the daily reminder (default early evening).
  int get reminderHour =>
      int.tryParse(_account.get('reminderHour') ?? '') ?? 18;

  int get reminderMinute =>
      int.tryParse(_account.get('reminderMinute') ?? '') ?? 30;

  Future<void> setReminderTime(int hour, int minute) async {
    await _account.put('reminderHour', '${hour.clamp(0, 23)}');
    await _account.put('reminderMinute', '${minute.clamp(0, 59)}');
  }

  /// The last day [childId] finished anything, as 'yyyy-MM-dd', or null.
  String? lastActiveDayKey(String childId) =>
      _account.get('streakDate:$childId');

  // ------------------------------------------------------------- subjects

  /// Subjects this child has finished at least one activity in.
  ///
  /// Progress rows are keyed by item id only, so "have they been here before?"
  /// is not answerable from them — this keeps a small explicit set instead.
  Set<String> completedSubjects(String childId) {
    final raw = _account.get('subjects:$childId');
    if (raw == null || raw.isEmpty) return const {};
    return raw.split('\n').where((s) => s.isNotEmpty).toSet();
  }

  bool hasCompletedAnyInSubject(String childId, String subject) =>
      completedSubjects(childId).contains(subject);

  Future<void> markSubjectCompleted(String childId, String subject) async {
    if (subject.isEmpty) return;
    final set = {...completedSubjects(childId), subject};
    await _account.put('subjects:$childId', set.join('\n'));
  }

  // --------------------------------------------------------------- coins

  int coinsFor(String childId) =>
      _stats.get('coins:$childId', defaultValue: 0)!;

  int coinsEarnedToday(String childId, {DateTime? now}) {
    final day = _dayKey(now ?? DateTime.now());
    if (_account.get('coinsDay:$childId') != day) return 0;
    return _stats.get('coinsToday:$childId', defaultValue: 0)!;
  }

  /// Grants [amount] coins subject to the daily cap. Returns coins actually
  /// granted.
  Future<int> grantCoins(
    String childId,
    int amount, {
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final when = now ?? DateTime.now();
    final day = _dayKey(when);
    if (_account.get('coinsDay:$childId') != day) {
      await _account.put('coinsDay:$childId', day);
      await _stats.put('coinsToday:$childId', 0);
    }
    final earned = coinsEarnedToday(childId, now: when);
    final room = 30 - earned; // matches economy.dailyCoinCap
    if (room <= 0) return 0;
    final grant = amount > room ? room : amount;
    await _stats.put('coins:$childId', coinsFor(childId) + grant);
    await _stats.put('coinsToday:$childId', earned + grant);
    return grant;
  }

  Future<bool> spendCoins(String childId, int amount) async {
    if (amount <= 0) return true;
    final bal = coinsFor(childId);
    if (bal < amount) return false;
    await _stats.put('coins:$childId', bal - amount);
    return true;
  }

  // --------------------------------------------------------------- avatars

  Set<String> unlockedAvatars(String childId) {
    final raw = _account.get('avatars:$childId');
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Future<void> unlockAvatar(String childId, String key) async {
    final set = unlockedAvatars(childId)..add(key);
    await _account.put('avatars:$childId', set.join(','));
  }

  bool isAvatarUnlocked(String childId, String key) =>
      unlockedAvatars(childId).contains(key);

  // ---------------------------------------------------- savanna decorations

  /// Decorations this child has bought with coins. Earned decorations are
  /// derived from progress and are not stored.
  Set<String> unlockedDecorations(String childId) {
    final raw = _account.get('decor:$childId');
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Future<void> unlockDecoration(String childId, String key) async {
    final set = unlockedDecorations(childId)..add(key);
    await _account.put('decor:$childId', set.join(','));
  }

  bool isDecorationUnlocked(String childId, String key) =>
      unlockedDecorations(childId).contains(key);

  // ---------------------------------------------------------------- cheers

  /// A cheer a grown-up left for this child, as 'kind|iso8601', or null.
  /// Read by the child's home screen and cleared once seen.
  String? pendingCheer(String childId) => _account.get('cheer:$childId');

  Future<void> sendCheer(String childId, String encoded) =>
      _account.put('cheer:$childId', encoded);

  Future<void> clearCheer(String childId) =>
      _account.delete('cheer:$childId');

  // ---------------------------------------------------------------- mascot

  /// The name the child gave their companion, or null while it is still just
  /// "the lion". A named companion is a relationship; an unnamed one is a
  /// decoration.
  String? mascotName(String childId) {
    final raw = _account.get('mascotName:$childId');
    return (raw == null || raw.trim().isEmpty) ? null : raw;
  }

  Future<void> setMascotName(String childId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      await _account.delete('mascotName:$childId');
      return;
    }
    // Same ceiling as a child nickname — long enough to be theirs, short
    // enough to fit a speech bubble.
    await _account.put(
      'mascotName:$childId',
      clean.length > 16 ? clean.substring(0, 16) : clean,
    );
  }

  // --------------------------------------------------------------- stars

  int totalStars(String childId) =>
      _stats.get('stars:$childId', defaultValue: 0)!;

  /// Best star rating recorded for a quiz (0–3).
  int starsForQuiz(String childId, String quizId) {
    final m = lastQuizAttempt(childId, quizId);
    if (m == null) return 0;
    return (m['stars'] as int?) ?? 0;
  }

  // --------------------------------------------------------------- continue

  /// Last library item the child opened/finished: {itemId, stage, subject}.
  Map<String, dynamic>? lastPlayed(String childId) {
    final raw = _account.get('lastPlayed:$childId');
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  Future<void> setLastPlayed({
    required String childId,
    required String itemId,
    required int stage,
    required String subject,
  }) =>
      _account.put(
        'lastPlayed:$childId',
        jsonEncode({
          'itemId': itemId,
          'stage': stage,
          'subject': subject,
        }),
      );

  // --------------------------------------------------------------- screen time

  /// Daily limit in minutes; 0 = unlimited (default).
  int screenTimeLimitMinutes() {
    final raw = _account.get('screenTimeLimit');
    return raw == null ? 0 : int.tryParse(raw) ?? 0;
  }

  Future<void> setScreenTimeLimitMinutes(int minutes) =>
      _account.put('screenTimeLimit', '${minutes < 0 ? 0 : minutes}');

  /// Seconds of learning time used today (all children, family device).
  int screenTimeUsedSeconds({DateTime? now}) {
    final day = _dayKey(now ?? DateTime.now());
    if (_account.get('screenTimeDay') != day) return 0;
    return _stats.get('screenTimeUsed', defaultValue: 0)!;
  }

  Future<void> addScreenTimeSeconds(int seconds, {DateTime? now}) async {
    if (seconds <= 0) return;
    final when = now ?? DateTime.now();
    final day = _dayKey(when);
    if (_account.get('screenTimeDay') != day) {
      await _account.put('screenTimeDay', day);
      await _stats.put('screenTimeUsed', 0);
    }
    await _stats.put(
      'screenTimeUsed',
      screenTimeUsedSeconds(now: when) + seconds,
    );
  }

  /// Soft-lock when a limit is set and today's usage is at/over it.
  bool isScreenTimeExceeded({DateTime? now}) {
    final limit = screenTimeLimitMinutes();
    if (limit <= 0) return false;
    return screenTimeUsedSeconds(now: now) >= limit * 60;
  }

  /// Parent grants a 10-minute grace extension (adds to limit for the day via
  /// reducing used time, or bumping a one-shot extension counter).
  Future<void> grantScreenTimeGrace({int minutes = 10}) async {
    final used = screenTimeUsedSeconds();
    final reduce = minutes * 60;
    await _stats.put(
      'screenTimeUsed',
      used > reduce ? used - reduce : 0,
    );
  }

  // --------------------------------------------------------------- premium

  /// Local entitlement mirror (sandbox + offline). Real source of truth is
  /// the Firebase account doc once payments are live.
  bool get hadPremiumBefore => _account.get('hadPremium') == 'true';

  /// Current entitlement from local storage.
  /// Import cycle avoided: returns a simple record consumed by entitlements.dart.
  ({String plan, DateTime? expiry, bool isPremium}) get entitlementRaw {
    final plan = _account.get('plan') ?? 'free';
    final expRaw = _account.get('entitlementExpiry');
    DateTime? exp;
    if (expRaw != null) exp = DateTime.tryParse(expRaw);
    final premium = plan == 'premium' &&
        (exp == null || exp.isAfter(DateTime.now()));
    return (plan: premium ? 'premium' : 'free', expiry: exp, isPremium: premium);
  }

  Future<void> setLocalPremium(
    bool premium, {
    DateTime? expiry,
    String source = 'local',
  }) async {
    if (premium) {
      await _account.put('plan', 'premium');
      await _account.put(
        'entitlementExpiry',
        (expiry ?? DateTime.now().add(const Duration(days: 30)))
            .toIso8601String(),
      );
      await _account.put('hadPremium', 'true');
      await _account.put('premiumSource', source);
    } else {
      await _account.put('plan', 'free');
      await _account.delete('entitlementExpiry');
    }
  }

  // --------------------------------------------------------------- adaptive

  /// Append a graded attempt for adaptive difficulty (capped list in JSON).
  Future<void> recordAttemptOutcome({
    required String childId,
    required int scorePct,
    required int retries,
  }) async {
    final key = 'attempts:$childId';
    final raw = _account.get(key);
    final list = <Map<String, dynamic>>[];
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) list.add(e.cast<String, dynamic>());
        }
      }
    }
    list.add({
      'scorePct': scorePct,
      'retries': retries,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    while (list.length > 20) {
      list.removeAt(0);
    }
    await _account.put(key, jsonEncode(list));
  }

  List<({int scorePct, int retries, DateTime at})> attemptHistory(
    String childId,
  ) {
    final raw = _account.get('attempts:$childId');
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <({int scorePct, int retries, DateTime at})>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      final at = DateTime.tryParse(m['at'] as String? ?? '');
      if (at == null) continue;
      out.add((
        scorePct: (m['scorePct'] as num?)?.toInt() ?? 0,
        retries: (m['retries'] as num?)?.toInt() ?? 0,
        at: at,
      ));
    }
    return out;
  }

  /// Adaptive history as [AttemptOutcome]-compatible records (score/retries/at).
  List<({int scorePct, int retries, DateTime at})> recentAttemptOutcomes(
    String childId,
  ) =>
      attemptHistory(childId);

  // --------------------------------------------------------------- export / erase

  /// Parent data export (local JSON) — no network. Suitable for "download my data".
  Map<String, dynamic> exportFamilyData() {
    final children = this.children.map((c) {
      final id = c.id;
      return {
        'profile': c.toJson(),
        'xp': xpFor(id),
        'streak': streakFor(id),
        'coins': coinsFor(id),
        'stars': totalStars(id),
        'lessonsCompleted': completedLessonCount(id),
        'storiesRead': completedStoryCount(id),
        'progress': [
          for (final e in progressEntriesFor(id))
            {
              'kind': e.kind,
              'at': e.at?.toIso8601String(),
              'timeSpentS': e.timeSpentS,
              'stars': e.stars,
            },
        ],
      };
    }).toList();
    return {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'locale': localeCode,
      'consent': consent.toJson(),
      'plan': entitlementRaw.plan,
      'pendingSyncOps': pendingOps.length,
      'children': children,
    };
  }

  // ---------------------------------------------------------- diagnostics

  /// Rolling on-device log of product events and non-fatal errors.
  ///
  /// The app ships without a third-party analytics SDK, so this box *is* the
  /// telemetry: it survives restarts, the parent can read it, and it rides
  /// along in the support bundle. Capped so it can never grow unbounded.
  static const diagnosticsCap = 200;

  List<Map<String, dynamic>> _diagList(String key) {
    final raw = _account.get(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> _appendDiag(String key, Map<String, dynamic> entry) async {
    final list = [..._diagList(key), entry];
    if (list.length > diagnosticsCap) {
      list.removeRange(0, list.length - diagnosticsCap);
    }
    await _account.put(key, jsonEncode(list));
  }

  /// Product events recorded since install (newest last).
  List<Map<String, dynamic>> get analyticsLog => _diagList('analyticsLog');

  Future<void> appendAnalyticsEvent(
    String name,
    Map<String, Object?> params, {
    DateTime? at,
  }) =>
      _appendDiag('analyticsLog', {
        'name': name,
        'params': params,
        'at': (at ?? DateTime.now().toUtc()).toIso8601String(),
      });

  /// Non-fatal / fatal errors recorded on this device (newest last).
  List<Map<String, dynamic>> get crashLog => _diagList('crashLog');

  Future<void> appendCrashEvent({
    required String error,
    String? stack,
    bool fatal = false,
    DateTime? at,
  }) =>
      _appendDiag('crashLog', {
        // Truncated: a stack trace is diagnostic, not an archive.
        'error': error.length > 400 ? error.substring(0, 400) : error,
        if (stack != null)
          'stack': stack.length > 2000 ? stack.substring(0, 2000) : stack,
        'fatal': fatal,
        'at': (at ?? DateTime.now().toUtc()).toIso8601String(),
      });

  Future<void> clearDiagnostics() async {
    await _account.delete('analyticsLog');
    await _account.delete('crashLog');
  }

  // ------------------------------------------------------- backup / restore

  /// Bump when the key layout changes in a way older bundles cannot satisfy.
  static const backupFormatVersion = 1;

  /// Keys deliberately excluded from a backup file.
  ///
  /// A backup lands in Downloads, a chat thread, a cloud drive. Credentials and
  /// reset tokens must not travel with it, and session/device identity must not
  /// be cloned onto a second device.
  static const _backupExcludedKeys = {
    'pinHash',
    'pinSalt',
    'pinFailCount',
    'pinLockedUntil',
    'accountHash',
    'accountSalt',
    'pwResetHash',
    'pwResetSalt',
    'pwResetExp',
    'pwResetEmail',
    'loggedIn',
    'deviceId',
    'analyticsLog',
    'crashLog',
  };

  /// A **restorable** snapshot of this device's learning data.
  ///
  /// [exportFamilyData] is the human-readable "download my data" answer and
  /// deliberately flattens things; it cannot rebuild a device. This keeps the
  /// raw box contents so a reinstall or a replacement phone can be brought
  /// back to where the child left off — the closest thing to cloud backup an
  /// offline build can offer.
  Map<String, dynamic> exportBackupBundle() {
    final account = <String, String>{};
    for (final k in _account.keys) {
      final key = k as String;
      if (_backupExcludedKeys.contains(key)) continue;
      final v = _account.get(key);
      if (v != null) account[key] = v;
    }
    final progress = <String, String>{};
    for (final k in _progress.keys) {
      final v = _progress.get(k as String);
      if (v != null) progress[k] = v;
    }
    final stats = <String, int>{};
    for (final k in _stats.keys) {
      final v = _stats.get(k as String);
      if (v != null) stats[k] = v;
    }
    return {
      'format': 'watoto.backup',
      'version': backupFormatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'childCount': children.length,
      'account': account,
      'progress': progress,
      'stats': stats,
    };
  }

  /// Restores a bundle produced by [exportBackupBundle].
  ///
  /// Merge semantics, not replace: existing keys are kept unless
  /// [overwrite] is set, and XP/coin counters take the **higher** of the two
  /// values. Restoring a stale backup should never cost a child progress they
  /// have already made on this device.
  ///
  /// Throws [FormatException] on anything that is not a Watoto backup, so a
  /// parent who picks the wrong file gets told rather than silently nothing.
  Future<BackupRestoreResult> restoreBackupBundle(
    Map<String, dynamic> bundle, {
    bool overwrite = false,
  }) async {
    if (bundle['format'] != 'watoto.backup') {
      throw const FormatException('Not a Watoto backup file.');
    }
    final version = (bundle['version'] as num?)?.toInt() ?? 0;
    if (version > backupFormatVersion) {
      throw const FormatException(
        'This backup was made by a newer version of Watoto. Update the app first.',
      );
    }
    final account = (bundle['account'] as Map?)?.cast<String, dynamic>() ?? {};
    final progress = (bundle['progress'] as Map?)?.cast<String, dynamic>() ?? {};
    final stats = (bundle['stats'] as Map?)?.cast<String, dynamic>() ?? {};

    var childrenRestored = 0;
    var progressRestored = 0;

    for (final e in account.entries) {
      if (_backupExcludedKeys.contains(e.key)) continue;
      final value = e.value;
      if (value is! String) continue;
      final exists = _account.get(e.key) != null;
      if (exists && !overwrite) continue;
      await _account.put(e.key, value);
      if (e.key.startsWith('child:')) childrenRestored++;
    }
    for (final e in progress.entries) {
      final value = e.value;
      if (value is! String) continue;
      if (_progress.get(e.key) != null && !overwrite) continue;
      await _progress.put(e.key, value);
      progressRestored++;
    }
    // Counters merge by max so a restore never subtracts.
    for (final e in stats.entries) {
      final value = (e.value as num?)?.toInt();
      if (value == null) continue;
      final current = _stats.get(e.key) ?? 0;
      await _stats.put(e.key, value > current ? value : current);
    }
    return BackupRestoreResult(
      childrenRestored: childrenRestored,
      progressRestored: progressRestored,
    );
  }

  /// Soft-delete a child profile and all per-child learning keys on device.
  Future<void> deleteChild(String childId) async {
    await _account.delete('child:$childId');
    final accountKeys = _account.keys
        .where((k) => (k as String).contains(childId))
        .toList();
    for (final k in accountKeys) {
      await _account.delete(k);
    }
    final progressKeys = _progress.keys
        .where((k) => (k as String).contains(':$childId:'))
        .toList();
    await _progress.deleteAll(progressKeys);
    final statKeys = _stats.keys.where((k) {
      final key = k as String;
      return key.endsWith(':$childId') || key.contains(':$childId');
    }).toList();
    await _stats.deleteAll(statKeys);
    if (activeChildId == childId) {
      await _account.delete('activeChildId');
    }
  }

  /// Factory-reset local learning data for all children (keeps PIN/account).
  Future<void> eraseAllLearningData() async {
    await _progress.clear();
    await _queue.clear();
    await _stats.clear();
    for (final child in children) {
      final id = child.id;
      for (final prefix in [
        'preferredStage:',
        'dailyDone:',
        'dailyTarget:',
        'tourDone:',
        'tourPrompted:',
        'seenBadges:',
        'lastPlayed:',
        'avatars:',
        'attempts:',
        'streakDate:',
        'coinsDay:',
        // Progress-derived personalisation: erasing learning data has to take
        // the savanna and the companion with it, or a "cleared" profile still
        // remembers what the child did.
        'decor:',
        'mascotName:',
        'subjects:',
        'cheer:',
        'streakShieldWeek:',
        'streakShieldUsedAt:',
      ]) {
        final keys = _account.keys
            .where((k) => (k as String).startsWith('$prefix$id'))
            .toList();
        for (final k in keys) {
          await _account.delete(k);
        }
      }
    }
  }

  Future<void> _enqueue(SyncOp op) =>
      _queue.put(op.clientOpId, jsonEncode(op.toJson()));

  Future<void> removeOps(Iterable<String> clientOpIds) =>
      _queue.deleteAll(clientOpIds);

  Future<void> close() async {
    await _progress.close();
    await _queue.close();
    await _stats.close();
    await _account.close();
  }
}

/// What a [OfflineStore.restoreBackupBundle] call actually put back, so the
/// parent screen can say "2 children, 47 activities" instead of "done".
class BackupRestoreResult {
  const BackupRestoreResult({
    required this.childrenRestored,
    required this.progressRestored,
  });

  final int childrenRestored;
  final int progressRestored;

  bool get isEmpty => childrenRestored == 0 && progressRestored == 0;
}
