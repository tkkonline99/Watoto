import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/gamification/daily_challenge.dart';
import '../../features/gamification/economy.dart';
import '../../features/gamification/reward_outcome.dart';
import '../../features/gamification/rewards.dart';
import '../../features/gamification/stars.dart';
import '../../features/lesson_player/lesson_models.dart';
import '../../features/library/library_models.dart';
import '../../features/library/library_repository.dart';
import '../../features/onboarding/consent.dart';
import '../../features/profiles/child_profile.dart';
import '../../features/quiz/quiz_models.dart';
import '../../features/auth/auth_service.dart';
import '../network/watoto_api.dart';
import 'offline_store.dart';
import 'sync_engine.dart';

/// Opened during bootstrap (main.dart) and injected via override so widget
/// tests can supply an in-memory store.
final offlineStoreProvider = Provider<OfflineStore>(
  (_) =>
      throw StateError('offlineStoreProvider must be overridden at bootstrap'),
);

final syncApiProvider = Provider<SyncApi>((ref) {
  // Prefer AuthPort token (Firebase when wired); Nest dev-token only in debug.
  final auth = ref.watch(authServiceProvider);
  final store = ref.watch(offlineStoreProvider);
  return WatotoApi(
    deviceId: store.deviceId,
    tokenProvider: ({bool forceRefresh = false}) =>
        auth.getIdToken(forceRefresh: forceRefresh),
  );
});

final syncEngineProvider = Provider<SyncEngine>(
  (ref) =>
      SyncEngine(ref.watch(offlineStoreProvider), ref.watch(syncApiProvider)),
);

// --------------------------------------------------------------- session

/// Navigation-relevant session state. Drives the router guards
/// (docs/05 §5.4). `parentUnlocked` is in-memory only and resets on restart.
class SessionState {
  const SessionState({
    required this.onboardingComplete,
    required this.activeChildId,
    required this.parentUnlocked,
    required this.loggedIn,
    required this.profilesRev,
  });

  final bool onboardingComplete;
  final String? activeChildId;
  final bool parentUnlocked;
  final bool loggedIn; // a parent account session is active
  final int profilesRev; // bumps when the set of profiles changes

  /// PIN families need [parentUnlocked] this run. Account families may enter
  /// while [loggedIn]; sensitive actions still use the FTC parent gate.
  /// Background [lockParent] clears the PIN unlock only.
  bool get parentAccessAllowed => parentUnlocked || loggedIn;

  SessionState _copy({
    bool? onboardingComplete,
    Object? activeChildId = _unset,
    bool? parentUnlocked,
    bool? loggedIn,
    int? profilesRev,
  }) => SessionState(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    activeChildId: activeChildId == _unset
        ? this.activeChildId
        : activeChildId as String?,
    parentUnlocked: parentUnlocked ?? this.parentUnlocked,
    loggedIn: loggedIn ?? this.loggedIn,
    profilesRev: profilesRev ?? this.profilesRev,
  );

