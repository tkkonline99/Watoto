import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/library/step_motion.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

/// Long enough to reveal a step's feedback, short enough that the player's
/// auto-advance (1400ms after the interaction) has not fired yet.
const _feedbackBeat = Duration(milliseconds: 300);

/// Pump interval that always clears the auto-advance timer, landing on
/// whatever the player moves to next.
const _autoAdvance = Duration(milliseconds: 1500);

class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

// A synthetic tap-interaction lesson (subject "Animals" → 🐘 stage emoji).
final _tapLesson = LibraryItem(
  id: 'test.tap.1',
  stage: 3,
  ages: '2-3',
  subject: 'Animals',
  type: LibraryType.lesson,
  title: 'Tap the Animal',
  objective: '',
  designTier: 'guided',
  reading: false,
  interaction: 'tap',
  steps: const [
    LessonStep(
      narration: 'Tap the elephant!',
      action: 'tap',
      feedback: 'Yes! Elephant!',
    ),
    LessonStep(
      narration: 'Tap it again!',
      action: 'tap',
      feedback: 'Well done!',
    ),
  ],
);

// A quiz in the same stage+subject as _tapLesson: deterministic "next
// activity" after the lesson (items sort lessons before quizzes).
final _animalQuiz = LibraryItem(
  id: 'test.quiz.1',
  stage: 3,
  ages: '2-3',
  subject: 'Animals',
  type: LibraryType.quiz,
  title: 'Animal Quiz',
  objective: '',
  designTier: 'guided',
  reading: false,
  interaction: 'single-select',
  questions: const [
    LibQuestion(
      prompt: 'Which one says woof?',
      options: [
        LibOption(label: 'Dog'),
        LibOption(label: 'Cat'),
      ],
      answer: 0,
      correctFeedback: 'Woof!',
      retryFeedback: 'Try again!',
    ),
  ],
);

// A reading step that quotes the word to find — must stage TEXT choices.
final _wordLesson = LibraryItem(
  id: 'test.word.1',
  stage: 7,
  ages: '6-7',
  subject: 'Reading',
  type: LibraryType.lesson,
  title: 'Short and Long Vowels',
  objective: '',
  designTier: 'guided',
  reading: true,
  interaction: 'tap',
  steps: const [
    LessonStep(
      narration: "'cap' has a SHORT a. Tap 'cap'.",
      action: 'tap-word',
      feedback: 'Short a!',
    ),
  ],
);

