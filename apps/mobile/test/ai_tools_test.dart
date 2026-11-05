import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:watoto_mobile/core/ai/watoto_ai_engine.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/domain/models/consent.dart';
import 'package:watoto_mobile/features/ai/ai_smart_practice_sheet.dart';
import 'package:watoto_mobile/features/ai/ai_story_weaver_sheet.dart';
import 'package:watoto_mobile/features/ai/ask_kibo_sheet.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/features/parent/parent_dashboard_screen.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
  });

  group('1. COPPA-Safe Hybrid WatotoAiEngine & PII Sanitization', () {
    test('sanitizeAiPayload strips all PII keys before any network call', () {
      final raw = <String, Object?>{
        'nickname': 'Zuri',
        'child_name': 'Zuri',
        'email': 'parent@example.com',
        'birthYear': 2020,
        'deviceId': 'dev-123',
        'childId': 'c-1',
        'pin': '1234',
        'subject': 'Numeracy',
        'stage': 2,
        'locale': 'sw',
      };
      final sanitized = sanitizeAiPayload(raw);
      expect(sanitized.keys, unorderedEquals(['subject', 'stage', 'locale']));
      expect(sanitized.containsKey('nickname'), isFalse);
      expect(sanitized.containsKey('email'), isFalse);
      expect(sanitized.containsKey('deviceId'), isFalse);
    });

    test('WatotoAiEngine respects parent consent.aiFeatures for cloud calls',
        () async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);

      var networkCalled = false;
      final mockHttp = MockClient((req) async {
        networkCalled = true;
        return http.Response(
          jsonEncode({
            'headline': 'Cloud Kibo',
            'body': 'Cloud Socratic explanation!',
          }),
          200,
        );
      });

      final engine = WatotoAiEngine(
        store: store,
        httpClient: mockHttp,
        endpoint: 'https://ai.watoto.app/v1/socratic',
      );

      // Default consent.aiFeatures is false -> must NOT call network, uses offline synthesizer.
      expect(engine.isAiConsentEnabled, isFalse);
      final offlineReply = await engine.generateSocraticResponse(
        kind: AiCuriosityKind.simpler,
        subject: 'Numeracy',
        stage: 2,
        promptContext: 'Count 3 zebras',
        locale: 'en',
      );
      expect(networkCalled, isFalse);
      expect(offlineReply.fromCloud, isFalse);
      expect(offlineReply.body, isNotEmpty);

      // Enable consent.aiFeatures -> cloud endpoint is allowed and used.
      await store.saveConsent(
        const ConsentRecord(
          coreData: true,
          aiFeatures: true,
          voiceRecording: false,
          recordedAt: null,
        ),
      );
      expect(engine.isAiConsentEnabled, isTrue);
      final cloudReply = await engine.generateSocraticResponse(
        kind: AiCuriosityKind.simpler,
        subject: 'Numeracy',
        stage: 2,
        promptContext: 'Count 3 zebras',
        locale: 'en',
      );
      expect(networkCalled, isTrue);
      expect(cloudReply.fromCloud, isTrue);
      expect(cloudReply.body, 'Cloud Socratic explanation!');
    });
  });

  group('2. Ask Kibo Socratic AI Helper (Guided Curiosity Chips)', () {
    testWidgets(
        'AskKiboSheet switches between all 4 curiosity chips in EN, SW, and FR',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Scaffold(
              body: AskKiboSheet(
                subject: 'Numeracy',
                stage: 2,
                promptContext: 'How many stripes are on 2 zebras?',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ask-kibo-sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('ask-kibo-response-text')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ask-kibo-chip-clue')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Rule out one tricky option'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('ask-kibo-chip-fact')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Did you know?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ask-kibo-chip-trilingual')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hesabu'), findsOneWidget);
    });
  });

  group('3. Kibo’s AI Story Weaver (Co-Created Trilingual Storybooks)', () {
    testWidgets(
        'AiStoryWeaverSheet weaves a 3-page story, reads along, and awards coins on quiz',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);
      final child = await store.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: true,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: 'Amina',
        birthYear: 2020,
        avatarKey: 'lion',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AiStoryWeaverSheet(),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('ai-story-weaver-sheet')), findsOneWidget);

      // Pick Giraffe + River Oasis + Counting.
      await tester.tap(find.byKey(const ValueKey('story-hero-giraffe')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('story-place-oasis')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('story-theme-counting')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('weave-story-button')));
      await tester.pump();

      // Page 1, 2, 3
      expect(find.byKey(const ValueKey('woven-story-page-text')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('woven-story-next-page')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('woven-story-next-page')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('woven-story-next-page')));
      await tester.pump();

      // Comprehension check
      expect(find.byKey(const ValueKey('woven-story-question')), findsOneWidget);
      final beforeCoins = store.coinsFor(child.id);
      await tester.tap(find.byKey(const ValueKey('woven-story-option-0')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('woven-story-celebration')),
        findsOneWidget,
      );
      expect(store.coinsFor(child.id), beforeCoins + 5);
    });
  });

  group('4. AI Smart Practice Adaptive Micro-Quiz', () {
    testWidgets(
        'AiSmartPracticeSheet walks through 3 adaptive questions with Socratic explanations',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);
      final child = await store.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: true,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: 'Baraka',
        birthYear: 2019,
        avatarKey: 'elephant',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AiSmartPracticeSheet(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('ai-smart-practice-sheet')),
        findsOneWidget,
      );

      for (int q = 0; q < 3; q++) {
        await tester.tap(find.byKey(const ValueKey('smart-practice-option-0')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('smart-practice-explanation')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('smart-practice-next')));
        await tester.pumpAndSettle();
      }

      expect(
        find.byKey(const ValueKey('smart-practice-complete')),
        findsOneWidget,
      );
      expect(store.coinsFor(child.id), 5);
    });
  });

  group('5. AI Parent Coach & Offline Activity Recommender in Parent Zone', () {
    testWidgets(
        'ParentDashboardScreen renders AI Parent Coach card, offline games, and consent toggle',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);
      final child = await store.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: 'Zuri',
        birthYear: 2020,
        avatarKey: 'giraffe',
      );
      await store.recordAttemptOutcome(
        childId: child.id,
        subject: 'Numeracy',
        stage: 2,
        scorePct: 45,
        retries: 3,
        itemId: 's02.math.quiz.01',
        type: 'quiz',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ParentDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ai-parent-coach-card')),
        200,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai-parent-coach-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-coach-activity-0')), findsOneWidget);

      // Toggle AI consent directly from the AI Parent Coach card.
      expect(store.consent.aiFeatures, isFalse);
      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-coach-consent-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-coach-consent-toggle')));
      await tester.pumpAndSettle();
      expect(store.consent.aiFeatures, isTrue);
    });
  });
}