  static const _unset = Object();
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._store)
    : super(
        SessionState(
          onboardingComplete: _store.onboardingComplete,
          activeChildId: _store.activeChildId,
          parentUnlocked: false,
          loggedIn: _store.isLoggedIn,
          profilesRev: 0,
        ),
      );

  final OfflineStore _store;

  Future<ChildProfile> completeOnboarding({
    required ConsentRecord consent,
    String? pin,
    String? accountEmail,
    String? accountPassword,
    required String nickname,
    required String avatarKey,
    required int birthYear,
  }) async {
    final child = await _store.completeOnboarding(
      consent: consent,
      pin: pin,
      accountEmail: accountEmail,
      accountPassword: accountPassword,
      nickname: nickname,
      avatarKey: avatarKey,
      birthYear: birthYear,
    );
    state = state._copy(
      onboardingComplete: true,
      activeChildId: child.id,
      loggedIn: accountEmail != null,
      // Fresh onboarding unlocks parent for setup; backgrounds re-lock.
      parentUnlocked: true,
      profilesRev: state.profilesRev + 1,
    );
    return child;
  }

  /// Creates a local parent account and starts the session.
  Future<void> createAccount(String email, String password) async {
    await _store.createAccount(email, password);
    state = state._copy(loggedIn: true, parentUnlocked: true);
  }

  /// Signs in to the local account; returns false on a credential mismatch.
  Future<bool> signIn(String email, String password) async {
    final ok = await _store.signIn(email, password);
    if (ok) state = state._copy(loggedIn: true, parentUnlocked: true);
    return ok;
  }

  Future<void> signOutAccount() async {
    await _store.signOut();
    state = state._copy(loggedIn: false, parentUnlocked: false);
  }

  Future<ChildProfile> addChild({
    required String nickname,
    required String avatarKey,
    required int birthYear,
  }) async {
    final child = await _store.addChild(
      nickname: nickname,
      avatarKey: avatarKey,
      birthYear: birthYear,
    );
    state = state._copy(profilesRev: state.profilesRev + 1);
    return child;
  }

  Future<void> selectChild(String id) async {
    await _store.setActiveChild(id);
    state = state._copy(activeChildId: id);
  }

  /// Return to the "who's learning?" picker.
  void switchChild() => state = state._copy(activeChildId: null);

  Future<void> saveConsent(ConsentRecord consent) async {
    await _store.saveConsent(consent);
    state = state._copy(); // nudge listeners
  }

  void unlockParent() => state = state._copy(parentUnlocked: true);
  void lockParent() => state = state._copy(parentUnlocked: false);

  /// Bumps [profilesRev] so avatar/equip changes refresh home/picker.
  void touchProfiles() =>
      state = state._copy(profilesRev: state.profilesRev + 1);

  /// Bumps session so entitlement listeners rebuild after a purchase.
  void touchSession() => state = state._copy();
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(ref.watch(offlineStoreProvider)),
);

/// The currently-selected child profile, or null at the picker.
final activeChildProvider = Provider<ChildProfile?>((ref) {
  final id = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (id == null) return null;
  ref.watch(sessionProvider.select((s) => s.profilesRev));
  return ref.watch(offlineStoreProvider).childById(id);
});

final childrenProvider = Provider<List<ChildProfile>>((ref) {
  ref.watch(sessionProvider.select((s) => s.profilesRev));
  return ref.watch(offlineStoreProvider).children;
});

/// Bumped after every economy write so UI always re-reads the store (single
/// source of truth — no desynced StateProvider snapshots).
final economyTickProvider = StateProvider<int>((ref) => 0);

/// XP balance for the active child (store-backed, reactive via [economyTickProvider]).
final xpProvider = Provider<int>((ref) {
  ref.watch(economyTickProvider);
  final id = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (id == null) return 0;
  return ref.watch(offlineStoreProvider).xpFor(id);
});

/// Daily-learning streak for the active child.
final streakProvider = Provider<int>((ref) {
  ref.watch(economyTickProvider);
  final id = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (id == null) return 0;
  return ref.watch(offlineStoreProvider).streakFor(id);
});

/// Coin balance for the active child.
final coinsProvider = Provider<int>((ref) {
  ref.watch(economyTickProvider);
  final id = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (id == null) return 0;
  return ref.watch(offlineStoreProvider).coinsFor(id);
});

/// Lifetime stars for the active child (quiz quality).
final starsProvider = Provider<int>((ref) {
  ref.watch(economyTickProvider);
  final id = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (id == null) return 0;
  return ref.watch(offlineStoreProvider).totalStars(id);
});

/// Bumps when screen-time settings or usage change so the soft-lock rebuilds.
final screenTimeTickProvider = StateProvider<int>((ref) => 0);

/// Newly earned badges since last home visit (ids). Cleared after toast.
final pendingBadgeToastProvider = StateProvider<List<String>>((ref) => []);

/// Level the child just reached (0 = none). Cleared after toast.
final pendingLevelUpProvider = StateProvider<int>((ref) => 0);

// --------------------------------------------------------------- learning

final learningServiceProvider = Provider<LearningService>(LearningService.new);

/// Single entry point for "the child finished something": persists locally for
/// the active child, updates balances, and kicks a best-effort sync — the UI
/// never waits on the network.
class LearningService {
  LearningService(this._ref);

  final Ref _ref;

