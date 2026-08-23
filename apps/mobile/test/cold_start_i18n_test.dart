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

/// What the first item played after a cold start is in.
///
/// The locale bundles load asynchronously, and nothing on the way to a play
/// screen touches them — so the screen that needs them is usually the screen
/// that starts them loading. Every play screen read the bundle as a snapshot
/// (`ref.read(...).asData?.value`), which is null while it loads, and the quiz
/// then *cached* what it built from that null for the whole run.
///
/// So the first quiz a Swahili child opened after launching the app asked its
/// questions in English, and went on doing so until they left the screen.
class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

const _quiz = LibraryItem(
  id: 's01.object.quiz.01',
  stage: 1,
  ages: '0-1',
  subject: 'Object Permanence',
  type: LibraryType.quiz,
  title: 'Where Did Teddy Go?',
  objective: '',
  designTier: 'parent-led',
  reading: false,
  interaction: 'tap',
  questions: [
    LibQuestion(
      prompt: 'Teddy hid under a cup. Tap the cup he is under.',
      options: [LibOption(label: 'Left cup'), LibOption(label: 'Right cup')],
      answer: 0,
      correctFeedback: 'There he is!',
      retryFeedback: 'Lift a cup and peek.',
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
    usePhoneViewport(size: const Size(420, 900));
  });

  tearDown(() async {
    resetPhoneViewport();
    await store.close();
  });

  testWidgets('the first quiz after a cold start is in the child\'s language',
      (tester) async {
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
    await store.setLocaleCode('fr');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        offlineStoreProvider.overrideWithValue(store),
        syncApiProvider.overrideWithValue(_UnreachableApi()),
        libraryProvider.overrideWith((ref) async => LibraryRepository([_quiz])),
      ],
      child: const WatotoApp(),
    ));
    await tester.pumpAndSettle();

    // Straight into the quiz, exactly as a cold start does: nothing has asked
    // for the locale bundle yet, so this screen is what starts it loading.
    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(appRouterProvider)
        .go('/play/${_quiz.id}');

    // Real async time, so the bundle genuinely finishes loading — the point is
    // not that it is slow, it is that the screen must use it once it arrives.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)));
    }
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Teddy hid under a cup. Tap the cup he is under.'),
        findsNothing,
        reason: 'the quiz is asking a French child its question in English');
    expect(
        find.text("Nounours s'est caché sous un gobelet. Touche le "
            'gobelet o\u00f9 il se trouve.'),
        findsOneWidget);
  });
}
