import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_models.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_repository.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/features/quiz/quiz_models.dart';
import 'package:watoto_mobile/features/quiz/quiz_repository.dart';
import 'package:watoto_mobile/router/app_router.dart';

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

/// The home no longer deep-links into the hard-coded counting lesson — the
/// daily challenge now opens the age picker — so the lesson/quiz flow tests
/// drive the still-live `/lesson` and `/quiz` routes directly.
void goTo(WidgetTester tester, String location) {
  ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
      .read(appRouterProvider)
      .go(location);
}

/// The home XP counter is a stat pill that renders the bare number ("⭐ 10");
/// the readable `<n> XP · Level <l>` string lives only on its semantics label,
/// so assert against the semantics tree rather than the pill's digits.
void expectXp(WidgetTester tester, int xp) {
  final handle = tester.ensureSemantics();
  expect(find.bySemanticsLabel(RegExp('^$xp XP')), findsOneWidget);
  handle.dispose();
}

/// The subject grid sits below the fold on the test surface, so scroll the home
/// list until the tile is on screen.
Future<void> scrollToSubjects(WidgetTester tester, Finder tile) async {
  await tester.scrollUntilVisible(tile, 200);
  await tester.pumpAndSettle();
}

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    // Hold the perpetual savanna ambient drift still so pumpAndSettle (used
    // throughout) doesn't wait forever on an animation that never completes.
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
    // Most tests here jump straight to a learning surface; the login gate has
    // its own group below, which turns this back off.
    debugSkipLoginGate = true;
  });

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  /// Seeds an onboarded family (PIN 1234, child "Amani") so tests start on
  /// the child home instead of onboarding.
  Future<String> seedOnboarded() async {
    final child = await store.completeOnboarding(
      consent: const ConsentRecord(
          coreData: true, aiFeatures: false, voiceRecording: false, recordedAt: null),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    return child.id;
  }

  Widget buildApp() => ProviderScope(
        overrides: [
          lessonProvider.overrideWith((ref, slug) async => _lesson),
          quizProvider.overrideWith((ref, slug) async => _quiz),
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_UnreachableApi()),
        ],
        child: const WatotoApp(),
      );

  Future<void> completeLesson(WidgetTester tester) async {
    goTo(tester, '/lesson/counting-1-3');
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

  Future<void> answerQuiz(WidgetTester tester, List<String> picks) async {
    for (final pick in picks) {
      await tester.tap(find.text(pick));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('first run: onboarding -> consent -> account -> child -> home',
      (tester) async {
    // The onboarding cards can exceed a short test viewport; give them room so
    // the primary buttons aren't scrolled off-screen when tapped.
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // store is fresh (not onboarded) -> app must start in onboarding.
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    // The button can sit below the fold on a small test viewport; bring it in.
    final letsGo = find.text("Let's go! 🚀");
    await tester.ensureVisible(letsGo);
    await tester.pump();
    await tester.tap(letsGo);
    await tester.pumpAndSettle();

    // The grown-up gate step has been removed: language -> consent directly.
    expect(find.text('A safe place to learn'), findsOneWidget);
    final agree = find.text('Agree & continue');
    await tester.ensureVisible(agree);
    await tester.tap(agree);
    await tester.pumpAndSettle();

    // Default secure step = create a parent account (no PIN asked).
    await tester.enterText(find.byType(TextField).at(0), 'parent@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.pump(); // let the (input-gated) Next button enable
    final next = find.text('Next');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Zuri');
    await tester.pumpAndSettle();
    final done = find.text('Done');
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(find.text('Hello, Zuri!'), findsOneWidget);
    expect(store.onboardingComplete, isTrue);
    expect(store.children.single.nickname, 'Zuri');
    expect(store.hasAccount, isTrue);
    expect(store.accountEmail, 'parent@example.com');
    expect(store.isLoggedIn, isTrue);
    expect(store.hasPin, isFalse); // account families are never asked for a PIN
  });

  testWidgets('account family reaches the parent zone without a PIN',
      (tester) async {
    await store.completeOnboarding(
      consent: const ConsentRecord(
          coreData: true, aiFeatures: false, voiceRecording: false, recordedAt: null),
      accountEmail: 'mom@example.com',
      accountPassword: 'secret123',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/'); // app opens on the welcome screen; enter the home
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Parent Zone'));
    await tester.pumpAndSettle();
    // Straight into the dashboard — no PIN gate.
    expect(find.text('Children'), findsOneWidget);
    expect(find.text('Grown-ups only'), findsNothing);
  });

  testWidgets('the account screen shows the family their own information',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await store.completeOnboarding(
      consent: ConsentRecord(
        coreData: true,
        aiFeatures: false,
        voiceRecording: false,
        recordedAt: DateTime.utc(2026, 3, 4),
      ),
      accountEmail: 'mom@example.com',
      accountPassword: 'secret123',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    goTo(tester, '/account');
    await tester.pumpAndSettle();

    expect(find.text('My account'), findsOneWidget);
    expect(find.text('mom@example.com'), findsWidgets);
    expect(find.text('Email & password'), findsOneWidget);
    expect(find.text('Amani, age ${DateTime.now().year - 2019}'),
        findsOneWidget);
    // Both dispose-of-my-data actions are offered, log out first.
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('logging out from the account screen returns to the welcome '
      'screen and ends the session', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedOnboarded(); // PIN 1234, no account
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    goTo(tester, '/account');
    await tester.pumpAndSettle();

    final logOut = find.text('Log out');
    await tester.ensureVisible(logOut);
    await tester.tap(logOut);
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    expect(store.isLoggedIn, isFalse);
  });

  testWidgets('deleting the account erases the device back to first run',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final childId = await seedOnboarded();
    await store.recordLessonCompleted(
      childId: childId,
      lessonId: 'counting-1-3',
      scorePct: 100,
      timeSpentS: 60,
      xpEarned: 25,
    );
    expect(store.xpFor(childId), 25);
    expect(store.pendingOps, isNotEmpty);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/account');
    await tester.pumpAndSettle();

    final delete = find.text('Delete account');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    // Destructive, so it asks first.
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(store.onboardingComplete, isFalse);
    expect(store.children, isEmpty);
    expect(store.hasAccount, isFalse);
    expect(store.hasPin, isFalse);
    expect(store.xpFor(childId), 0);
    expect(store.pendingOps, isEmpty);
    // Back at the very beginning.
    expect(find.text('Choose your language'), findsOneWidget);
  });

  testWidgets('home shows greeting, subjects, and daily challenge', (tester) async {
    await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/'); // app opens on the welcome screen; enter the home
    await tester.pumpAndSettle();

    expect(find.text('Hello, Amani!'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expectXp(tester, 0);
    await scrollToSubjects(tester, find.text('Math'));
    expect(find.text('Math'), findsOneWidget);
  });

  testWidgets('child completes the lesson offline: XP banked, op queued',
      (tester) async {
    final id = await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    goTo(tester, '/lesson/counting-1-3');
    await tester.pumpAndSettle();
    expect(find.text('Counting 1 to 3'), findsWidgets);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Tap each mango to count it!'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('🥭').at(i));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('So close! Try again!'), findsOneWidget);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expectXp(tester, 10);

    expect(store.xpFor(id), 10);
    expect(store.progressFor(id, _lesson.id)?['status'], 'completed');
    final ops = store.pendingOps;
    expect(ops, hasLength(1));
    expect(ops.single.opType, 'lesson_progress');
    expect(ops.single.payload['lessonId'], _lesson.id);
  });

  testWidgets('quiz: fail is forgiving, retry passes, attempts queue offline',
      (tester) async {
    final id = await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await completeLesson(tester);
    await tester.tap(find.text('Quiz time!'));
    await tester.pumpAndSettle();
    expect(find.text('Counting Quiz'), findsWidgets);
    expect(find.text('How many do you see?'), findsOneWidget);

    await answerQuiz(tester, ['1', '1', '3']);
    expect(find.text('So close! Try again!'), findsOneWidget);
    expect(find.text('You got 2 of 3!'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await answerQuiz(tester, ['1', '2', '3']);
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('You got 3 of 3!'), findsOneWidget);
    expect(find.text('⭐⭐⭐'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expectXp(tester, 30);

    final ops = store.pendingOps;
    expect(ops, hasLength(3));
    expect(ops.where((o) => o.opType == 'quiz_attempt'), hasLength(2));
    final lastAttempt = store.lastQuizAttempt(id, _quiz.id);
    expect(lastAttempt?['passed'], true);
    expect(lastAttempt?['scorePct'], 100);
    expect(store.xpFor(id), 30);
  });

  testWidgets('parent zone is PIN-gated', (tester) async {
    await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/'); // app opens on the welcome screen; enter the home
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Parent Zone'));
    await tester.pumpAndSettle();
    expect(find.text('Grown-ups only'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong PIN, try again'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Children'), findsOneWidget);
    // The dashboard names the child in both the weekly snapshot and the
    // children list, so more than one match is expected here.
    expect(find.text('Amani'), findsWidgets);
  });

  testWidgets('locale switches to Swahili', (tester) async {
    await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/'); // app opens on the welcome screen; enter the home
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose your language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();

    expect(find.text('Changamoto ya Leo'), findsOneWidget); // dailyChallenge
    expect(find.text('Jambo, Amani!'), findsOneWidget); // localized greeting
    // Note: subject tile names come from the curriculum content (English in the
    // source deck), so they are not localized yet — only UI chrome is.
  });

  /// Watoto keeps no session between launches: the email is remembered, the
  /// password or PIN is not. These run with the real gate in place.
  group('login gate', () {
    setUp(() => debugSkipLoginGate = false);
    tearDown(() => debugSkipLoginGate = true);

    Future<void> pumpTall(WidgetTester tester) async {
      // The login card plus its recovery links overflow a short viewport.
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
    }

    Future<void> tapLetsGo(WidgetTester tester) async {
      final letsGo = find.text("Let's go! 🚀");
      await tester.ensureVisible(letsGo);
      await tester.pump();
      await tester.tap(letsGo);
      await tester.pumpAndSettle();
    }

    testWidgets('"Let\'s go" leads to the login page, not the home',
        (tester) async {
      await seedOnboarded(); // PIN 1234
      await pumpTall(tester);

      // A returning family lands on the welcome screen, signed out.
      expect(find.text('Choose your language'), findsOneWidget);
      await tapLetsGo(tester);

      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Hello, Amani!'), findsNothing);
    });

    testWidgets('a stored account is remembered but its password is not',
        (tester) async {
      await store.completeOnboarding(
        consent: const ConsentRecord(
            coreData: true,
            aiFeatures: false,
            voiceRecording: false,
            recordedAt: null),
        accountEmail: 'mom@example.com',
        accountPassword: 'secret123',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: 2019,
      );
      // Onboarding logged them in; a relaunch must not inherit that session.
      await store.signOut();
      await pumpTall(tester);
      await tapLetsGo(tester);

      // Email prefilled, password demanded.
      expect(find.text('mom@example.com'), findsOneWidget);
      final password = find.byType(TextField).at(1);

      await tester.enterText(password, 'wrong-one');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong password, try again'), findsOneWidget);
      expect(find.text('Hello, Amani!'), findsNothing);

      await tester.enterText(password, 'secret123');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Amani!'), findsOneWidget);
    });

    testWidgets('a PIN family gets in with the PIN', (tester) async {
      await seedOnboarded(); // PIN 1234
      await pumpTall(tester);
      await tapLetsGo(tester);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Amani!'), findsOneWidget);
    });

    testWidgets('deep links are held at the gate, then handed back',
        (tester) async {
      await seedOnboarded();
      await pumpTall(tester);

      goTo(tester, '/curriculum');
      await tester.pumpAndSettle();
      // Gate first...
      expect(find.text('Welcome back!'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      // ...then the place they were actually going.
      expect(find.text('Welcome back!'), findsNothing);
      expect(find.textContaining('Curriculum'), findsWidgets);
    });

    testWidgets('someone locked out can still reach recovery', (tester) async {
      await seedOnboarded();
      await pumpTall(tester);
      await tapLetsGo(tester);

      final forgot = find.text('Forgot your PIN?');
      expect(forgot, findsOneWidget);
      await tester.ensureVisible(forgot);
      await tester.tap(forgot);
      await tester.pumpAndSettle();
      expect(find.text('Set new PIN'), findsOneWidget);
    });
  });
}