  Future<void> completeLesson(
    LessonBody lesson, {
    required int scorePct,
    required int timeSpentS,
  }) async {
    final childId = _ref.read(sessionProvider).activeChildId;
    if (childId == null) return;
    final store = _ref.read(offlineStoreProvider);
    await store.recordLessonCompleted(
      childId: childId,
      lessonId: lesson.id,
      scorePct: scorePct,
      timeSpentS: timeSpentS,
      xpEarned: lesson.completion.xp,
    );
    _afterWrite(store, childId);
  }

  Future<void> completeQuiz(
    QuizBody quiz, {
    required List<int> selected,
    required QuizGrade grade,
    required int durationS,
  }) async {
    final childId = _ref.read(sessionProvider).activeChildId;
    if (childId == null) return;
    final store = _ref.read(offlineStoreProvider);
    await store.recordQuizAttempt(
      childId: childId,
      quizId: quiz.id,
      scorePct: grade.scorePct,
      passed: grade.passed,
      answers: [
        for (var i = 0; i < selected.length; i++)
          {'questionId': quiz.questions[i].id, 'selectedIndex': selected[i]},
      ],
      durationS: durationS,
      xpEarned: grade.xp,
    );
    _afterWrite(store, childId);
  }

  // --- Playable content library (content/watoto_content_library.json) ---

  /// [scorePct] and [mistakes] describe how the run actually went. They used
  /// to be hardcoded to a perfect 100/0, which meant the adaptive engine saw
  /// every child as flying and pushed everyone up a stage.
  ///
  /// [graded] is false for lessons with nothing a child can get wrong (all
  /// "tap the picture" steps). Those still complete and still pay out, but
  /// they contribute no difficulty signal — a run that cannot be failed is not
  /// evidence the child found it easy.
  Future<void> completeLibraryLesson(
    LibraryItem item, {
    required int timeSpentS,
    int scorePct = 100,
    int mistakes = 0,
    int stars = 0,
    bool graded = false,
  }) async {
    final childId = _ref.read(sessionProvider).activeChildId;
    if (childId == null) return;
    final store = _ref.read(offlineStoreProvider);
    final firstInSubject = await _firstTimeInSubject(store, childId, item);
    await store.recordLessonCompleted(
      childId: childId,
      lessonId: item.id,
      scorePct: scorePct,
      timeSpentS: timeSpentS,
      xpEarned: item.xp,
    );
    final coins = await store.grantCoins(childId, coinsLesson);
    await store.setLastPlayed(
      childId: childId,
      itemId: item.id,
      stage: item.stage,
      subject: item.subject,
    );
    await store.addScreenTimeSeconds(timeSpentS);
    final bonusCoins =
        await _maybeDailyChallengeBonus(store, childId, item.id);
    if (graded) {
      await store.recordAttemptOutcome(
        childId: childId,
        scorePct: scorePct,
        retries: mistakes,
      );
    }
    _afterWrite(
      store,
      childId,
      xp: item.xp,
      coins: coins + bonusCoins,
      stars: stars,
      firstInSubject: firstInSubject,
    );
  }

  /// Whether this child has finished anything in [item]'s subject before —
  /// used to make a first step into a new subject feel like one. Records the
  /// subject as visited on the way out.
  Future<bool> _firstTimeInSubject(
    OfflineStore store,
    String childId,
    LibraryItem item,
  ) async {
    final seen = store.hasCompletedAnyInSubject(childId, item.subject);
    if (!seen) await store.markSubjectCompleted(childId, item.subject);
    return !seen;
  }

  Future<void> completeLibraryQuiz(
    LibraryItem item, {
    required int scorePct,
    required bool passed,
    required List<Map<String, dynamic>> answers,
    required int durationS,
    int retries = 0,
  }) async {
    final childId = _ref.read(sessionProvider).activeChildId;
    if (childId == null) return;
    final store = _ref.read(offlineStoreProvider);
    final stars = starsFromScorePct(scorePct);
    final firstInSubject = await _firstTimeInSubject(store, childId, item);
    await store.recordQuizAttempt(
      childId: childId,
      quizId: item.id,
      scorePct: scorePct,
      passed: passed,
      answers: answers,
      durationS: durationS,
      xpEarned: passed ? item.xp : 0,
      stars: stars,
    );
    var coins = 0;
    if (passed) {
      coins = await store.grantCoins(childId, coinsQuizPass);
      coins += await _maybeDailyChallengeBonus(store, childId, item.id);
    }
    await store.setLastPlayed(
      childId: childId,
      itemId: item.id,
      stage: item.stage,
      subject: item.subject,
    );
    await store.addScreenTimeSeconds(durationS);
    await store.recordAttemptOutcome(
      childId: childId,
      scorePct: scorePct,
      retries: retries,
    );
    _afterWrite(
      store,
      childId,
      xp: passed ? item.xp : 0,
      coins: coins,
      stars: stars,
      firstInSubject: passed && firstInSubject,
    );
  }

