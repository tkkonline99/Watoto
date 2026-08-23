import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/library/step_motion.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

import 'support/phone_viewport.dart';

/// Whether the screens survive the accessibility setting the app offers.
///
/// "Text size" goes to 1.6, and `_ScaledTextScaler` deliberately *stacks* it on
/// the device's own setting rather than replacing it — so a parent who has
/// already enlarged text in Android settings and then turns Watoto's control up
/// is asking for well over 2x. Nothing tested any screen above 1.0, which meant
/// the one accessibility feature a low-vision reader would reach for first was
/// the one nothing had ever rendered.
///
/// An overflowing RenderFlex throws during paint, and `takeException` is how a
/// widget test hears it.
class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// Long text on purpose: real content has prompts this size, and a short
/// fixture would pass at any scale and prove nothing.
const _lesson = LibraryItem(
  id: 's04.math.lesson.01',
  stage: 4,
  ages: '4-5',
  subject: 'Mathematics',
  type: LibraryType.lesson,
  title: 'Counting Groups of Things',
  objective: 'Count a group and say how many.',
  designTier: 'encourage-effort',
  reading: true,
  interaction: 'tap',
  steps: [
    LessonStep(
      narration: 'Look at the basket of mangoes on the table. '
          'Count them one at a time, and say the number out loud as you go.',
      action: 'count',
      feedback: 'You counted every mango in the basket. That is six!',
      mechanic: 'count',
      count: 6,
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
    // 360x780 — a small-but-real Android handset, not a flagship.
    usePhoneViewport(size: const Size(360, 780));
  });

  tearDown(() async {
    resetPhoneViewport();
    await store.close();
  });

  Future<void> open(WidgetTester tester, String route, double scale) async {
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
      birthYear: 2021,
    );
    await store.setTextScale(scale);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        offlineStoreProvider.overrideWithValue(store),
        syncApiProvider.overrideWithValue(_UnreachableApi()),
        libraryProvider
            .overrideWith((ref) async => LibraryRepository([_lesson])),
      ],
      child: const WatotoApp(),
    ));
    await tester.pumpAndSettle();
    if (route != '/') {
      ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
          .read(appRouterProvider)
          .go(route);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }
  }

  // The case the stacking is for, and the harshest the app can be asked to
  // render: the device already enlarged to 1.3, and Watoto's own control then
  // turned to its maximum on top of it.
  // This is the one that was broken. `SavannaScaffold`'s top bar laid the
  // wordmark out at its natural width, and at about 2x it was wider than the
  // bar — so the account, language and parent-zone buttons were pushed off the
  // right edge on every screen built on that scaffold, onboarding included.
  testWidgets('the home screen lays out at 1.6 on top of a 1.3 device setting',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, '/', 1.6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lesson lays out at 1.6 on top of a 1.3 device setting',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, '/play/${_lesson.id}', 1.6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the parent zone lays out at 1.6 on top of a 1.3 device setting',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, '/parent', 1.6);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.3, 1.6]) {
    testWidgets('the home screen lays out at text scale $scale',
        (tester) async {
      await open(tester, '/', scale);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a lesson lays out at text scale $scale', (tester) async {
      await open(tester, '/play/${_lesson.id}', scale);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the parent zone lays out at text scale $scale',
        (tester) async {
      await open(tester, '/parent', scale);
      expect(tester.takeException(), isNull);
    });
  }
}
