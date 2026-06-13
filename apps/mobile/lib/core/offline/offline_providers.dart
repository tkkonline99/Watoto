import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/lesson_player/lesson_models.dart';
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

/// XP balance, seeded from the persisted store on startup.
final xpProvider = StateProvider<int>((ref) => ref.watch(offlineStoreProvider).xp);

final learningServiceProvider = Provider<LearningService>(LearningService.new);

/// Single entry point for "the child finished something": persists locally,
/// updates balances, and kicks a best-effort sync — the UI never waits on
/// the network.
class LearningService {
  LearningService(this._ref);

  final Ref _ref;

  Future<void> completeLesson(
    LessonBody lesson, {
    required int scorePct,
    required int timeSpentS,
  }) async {
    final store = _ref.read(offlineStoreProvider);
    await store.recordLessonCompleted(
      lessonId: lesson.id,
      scorePct: scorePct,
      timeSpentS: timeSpentS,
      xpEarned: lesson.completion.xp,
    );
    _afterWrite(store);
  }

  Future<void> completeQuiz(
    QuizBody quiz, {
    required List<int> selected,
    required QuizGrade grade,
    required int durationS,
  }) async {
    final store = _ref.read(offlineStoreProvider);
    await store.recordQuizAttempt(
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
    _afterWrite(store);
  }

  void _afterWrite(OfflineStore store) {
    _ref.read(xpProvider.notifier).state = store.xp;
    unawaited(_ref.read(syncEngineProvider).flush());
  }
}
