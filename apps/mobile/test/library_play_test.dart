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
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

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

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
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

  Widget buildApp() => ProviderScope(
    overrides: [
      offlineStoreProvider.overrideWithValue(store),
      syncApiProvider.overrideWithValue(_UnreachableApi()),
      libraryProvider.overrideWith(
        (ref) async => LibraryRepository([_tapLesson]),
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

      await tester.tap(find.text('🐘'));
      await tester.pumpAndSettle();
      expect(find.text('Yes! Elephant!'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Tap it again!'), findsOneWidget);

      await tester.tap(find.text('🐘'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Celebration + XP banked for the active child, and the streak started.
      expect(find.text('Great job!'), findsOneWidget);
      expect(find.text('+10 XP'), findsOneWidget);
      expect(store.xpFor(id), 10);
      expect(store.streakFor(id), 1);
    },
  );
}