// A directive step naming an object ("ball") — must stage a multiple choice.
final _choiceLesson = LibraryItem(
  id: 'test.choice.1',
  stage: 4,
  ages: '3-4',
  subject: 'Language & Literacy',
  type: LibraryType.lesson,
  title: 'First Sounds',
  objective: '',
  designTier: 'guided',
  reading: false,
  interaction: 'tap',
  steps: const [
    LessonStep(
      narration: 'Ball starts with /b/. Tap the ball.',
      action: 'tap-correct',
      feedback: 'Yes! Ball starts with /b/!',
    ),
  ],
);

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    // The celebration screen bounces Kibo forever; hold him still so
    // pumpAndSettle can return.
    debugDisableMascotAnimation = true;
    // Same for the step illustration, which breathes for as long as it is on
    // screen.
    debugDisableStepMotion = true;
  });

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  void goTo(WidgetTester tester, String location) => ProviderScope.containerOf(
    tester.element(find.byType(WatotoApp)),
  ).read(appRouterProvider).go(location);

  /// The tap target inside the interaction stage. A step also shows the item's
  /// illustration above it, which falls back to the same emoji when no artwork
  /// is bundled — the stage is the one that comes last.
  Finder tapTarget(String emoji) => find.text(emoji).last;

  Widget buildApp() => ProviderScope(
    overrides: [
      offlineStoreProvider.overrideWithValue(store),
      syncApiProvider.overrideWithValue(_UnreachableApi()),
      libraryProvider.overrideWith(
        (ref) async => LibraryRepository([
          _tapLesson,
          _animalQuiz,
          _wordLesson,
          _choiceLesson,
        ]),
      ),
    ],
    child: const WatotoApp(),
  );

  Future<String> seed() async {
    final child = await store.completeOnboarding(
      consent: const ConsentRecord(
        coreData: true,
        aiFeatures: false,
        voiceRecording: false,
        recordedAt: null,
      ),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2022,
    );
    return child.id;
  }

  testWidgets(
    'tap lesson: interaction gates Next, then completes and banks XP',
    (tester) async {
      final id = await seed();
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      goTo(tester, '/play/${_tapLesson.id}');
      await tester.pumpAndSettle();

      // Caption is shown and Next is disabled until the child taps the picture.
      expect(find.text('Tap the elephant!'), findsOneWidget);
      final next = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(next.onPressed, isNull);

      await tester.tap(tapTarget('🐘'));
      await tester.pump(_feedbackBeat);
      expect(find.text('Yes! Elephant!'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Tap it again!'), findsOneWidget);

      // Finishing the last step auto-advances into the celebration a beat
      // later — no Done tap needed.
      await tester.tap(tapTarget('🐘'));
      await tester.pumpAndSettle(_autoAdvance);

      // Celebration + XP banked for the active child, and the streak started.
      expect(find.text('Perfect!'), findsOneWidget);
      expect(find.text('+10 XP'), findsOneWidget);
      expect(store.xpFor(id), 10);
      expect(store.streakFor(id), 1);

      // Back on the subject page, the finished lesson wears the done mark;
      // the untouched quiz keeps its play icon.
      await tester.ensureVisible(find.text('Done'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      goTo(tester, '/subject/3/Animals');
      await tester.pumpAndSettle();
      expect(find.text('✅'), findsOneWidget);
    },
  );

  testWidgets('directive step ("Tap the ball") stages a real multiple choice', (
    tester,
  ) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    goTo(tester, '/play/${_choiceLesson.id}');
    await tester.pumpAndSettle();

    // The plan is deterministic: the ball plus two same-category
    // distractors, all rendered on screen.
    final plan = choicePlanFor(
      _choiceLesson.id,
      0,
      _choiceLesson.steps[0].narration,
    )!;
    expect(plan.options, hasLength(3));
    expect(plan.options[plan.targetIndex].emoji, '⚽');
    for (final o in plan.options) {
      expect(find.text(o.emoji), findsOneWidget);
    }

    // A wrong pick does not advance: Done stays disabled, retry appears.
    final wrong = plan.targetIndex == 0 ? 1 : 0;
    await tester.tap(find.text(plan.options[wrong].emoji));
    await tester.pumpAndSettle();
    expect(find.text('So close! Try again!'), findsOneWidget);
    final done = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Done'),
    );
    expect(done.onPressed, isNull);

    // The right pick reveals feedback, then auto-advances to the celebration.
    await tester.tap(find.text('⚽'));
    await tester.pump(_feedbackBeat);
    expect(find.text('Yes! Ball starts with /b/!'), findsOneWidget);
    await tester.pumpAndSettle(_autoAdvance);
    expect(find.text('Perfect!'), findsOneWidget);
    // Last item of its subject — no chain offered.
    expect(find.text('Keep going!'), findsNothing);
  });

  testWidgets('quoted-word step ("Tap \'cap\'") stages text choices', (
    tester,
  ) async {
    await seed();
    // The reading fixture sits at stage 7, past the free tier — unlock it so
    // this test exercises the word choices, not the paywall.
    await store.setLocalPremium(true);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    goTo(tester, '/play/${_wordLesson.id}');
    await tester.pumpAndSettle();

    final plan = choicePlanFor(
      _wordLesson.id,
      0,
      _wordLesson.steps[0].narration,
    )!;
    expect(plan.options[plan.targetIndex].emoji, 'cap');
    // The silent-e minimal pair is the leading distractor.
    expect(plan.options.map((o) => o.emoji), contains('cape'));
    for (final o in plan.options) {
      expect(find.text(o.emoji), findsOneWidget, reason: o.emoji);
    }

    // Picking the look-alike word does not advance.
    await tester.tap(find.text('cape'));
    await tester.pumpAndSettle();
    expect(find.text('So close! Try again!'), findsOneWidget);
    final done = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Done'),
    );
    expect(done.onPressed, isNull);

    // Reading the right word completes the step.
    await tester.tap(find.text('cap'));
    await tester.pump(_feedbackBeat);
    expect(find.text('Short a!'), findsOneWidget);
    // Drain the auto-advance so no timer outlives the test.
    await tester.pumpAndSettle(_autoAdvance);
  });

  testWidgets('celebration chains into the next activity in the subject', (
    tester,
  ) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Complete the animals lesson (choice step, then fallback tap step).
    goTo(tester, '/play/${_tapLesson.id}');
    await tester.pumpAndSettle();
    await tester.tap(tapTarget('🐘'));
    await tester.pump(_feedbackBeat);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(tapTarget('🐘'));
    await tester.pumpAndSettle(_autoAdvance);

    // The celebration offers the next item (the Animals quiz)…
    expect(find.text('Keep going!'), findsOneWidget);
    await tester.ensureVisible(find.text('Keep going!'));
    await tester.pump();
    await tester.tap(find.text('Keep going!'));
    await tester.pumpAndSettle();

    // …which opens directly, with the illustrated option ("Dog" → 🐶).
    expect(find.text('Which one says woof?'), findsOneWidget);
    expect(find.text('🐶'), findsOneWidget);
  });

  testWidgets('chaining lesson -> lesson opens the new lesson, not the '
      'finished one', (tester) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Finish the first lesson to reach its celebration.
    goTo(tester, '/play/${_tapLesson.id}');
    await tester.pumpAndSettle();
    await tester.tap(tapTarget('🐘'));
    await tester.pump(_feedbackBeat);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(tapTarget('🐘'));
    await tester.pumpAndSettle(_autoAdvance);
    expect(find.text('Perfect!'), findsOneWidget);

    // /play/:id -> /play/:otherId is the same route: without a per-item key
    // the finished lesson's state is reused and the child stares at the old
    // celebration instead of the new activity.
    goTo(tester, '/play/${_choiceLesson.id}');
    await tester.pumpAndSettle();
    expect(find.text('Perfect!'), findsNothing);
    expect(find.text('Ball starts with /b/. Tap the ball.'), findsOneWidget);
  });
}
