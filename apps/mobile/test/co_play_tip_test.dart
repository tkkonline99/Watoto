/// The grown-up actually sees the note written for them.
///
/// Every stage-1 and stage-2 item carries a `parentNote` — "Hold baby close
/// and trace the swirl together", "Pat a real pot or drum together to feel the
/// beat" — and for the whole life of the app none of them was displayed. The
/// only reader was `coPlayTipFor` in play_style.dart, which nothing imported,
/// so 342 authored notes reached no parent. At the `parent-led` tier, where
/// the design says outright that the grown-up is the primary user, that note
/// is the lesson; the screen is the prompt.
///
/// These tests hold the wiring in place, and hold the line on where it stops:
/// a standing instruction to an adult who is not sitting there is clutter, so
/// older bands get nothing.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/library/play_shared.dart';
import 'package:watoto_mobile/features/library/step_motion.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

LibraryItem _lesson({
  required String id,
  required int stage,
  String? parentNote,
  String subject = 'Sensory Exploration',
}) =>
    LibraryItem(
      id: id,
      stage: stage,
      ages: stage <= 2 ? '0-1' : '6-7',
      subject: subject,
      type: LibraryType.lesson,
      title: 'Tap the Star',
      objective: '',
      designTier: stage <= 2 ? 'parent-led' : 'gamify-gently',
      reading: false,
      interaction: 'tap',
      parentNote: parentNote,
      steps: const [
        LessonStep(
          narration: 'Tap the star.',
          action: 'tap',
          feedback: 'A star!',
          mechanic: 'tap',
        ),
      ],
    );

final _withNote = _lesson(
  id: 'test.tip.noted',
  stage: 1,
  parentNote: 'Hold baby close and trace the swirl together.',
);
final _withoutNote = _lesson(id: 'test.tip.bare', stage: 1);
final _olderChild = _lesson(
  id: 'test.tip.older',
  stage: 7,
  subject: 'Math',
  parentNote: 'This note should not be shown to a seven-year-old.',
);

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
    debugDisableStepMotion = true;
    debugSkipLoginGate = true;
  });

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          libraryProvider.overrideWith(
            (ref) async =>
                LibraryRepository([_withNote, _withoutNote, _olderChild]),
          ),
        ],
        child: const WatotoApp(),
      );

  Future<void> seed() async {
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
      birthYear: 2024,
    );
  }

  Future<void> open(WidgetTester tester, String id) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(appRouterProvider)
        .go('/play/$id');
    await tester.pumpAndSettle();
  }

  testWidgets('a parent-led lesson shows its note to the grown-up',
      (tester) async {
    await open(tester, _withNote.id);
    expect(find.byType(CoPlayTip), findsOneWidget);
    expect(
      find.text('Hold baby close and trace the swirl together.'),
      findsOneWidget,
      reason: 'the authored note never reached the parent it was written for',
    );
  });

  testWidgets('a parent-led lesson with no note still gets a co-play tip',
      (tester) async {
    await open(tester, _withoutNote.id);
    expect(find.byType(CoPlayTip), findsOneWidget);
    // play_style carries a per-subject fallback for exactly this case.
    expect(
      find.textContaining('Hold the device together'),
      findsOneWidget,
      reason: 'the sensory fallback tip should stand in for a missing note',
    );
  });

  testWidgets('an older band gets no co-play tip', (tester) async {
    await open(tester, _olderChild.id);
    expect(
      find.text('This note should not be shown to a seven-year-old.'),
      findsNothing,
      reason: 'stage 7 plays alone; a standing note to an absent adult is '
          'just clutter on the child\'s screen',
    );
  });

  testWidgets('the tip is labelled for grown-ups, not aimed at the child',
      (tester) async {
    await open(tester, _withNote.id);
    expect(find.text('FOR GROWN-UPS'), findsOneWidget);
  });
}
