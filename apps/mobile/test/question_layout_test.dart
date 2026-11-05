import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/audio/narration.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/library/play_shared.dart';
import 'package:watoto_mobile/features/library/play_stages.dart';
import 'package:watoto_mobile/features/library/step_motion.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

import 'support/phone_viewport.dart';

/// What a question screen does with the space it is not using.
///
/// A staged choice puts the pictures in the answers, so the skeleton's stage
/// has nothing left to show and gives its 300dp back (docs/26 §26.2). All of
/// that space then pooled into the single gap between the prompt and the
/// response: on a phone the question sat at the top, the answers sat at the
/// bottom, and half the screen in between was empty cream. These tests hold
/// the two things that fixed it — the slack is split around the answers, and
/// the prompt now offers to say itself again instead of leaving a void.
///
/// The split is unconditional rather than reserved for a collapsed stage: a
/// two-answer quiz under a full 300dp stage strands its answers the same way,
/// just less dramatically.

class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// A stage-1 lesson whose first step stages a choice — the screen this all
/// started from.
const _firstWords = LibraryItem(
  id: 's01.lang.lesson.01',
  stage: 1,
  ages: '0-1',
  subject: 'Early Language',
  type: LibraryType.lesson,
  title: 'First Words: Mama & Dada',
  objective: 'Hear and associate first words with faces.',
  designTier: 'parent-led',
  reading: false,
  interaction: 'tap',
  parentNote: "Record your own voice for 'mama'/'dada' in Settings.",
  // Two steps, so the primary button reads "Next" as it does on the real
  // screen — on a lesson's last step it reads "Done" instead.
  steps: [
    LessonStep(
      narration: 'Tap the smiling grown-up.',
      action: 'tap',
      feedback: "Warm voice: 'Mama!'",
      mechanic: 'tap',
    ),
    LessonStep(
      narration: 'Tap the other grown-up.',
      action: 'tap',
      feedback: "Warm voice: 'Dada!'",
      mechanic: 'tap',
    ),
  ],
);

void main() {
  late OfflineStore store;
  const viewport = Size(420, 900);

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
    debugDisableStepMotion = true;
    debugSkipLoginGate = true;
  });

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
    usePhoneViewport(size: viewport);
  });

  tearDown(() async {
    resetPhoneViewport();
    await store.close();
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_UnreachableApi()),
          libraryProvider
              .overrideWith((ref) async => LibraryRepository([_firstWords])),
        ],
        child: const WatotoApp(),
      );

  Future<void> openLesson(WidgetTester tester) async {
    await store.completeOnboarding(
      consent: const ConsentRecord(
        coreData: true,
        aiFeatures: false,
        voiceRecording: false,
        recordedAt: null,
      ),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2025,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(appRouterProvider)
        .go('/play/${_firstWords.id}');
    await tester.pumpAndSettle();
  }

  testWidgets('a collapsed stage does not leave a hole under the prompt',
      (tester) async {
    // Deliberately taller than a handset: the more room the screen is given,
    // the more a single Spacer had to pour into one gap, and the screenshot
    // that started this was a browser window about this tall. At 900dp the
    // fault is only 57px and would slip past unnoticed.
    const tall = Size(420, 1200);
    usePhoneViewport(size: tall);
    await openLesson(tester);

    final prompt = tester.getRect(find.text('Tap the smiling grown-up.'));
    final answers = tester.getRect(find.byType(ChoiceStage));
    final gap = answers.top - prompt.bottom;

    expect(answers.top, greaterThan(prompt.bottom));
    expect(
      gap,
      lessThan(tall.height * 0.30),
      reason: 'the answers are stranded ${gap.round()}px below the question',
    );
  });

  testWidgets('the leftover space is split above and below the answers',
      (tester) async {
    await openLesson(tester);

    final answers = tester.getRect(find.byType(ChoiceStage));
    final replay = tester.getRect(find.byType(ReplayNarrationButton));
    final assist = tester.getRect(find.byType(CoPlayTip));
    final next = tester.getRect(find.widgetWithText(FilledButton, 'Next'));

    final above = answers.top - replay.bottom;
    final below = assist.top - next.bottom;

    // Both gaps are real — neither side collapsed — and neither is more than
    // a fixed padding away from the other, which is what "split" means. A
    // single Spacer would send `above` to hundreds and `below` to ~12.
    expect(above, greaterThan(0));
    expect(below, greaterThan(0));
    expect(
      (above - below).abs(),
      lessThan(40),
      reason: 'slack is lopsided: ${above.round()} above, ${below.round()} below',
    );
  });

  testWidgets('the prompt offers to say itself again', (tester) async {
    await openLesson(tester);

    expect(find.byType(ReplayNarrationButton), findsOneWidget);
    expect(find.text('Hear it again'), findsOneWidget);

    // It sits with the prompt it replays, above the answers.
    final replay = tester.getRect(find.byType(ReplayNarrationButton));
    final prompt = tester.getRect(find.text('Tap the smiling grown-up.'));
    expect(replay.top, greaterThan(prompt.bottom));
    expect(replay.bottom, lessThan(tester.getRect(find.byType(ChoiceStage)).top));

    // Tapping replays rather than navigating or throwing.
    await tester.tap(find.byType(ReplayNarrationButton));
    await tester.pump();
    expect(find.text('Tap the smiling grown-up.'), findsOneWidget);
  });

  testWidgets('and is not there when narration is switched off',
      (tester) async {
    await openLesson(tester);
    expect(find.byType(ReplayNarrationButton), findsOneWidget);

    // A button promising to speak must disappear when nothing will be said.
    unawaited(ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(narrationProvider.notifier)
        .toggle());
    await tester.pumpAndSettle();

    expect(find.text('Hear it again'), findsNothing);
  });
}