  Future<void> completeLibraryStory(LibraryItem item) async {
    final childId = _ref.read(sessionProvider).activeChildId;
    if (childId == null) return;
    final store = _ref.read(offlineStoreProvider);
    final firstInSubject = await _firstTimeInSubject(store, childId, item);
    await store.recordStoryRead(
      childId: childId,
      storyId: item.id,
      xpEarned: item.xp,
    );
    var coins = await store.grantCoins(childId, coinsStory);
    await store.setLastPlayed(
      childId: childId,
      itemId: item.id,
      stage: item.stage,
      subject: item.subject,
    );
    coins += await _maybeDailyChallengeBonus(store, childId, item.id);
    _afterWrite(
      store,
      childId,
      xp: item.xp,
      coins: coins,
      firstInSubject: firstInSubject,
    );
  }

  /// If [itemId] is today's daily challenge, grant the once-per-day bonus XP.
  /// Returns the bonus coins granted (0 when it was not today's challenge).
  Future<int> _maybeDailyChallengeBonus(
    OfflineStore store,
    String childId,
    String itemId,
  ) async {
    if (store.isDailyChallengeDone(childId)) return 0;
    final child = store.childById(childId);
    if (child == null) return 0;
    final lib = await _ref.read(libraryProvider.future);
    if (!isTodaysChallengeItem(
      itemId: itemId,
      child: child,
      store: store,
      library: lib,
    )) {
      return 0;
    }
    await store.markDailyChallengeDone(childId, itemId);
    return store.grantCoins(childId, coinsDailyChallenge);
  }

  void _afterWrite(
    OfflineStore store,
    String childId, {
    int xp = 0,
    int coins = 0,
    int stars = 0,
    bool firstInSubject = false,
  }) {
    final totalXp = store.xpFor(childId);
    final level = levelForXp(totalXp);
    final prevLevel = store.lastKnownLevel(childId);
    var levelUp = 0;
    if (level > prevLevel) {
      unawaited(store.setLastKnownLevel(childId, level));
      _ref.read(pendingLevelUpProvider.notifier).state = level;
      levelUp = level;
    }

    final streak = store.streakFor(childId);
    final stats = BadgeStats(
      xp: totalXp,
      streak: streak,
      lessons: store.completedLessonCount(childId),
      stories: store.completedStoryCount(childId),
      dailyChallenges: store.dailyChallengeTotalCount(childId),
    );
    final earned = earnedBadges(stats).map((b) => b.id).toSet();
    final seen = store.seenBadgeIds(childId);
    final fresh = earned.difference(seen).toList();
    if (fresh.isNotEmpty) {
      unawaited(store.markBadgesSeen(childId, fresh));
      _ref.read(pendingBadgeToastProvider.notifier).state = [
        ..._ref.read(pendingBadgeToastProvider),
        ...fresh,
      ];
    }

    // Hand the celebration everything worth showing, in one object. The
    // session counter drives the cool-down (docs/12 §12.6).
    final sessionIndex = _ref.read(sessionCompletionCountProvider);
    _ref.read(sessionCompletionCountProvider.notifier).state = sessionIndex + 1;
    _ref.read(pendingRewardProvider.notifier).state = RewardOutcome(
      xp: xp,
      coins: coins,
      stars: stars,
      levelUp: levelUp,
      badgeIds: fresh,
      streakSavedDays: store.takeShieldJustUsed() ? streak : 0,
      streak: streak,
      firstInSubject: firstInSubject,
      sessionIndex: sessionIndex,
    );

    _ref.read(economyTickProvider.notifier).state++;
    _ref.read(screenTimeTickProvider.notifier).state++;
    unawaited(_ref.read(syncEngineProvider).flush());
  }
}
