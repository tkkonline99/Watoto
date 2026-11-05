import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:watoto_mobile/core/audio/narration.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/data/cloud/cloud_sync.dart';
import 'package:watoto_mobile/features/auth/entitlements.dart';
import 'package:watoto_mobile/features/auth/iap_bridge.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/play_stages.dart';
import 'package:watoto_mobile/features/library/step_play.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
  });

  group('1. Bundled VO & Narration Word Progress', () {
    test('resolveVoAsset prefers active language MP3 and optionally falls back to EN', () {
      final available = <String>{
        'audio/sw/s01.animals.story.01.pages.0.narration.mp3',
        'audio/en/s01.animals.story.01.pages.1.narration.mp3',
      };

      expect(
        NarrationController.resolveVoAsset(
          'sw',
          's01.animals.story.01.pages.0.narration',
          available,
        ),
        'audio/sw/s01.animals.story.01.pages.0.narration.mp3',
      );

      // Without English fallback, missing Swahili clip returns null so TTS runs.
      expect(
        NarrationController.resolveVoAsset(
          'sw',
          's01.animals.story.01.pages.1.narration',
          available,
        ),
        isNull,
      );

      // With English fallback enabled, resolves to the English MP3.
      expect(
        NarrationController.resolveVoAsset(
          'sw',
          's01.animals.story.01.pages.1.narration',
          available,
          allowEnglishFallback: true,
        ),
        'audio/en/s01.animals.story.01.pages.1.narration.mp3',
      );
    });
  });

  group('2. Interactive Tracing & Sequencing Mechanics', () {
    test('planStep resolves trace mode and extracts target letter/shape', () {
      const item = LibraryItem(
        id: 's03.writing.lesson.01',
        stage: 3,
        ages: '2-3',
        subject: 'Tracing & Stories',
        type: LibraryType.lesson,
        title: 'Trace Letters',
        objective: '',
        designTier: 'encourage-effort',
        reading: false,
        interaction: 'trace',
      );

      final planLetter = planStep(
        item: item,
        stepIndex: 0,
        step: const LessonStep(
          narration: "Trace the letter 'A' with your finger!",
          action: 'trace',
          feedback: 'Great tracing!',
          mechanic: 'drag',
        ),
      );
      expect(planLetter.mechanic, StepMechanic.drag);
      expect(planLetter.dragMode, 'trace');
      expect(planLetter.traceTarget, 'A');

      final planCircle = planStep(
        item: item,
        stepIndex: 1,
        step: const LessonStep(
          narration: 'Trace a big circle in the air and on screen.',
          action: 'trace',
          feedback: 'Round and round!',
          mechanic: 'drag',
        ),
      );
      expect(planCircle.dragMode, 'trace');
      expect(planCircle.traceTarget, '○');
    });

    test('planStep resolves order mode for sequencing steps', () {
      const item = LibraryItem(
        id: 's05.math.lesson.02',
        stage: 5,
        ages: '4-5',
        subject: 'Math',
        type: LibraryType.lesson,
        title: 'Order Numbers',
        objective: '',
        designTier: 'encourage-effort',
        reading: false,
        interaction: 'drag',
      );

      final plan = planStep(
        item: item,
        stepIndex: 0,
        step: const LessonStep(
          narration: 'Put the blocks in order from 1 to 3.',
          action: 'order',
          feedback: '1, 2, 3!',
          mechanic: 'drag',
        ),
      );
      expect(plan.mechanic, StepMechanic.drag);
      expect(plan.dragMode, 'order');
    });

    testWidgets('DragStage in trace mode completes via finger pan gesture', (
      tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        _host(
          DragStage(
            emoji: '✏️',
            dragMode: 'trace',
            traceTarget: 'A',
            prompt: 'Trace the letter A!',
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pad = find.byKey(const ValueKey('trace-canvas-pad'));
      expect(pad, findsOneWidget);
      expect(find.text('A'), findsOneWidget);

      await tester.drag(pad, const Offset(80, 60));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets('DragStage in order mode completes when sequence tiles are tapped', (
      tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        _host(
          DragStage(
            emoji: '🌱',
            dragMode: 'order',
            prompt: 'Put them in order!',
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('order-sequence-rail')), findsOneWidget);
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(completed, isFalse);
      await tester.tap(find.text('2'));
      await tester.pump();
      expect(completed, isFalse);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });
  });

  group('3. End-to-End Cloud Snapshot Sync & Store Receipt Verification', () {
    test('CloudSyncClient pushes and merges family backup across stores', () async {
      final sourceStore = await OfflineStore.open(inMemory: true);

      final child = await sourceStore.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: 'Baraka',
        avatarKey: 'zebra',
        birthYear: 2020,
      );
      await sourceStore.recordLessonCompleted(
        childId: child.id,
        lessonId: 's01.animals.lesson.01',
        scorePct: 100,
        timeSpentS: 45,
        xpEarned: 25,
      );

      String? storedCloudBody;
      final mockHttp = MockClient((request) async {
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/accounts/uid-123/backup')) {
          storedCloudBody = request.body;
          return http.Response('{"ok":true}', 200);
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/accounts/uid-123/backup')) {
          return http.Response(storedCloudBody ?? '', storedCloudBody == null ? 404 : 200);
        }
        return http.Response('not found', 404);
      });

      final client = CloudSyncClient(
        client: mockHttp,
        baseUrl: 'https://api.watoto.app/v1',
      );

      final pushed = await client.pushFamilySnapshot(
        sourceStore,
        uid: 'uid-123',
        idToken: 'token-abc',
        email: 'parent@watoto.app',
      );
      expect(pushed, isTrue);
      expect(storedCloudBody, isNotNull);
      await sourceStore.close();

      // Simulate signing in on a fresh device by opening a new in-memory store.
      final freshStore = await OfflineStore.open(inMemory: true);
      addTearDown(freshStore.close);
      expect(freshStore.children, isEmpty);

      final merged = await client.pullAndMergeSnapshot(
        freshStore,
        uid: 'uid-123',
        idToken: 'token-abc',
      );
      expect(merged.childrenRestored, 1);
      expect(freshStore.children.first.nickname, 'Baraka');
      expect(freshStore.xpFor(child.id), 25);
    });

    test('StoreKitPlayPurchaseBridge + verifyStoreReceiptHttp grants verified entitlement', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('app.watoto.iap');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'buy') {
          return <String, dynamic>{
            'platform': 'ios',
            'receipt': 'appstore-jws-receipt-xyz',
          };
        }
        if (call.method == 'restore') {
          return <String, dynamic>{
            'platform': 'ios',
            'receipt': 'appstore-jws-restore-xyz',
          };
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);

      final expectedExpiry = DateTime.now().toUtc().add(const Duration(days: 365));
      final mockVerifyClient = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['platform'], 'ios');
        expect(body['receipt'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'valid': true,
            'entitlementExpiry': expectedExpiry.toIso8601String(),
          }),
          200,
        );
      });

      final service = EntitlementService(
        store,
        bridge: StoreKitPlayPurchaseBridge(channel: channel),
        verifier: ({
          required platform,
          required productId,
          required receipt,
          required accountToken,
        }) =>
            verifyStoreReceiptHttp(
          platform: platform,
          productId: productId,
          receipt: receipt,
          accountToken: accountToken,
          client: mockVerifyClient,
          verifyUrl: 'https://api.watoto.app/v1/billing/verify',
        ),
      );

      final entitlement = await service.subscribe(
        premiumAnnualId,
        accountToken: 'parent-uid-1',
      );
      expect(entitlement.isPremium, isTrue);
      expect(store.entitlementRaw.isPremium, isTrue);
    });
  });
}
