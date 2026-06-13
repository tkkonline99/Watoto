import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_models.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_repository.dart';
import 'package:watoto_mobile/features/quiz/quiz_models.dart';
import 'package:watoto_mobile/features/quiz/quiz_repository.dart';

const _quiz = QuizBody(
  id: '8c1d2e3f-4a5b-4c6d-8e7f-9a0b1c2d3e4f',
  schema: 'watoto.quiz/1.0',
  titleKey: 'quizCountingTitle',
  passPct: 70,
  xpByStars: [10, 15, 20],
  questions: [
    QuizQuestion(id: 'q1', promptKey: 'quizHowMany', emoji: '☀️', count: 1, options: [
      QuizOption(text: '1', correct: true),
      QuizOption(text: '2', correct: false),
    ]),
    QuizQuestion(id: 'q2', promptKey: 'quizHowMany', emoji: '🐘', count: 2, options: [
      QuizOption(text: '1', correct: false),
      QuizOption(text: '2', correct: true),
    ]),
    QuizQuestion(id: 'q3', promptKey: 'quizHowMany', emoji: '🥭', count: 3, options: [
      QuizOption(text: '2', correct: false),
      QuizOption(text: '3', correct: true),
    ]),
  ],
);

const _lesson = LessonBody(
  id: '5d3f1a2b-9c4e-4f6a-8b7d-1e2f3a4b5c6d',
  schema: 'watoto.lesson/1.0',
  titleKey: 'lessonCountingTitle',
  quizSlug: 'counting-quiz',
  blocks: [
    ConceptBlock(textKey: 'lessonCountingTitle', emoji: '🥭'),
    TapToCountBlock(items: 3),
    CheckBlock(
      promptKey: 'checkAnswerPrompt',
      options: [
        CheckOption(text: '2', correct: false),
        CheckOption(text: '3', correct: true),
      ],
    ),
  ],
  completion: LessonCompletion(xp: 10, stars: 1, skills: ['counting.1-10']),
);

/// Simulates being offline: every sync attempt fails, ops must stay queued.
class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

void main() {
  late OfflineStore store;

  setUpAll(() => Hive.init(Directory.systemTemp.path));

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          lessonProvider.overrideWith((ref, slug) async => _lesson),
          quizProvider.overrideWith((ref, slug) async => _quiz),
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_UnreachableApi()),
        ],
        child: const WatotoApp(),
      );

  /// Scripts the lesson up to the celebration screen.
  Future<void> completeLesson(WidgetTester tester) async {
    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('🥭').at(i));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
  }

  /// Answers the current quiz with the given option texts.
  Future<void> answerQuiz(WidgetTester tester, List<String> picks) async {
    for (final pick in picks) {
      await tester.tap(find.text(pick));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('home shows greeting, subjects, and daily challenge', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Jambo, Amani!'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
  });

  testWidgets('child completes the lesson offline: XP banked, op queued', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Enter the lesson from the Math island.
    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    expect(find.text('Counting 1 to 3'), findsWidgets);

    // Block 1: concept → Next.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Block 2: tap all three mangoes, then Next.
    expect(find.text('Tap each mango to count it!'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('🥭').at(i));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Block 3: wrong answer is forgiving, correct answer completes.
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('So close! Try again!'), findsOneWidget);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);

    // Done → home, with XP banked.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('10 XP'), findsOneWidget);

    // Offline-first contract: completion persisted locally and the sync op
    // is still queued because the (fake) network was unreachable.
    expect(store.xp, 10);
    expect(store.progressFor(_lesson.id)?['status'], 'completed');
    final ops = store.pendingOps;
    expect(ops, hasLength(1));
    expect(ops.single.opType, 'lesson_progress');
    expect(ops.single.payload['lessonId'], _lesson.id);
  });

  testWidgets('quiz: fail is forgiving, retry passes, attempts queue offline', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await completeLesson(tester);
    await tester.tap(find.text('Quiz time!'));
    await tester.pumpAndSettle();
    expect(find.text('Counting Quiz'), findsWidgets);
    expect(find.text('How many do you see?'), findsOneWidget);

    // Attempt 1: one wrong answer → 2/3 = 67% → fail, warmly.
    await answerQuiz(tester, ['1', '1', '3']);
    expect(find.text('So close! Try again!'), findsOneWidget);
    expect(find.text('You got 2 of 3!'), findsOneWidget);

    // Attempt 2: all correct → pass with 3 stars and XP.
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await answerQuiz(tester, ['1', '2', '3']);
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('You got 3 of 3!'), findsOneWidget);
    expect(find.text('⭐⭐⭐'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);

    // Home shows lesson (10) + quiz (20) XP.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('30 XP'), findsOneWidget);

    // Offline queue holds: 1 lesson op + 2 quiz attempts (fail AND pass —
    // attempts are data), all awaiting sync.
    final ops = store.pendingOps;
    expect(ops, hasLength(3));
    expect(ops.where((o) => o.opType == 'quiz_attempt'), hasLength(2));
    final lastAttempt = store.lastQuizAttempt(_quiz.id);
    expect(lastAttempt?['passed'], true);
    expect(lastAttempt?['scorePct'], 100);
    expect(store.xp, 30);
  });

  testWidgets('locale switches to Swahili', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose your language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();

    expect(find.text('Changamoto ya Leo'), findsOneWidget);
    expect(find.text('Hesabu'), findsOneWidget);
  });
}
