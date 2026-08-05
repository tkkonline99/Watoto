/// The `build-circuit` step must be a circuit, not a quiz about one.
///
/// s10.science.lesson.01 opens with `action: "build-circuit"`, an authored
/// mechanic the planner had no case for. It fell through to a two-option
/// multiple choice — "A broken wire" / "A complete loop" — which asks a child
/// to recall the answer to the thing the step exists to let them find out.
library;

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
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/library/play_stage_circuit.dart';
import 'package:watoto_mobile/features/library/step_motion.dart';
import 'package:watoto_mobile/features/library/step_play.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// The real opening step of the shipped circuits lesson.
final _lesson = LibraryItem(
  id: 'test.circuit',
  stage: 10,
  ages: '9-10',
  subject: 'Science',
  type: LibraryType.lesson,
  title: 'Electricity and Circuits',
  objective: '',
  designTier: 'grant-autonomy',
  reading: true,
  interaction: 'build-circuit',
  steps: const [
    LessonStep(
      narration: 'Connect the battery, wire, and bulb to make a loop.',
      action: 'build-circuit',
      feedback: 'The loop is closed, so the bulb lights.',
    ),
    LessonStep(
      narration: 'Now open a gap in the wire.',
      action: 'build-circuit',
      feedback: 'One gap stops everything.',
    ),
  ],
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

  test('"build-circuit" plans the circuit builder, not a choice', () {
    final plan = planStep(
      item: _lesson,
      stepIndex: 0,
      step: _lesson.steps.first,
    );
    expect(plan.mechanic, StepMechanic.buildCircuit);
    expect(plan.circuitMode, 'build');
    expect(
      plan.choices,
      isEmpty,
      reason: 'a circuit step must not offer answer options',
    );
  });

  test('"open a gap" runs the same board backwards', () {
    final plan = planStep(
      item: _lesson,
      stepIndex: 1,
      step: _lesson.steps[1],
    );
    expect(plan.mechanic, StepMechanic.buildCircuit);
    expect(
      plan.circuitMode,
      'gap',
      reason: 'an empty board under "open a gap in the wire" asks the child '
          'to do the opposite of what the step says',
    );
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_UnreachableApi()),
          libraryProvider.overrideWith(
            (ref) async => LibraryRepository([_lesson]),
          ),
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
      birthYear: 2016,
    );
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(appRouterProvider)
        .go('/play/${_lesson.id}');
    await tester.pumpAndSettle();
  }

  /// The board plus the tray is taller than the play viewport, so a token has
  /// to be scrolled to before it can be tapped.
  Future<void> tapToken(WidgetTester tester, Finder token) async {
    await tester.ensureVisible(token);
    await tester.pump();
    await tester.tap(token);
    await tester.pump();
  }

  testWidgets('the board and all three parts are on screen', (tester) async {
    await openLesson(tester);

    expect(find.byType(CircuitBuildStage), findsOneWidget);
    expect(find.text('Battery'), findsOneWidget);
    expect(find.text('Wire'), findsOneWidget);
    expect(find.text('Bulb'), findsOneWidget);
    expect(find.text('Drop each part into its socket'), findsOneWidget);

    // The old fallback's options must be gone.
    expect(find.text('A broken wire'), findsNothing);
    expect(find.text('A complete loop'), findsNothing);
  });

  testWidgets('the loop only closes once every part is in', (tester) async {
    await openLesson(tester);

    final next = find.widgetWithText(FilledButton, 'Next');
    expect(
      tester.widget<FilledButton>(next).onPressed,
      isNull,
      reason: 'an empty board is not a finished circuit',
    );

    // Tap-to-place is the accessible equivalent of the drag.
    await tapToken(tester, find.byKey(circuitPartKey(CircuitPart.battery)));
    await tapToken(tester, find.byKey(circuitPartKey(CircuitPart.wire)));
    expect(
      tester.widget<FilledButton>(next).onPressed,
      isNull,
      reason: 'two of three parts still leaves a gap',
    );

    await tapToken(tester, find.byKey(circuitPartKey(CircuitPart.bulb)));
    expect(find.text('The loop is complete — the bulb lights up!'),
        findsOneWidget);
    expect(
      find.text('Drop each part into its socket'),
      findsNothing,
      reason: 'the board is still telling the child to do what they just did',
    );

    // The bulb is shown lit for a beat before the step reports itself done.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
    await tester.pumpAndSettle();
  });

  testWidgets('the gap step starts whole and completes when broken',
      (tester) async {
    await openLesson(tester);

    // Finish the build step to reach the gap step.
    for (final part in CircuitPart.values) {
      await tapToken(tester, find.byKey(circuitPartKey(part)));
    }
    // Both beats have to be pumped explicitly: with step motion disabled no
    // animation is scheduled, so pumpAndSettle returns without moving the
    // clock and neither timer would ever fire.
    await tester.pump(const Duration(milliseconds: 1000)); // stage reports done
    await tester.pump(const Duration(milliseconds: 1500)); // player advances
    await tester.pumpAndSettle();

    expect(find.text('Now open a gap in the wire.'), findsOneWidget);
    expect(find.text('Take one part out to break the loop'), findsOneWidget);
    // The loop arrives already made — there is nothing to break otherwise.
    expect(find.byKey(circuitSocketKey(CircuitPart.wire)), findsOneWidget);

    final done = find.widgetWithText(FilledButton, 'Done');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);

    await tapToken(tester, find.byKey(circuitSocketKey(CircuitPart.wire)));
    expect(find.text('The loop is open — the bulb goes dark.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
  });
}
