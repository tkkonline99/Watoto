import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/lesson_player/lesson_models.dart';
import '../../features/library/library_models.dart';
import '../../features/onboarding/consent.dart';
import '../../features/profiles/child_profile.dart';
import '../../features/quiz/quiz_models.dart';
import '../network/watoto_api.dart';
import 'offline_store.dart';
import 'sync_engine.dart';

/// Opened during bootstrap (main.dart) and injected via override so widget
/// tests can supply an in-memory store.
final offlineStoreProvider = Provider<OfflineStore>(
  (_) => throw StateError('offlineStoreProvider must be overridden at bootstrap'),
);

final syncApiProvider = Provider<SyncApi>((_) => WatotoApi());

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(ref.watch(offlineStoreProvider), ref.watch(syncApiProvider)),
);

// --------------------------------------------------------------- session

/// Navigation-relevant session state. Drives the router guards
/// (docs/05 §5.4). `parentUnlocked` is in-memory only and resets on restart.
class SessionState {
  const SessionState({
    required this.onboardingComplete,
    required this.activeChildId,
    required this.parentUnlocked,
    required this.profilesRev,
  });

  final bool onboardingComplete;
  final String? activeChildId;
  final bool parentUnlocked;
  final int profilesRev; // bumps when the set of profiles changes

  SessionState _copy({
    bool? onboardingComplete,
    Object? activeChildId = _unset,
    bool? parentUnlocked,
    int? profilesRev,
  }) =>
      SessionState(
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        activeChildId:
            activeChildId == _unset ? this.activeChildId : activeChildId as String?,
        parentUnlocked: parentUnlocked ?? this.parentUnlocked,
        profilesRev: profilesRev ?? this.profilesRev,
      );

  static const _unset = Object();
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._store)
      : super(SessionState(
          onboardingComplete: _store.onboardingComplete,
          activeChildId: _store.activeChildId,
          parentUnlocked: false,
          profilesRev: 0,
        ));

  final OfflineStore _store;

  Future<ChildProfile> completeOnboarding({
    required ConsentRecord consent,
    required String pin,
    required String nickname,
    required String avatarKey,
    required int birthYear,
  }) async {
    final child = await _store.completeOnboarding(
      consent: consent,
      pin: pin,
      nickname: nickname,
      avatarKey: avatarKey,
      birthYear: birthYear,
    );
    state = state._copy(
      onboardingComplete: true,
      activeChildId: child.id,
      profilesRev: state.profilesRev + 1,
    );
    return child;
  }

  Future<ChildProfile> addChild({
    required String nickname,
    required String avatarKey,
    required int birthYear,
  }) async {
    final child = await _store.addChild(
        nickname: nickname, avatarKey: avatarKey, birthYear: birthYear);
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
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionState>(
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

/// XP balance for the active child, seeded from the store and updated on write.
final xpProvider = StateProvider<int>((ref) {
  final id = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (id == null) return 0;
  return ref.watch(offlineStoreProvider).xpFor(id);
});

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

  Future<void> completeLibraryLesson(LibraryItem item, {required int timeSpentS}) async {
    final childId = _ref.read(sessionProvider).activeChildId;
    if (childId == null) return;
    final store = _ref.read(offlineStoreProvider);
    await store.recordLessonCompleted(
      childId: childId,
      lessonId: item.id,
      scorePct: 100,
      timeSpentS: timeSpentS,
      xpEarned: item.xp,
    );
    _afterWrite(store, childId);
  }

  Future<void> completeLibraryQuiz(
    LibraryItem item, {
    required int scorePct,
    required bool passed,
    required List<Map<String, dynamic>> answers,
    required int durationS,
  }) async {
    final childId = _ref.read(sessionProvider).activeChildId;
    if (childId == null) return;
    final store = _ref.read(offlineStoreProvider);
    await store.recordQuizAttempt(
      childId: childId,
      quizId: item.id,
      scorePct: scorePct,
      passed: passed,
      answers: answers,
      durationS: durationS,
      xpEarned: passed ? item.xp : 0,
    );
    _afterWrite(store, childId);
  }

  Future<void> completeLibraryStory(LibraryItem item) async {
    final childId = _ref.read(sessionProvider).activeChildId;
    if (childId == null) return;
    final store = _ref.read(offlineStoreProvider);
    await store.recordStoryRead(
      childId: childId,
      storyId: item.id,
      xpEarned: item.xp,
    );
    _afterWrite(store, childId);
  }

  void _afterWrite(OfflineStore store, String childId) {
    _ref.read(xpProvider.notifier).state = store.xpFor(childId);
    unawaited(_ref.read(syncEngineProvider).flush());
  }
}
