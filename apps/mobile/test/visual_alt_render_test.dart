import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/content_i18n.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/library/step_motion.dart';
import 'package:watoto_mobile/features/library/visual_stage.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

import 'support/phone_viewport.dart';

/// What the striped placeholder actually prints, on the screen, in French.
///
/// 1,512 parts of the library carry a brief for art nobody has drawn, and the
/// brief is rendered as text inside the placeholder. Authored in English, it
/// was printed in English to a child playing in French — mid-lesson, in the
/// middle of an otherwise fully translated screen. The model-level fix is held
/// in visual_alt_i18n_test.dart; this is the same fix seen from the seat the
/// child is sitting in.

class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// A lesson whose step points at art that is not bundled, so the stage falls
/// to the placeholder — the case this is about.
const _undrawn = LibraryItem(
  id: 's01.cause.lesson.01',
  stage: 1,
  ages: '0-1',
  subject: 'Cause & Effect',
  type: LibraryType.lesson,
  title: 'Tap to Make a Star',
  objective: 'Learn an action produces a result.',
  designTier: 'parent-led',
  reading: false,
  interaction: 'tap',
  steps: [
    LessonStep(
      narration: 'Tap the dark sky.',
      action: 'real-world',
      feedback: 'A star appears.',
      mechanic: 'celebrate',
      visual: SlotVisual(
        ref: 'img/s01/nothing_drawn_here.png',
        alt: "The dark sky, from the lesson 'Tap to Make a Star'",
      ),
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

  Future<void> openLessonIn(WidgetTester tester, String lang) async {
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
    await store.setLocaleCode(lang);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        offlineStoreProvider.overrideWithValue(store),
        syncApiProvider.overrideWithValue(_UnreachableApi()),
        libraryProvider
            .overrideWith((ref) async => LibraryRepository([_undrawn])),
      ],
      child: const WatotoApp(),
    ));
    await tester.pumpAndSettle();

    // The locale bundles are decoded on a background isolate, so they are not
    // there on the first frame. Waiting for them is the point: the assertions
    // below are about what a child reads once the app has finished loading,
    // not about the instant before it has.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(WatotoApp)));
    await tester.runAsync(() => container.read(contentI18nProvider.future));
    await tester.pump();

    container.read(appRouterProvider).go('/play/${_undrawn.id}');
    // Bounded pumps rather than pumpAndSettle: a lesson step that is showing
    // its stage keeps something moving, so settling never arrives.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  String placeholderText(WidgetTester tester) {
    final placeholder = tester.widget<StripedPlaceholder>(
      find.byType(StripedPlaceholder),
    );
    return placeholder.brief;
  }

  testWidgets('English prints the authored brief', (tester) async {
    await openLessonIn(tester, 'en');
    expect(find.byType(StripedPlaceholder), findsOneWidget);
    expect(placeholderText(tester),
        "The dark sky, from the lesson 'Tap to Make a Star'");
  });

  testWidgets('French prints French, not the English brief', (tester) async {
    await openLessonIn(tester, 'fr');
    expect(find.byType(StripedPlaceholder), findsOneWidget);

    final brief = placeholderText(tester);
    expect(brief, 'Touche le ciel sombre.');
    expect(brief, isNot(contains('dark sky')));
    expect(brief, isNot(contains('from the lesson')));
  });

  testWidgets('Swahili prints Swahili, not the English brief', (tester) async {
    await openLessonIn(tester, 'sw');
    expect(find.byType(StripedPlaceholder), findsOneWidget);

    final brief = placeholderText(tester);
    expect(brief, 'Gusa anga lenye giza.');
    expect(brief, isNot(contains('dark sky')));
  });
}
