import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../features/onboarding/consent.dart';
import '../../features/profiles/child_profile.dart';
import 'sync_op.dart';

/// Offline-first local store: account/profiles/consent, per-child progress and
/// reward balances, and the outbound sync queue. Every learning write lands
/// here first; the [SyncEngine] drains the queue when the API is reachable
/// (docs/15-offline-sync.md).
///
/// Hive keeps this portable across Android/iOS/Web and trivially testable;
/// the drift/SQLite + Firebase-auth upgrade slots in behind this interface.
/// Pure streak arithmetic (unit-tested directly): the run continues on the
/// same day, increments after exactly one day's gap, and resets otherwise.
/// Day keys are 'yyyy-MM-dd' strings in the family's local time.
int nextStreak({
  required String? lastDayKey,
  required String todayKey,
  required String yesterdayKey,
  required int current,
}) {
  if (lastDayKey == todayKey) return current == 0 ? 1 : current;
  if (lastDayKey == yesterdayKey) return current + 1;
  return 1;
}

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

  bool get hasPin => _account.get('pinHash') != null;

  /// Local parent gate. A salted SHA-256 keeps the PIN out of plaintext on
  /// device; the production design uses argon2id server-side (docs/16 §16.1).
  Future<void> setPin(String pin) async {
    await _account.put('pinSalt', _uuid.v4());
    await _account.put('pinHash', _hashPin(pin));
  }

  bool verifyPin(String pin) =>
      hasPin && _hashPin(pin) == _account.get('pinHash');

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
    await _account.put('accountEmail', email.trim());
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
    );
    await _account.put('child:${child.id}', jsonEncode(child.toJson()));
    return child;
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
  Future<void> _touchStreak(String childId, DateTime now) async {
    final todayKey = _dayKey(now);
    final lastKey = _account.get('streakDate:$childId');
    if (lastKey == todayKey) return; // already counted today
    final next = nextStreak(
      lastDayKey: lastKey,
      todayKey: todayKey,
      yesterdayKey: _dayKey(now.subtract(const Duration(days: 1))),
      current: streakFor(childId),
    );
    await _stats.put('streak:$childId', next);
    await _account.put('streakDate:$childId', todayKey);
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
  /// it for server-side authoritative re-grading.
  Future<void> recordQuizAttempt({
    required String childId,
    required String quizId,
    required int scorePct,
    required bool passed,
    required List<Map<String, dynamic>> answers,
    required int durationS,
    required int xpEarned,
  }) async {
    final now = DateTime.now().toUtc();
    await _progress.put(
      'quiz:$childId:$quizId',
      jsonEncode({
        'quizId': quizId,
        'scorePct': scorePct,
        'passed': passed,
        'attemptedAt': now.toIso8601String(),
      }),
    );
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

  Future<void> _grantXp(String childId, int amount) async {
    if (amount > 0) await _stats.put('xp:$childId', xpFor(childId) + amount);
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
