import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/consent.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/rules/review.dart';
import '../../domain/rules/streak.dart';
import '../../domain/rules/username.dart';
import 'sync_op.dart';

export '../../domain/rules/streak.dart'
    show nextStreak, nextStreakTick, StreakTick, isoWeekKey;
export '../../domain/rules/username.dart';

part 'offline_store_cosmetics.dart';
part 'offline_store_data.dart';
part 'offline_store_insights.dart';
part 'offline_store_settings.dart';

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

  // Hoisted here because call sites say OfflineStore.<name>:
  // an extension's statics would only answer to the extension.
  /// Rolling on-device log of product events and non-fatal errors.
  ///
  /// The app ships without a third-party analytics SDK, so this box *is* the
  /// telemetry: it survives restarts, the parent can read it, and it rides
  /// along in the support bundle. Capped so it can never grow unbounded.
  static const diagnosticsCap = 200;

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

  int completedQuizCount(String childId) => _progress.keys
      .where((k) => (k as String).startsWith('quiz:$childId:'))
      .length;

  /// Quizzes finished with every question right. Reads the stored best score,
  /// so a child who returns and aces a quiz they first fumbled is counted —
  /// the badge rewards mastery, not first-attempt luck.
  int perfectQuizCount(String childId) {
    var n = 0;
    for (final k in _progress.keys) {
      if (!(k as String).startsWith('quiz:$childId:')) continue;
      final m = _read(k);
      if (m == null) continue;
      if (((m['scorePct'] as num?)?.toInt() ?? 0) >= 100) n++;
    }
    return n;
  }

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
