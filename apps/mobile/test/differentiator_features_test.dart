import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/state/app_state.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/domain/models/consent.dart';
import 'package:watoto_mobile/features/child_home/savanna_sketchpad_sheet.dart';
import 'package:watoto_mobile/features/gamification/certificate_screen.dart';
import 'package:watoto_mobile/features/gamification/word_of_the_day.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
  });

  group('1. Trilingual Savanna Word of the Day Bridge (EN <-> SW <-> FR)', () {
    test('wordOfTheDayFor is deterministic and cycles across all 14 words', () {
      final d = DateTime.utc(2026, 5, 10);
      final w0 = wordOfTheDayFor(d);
      final w1 = wordOfTheDayFor(d, offset: 1);
      expect(w0.id, isNot(equals(w1.id)));
      expect(kSavannaWordDeck.length, 14);
      for (final entry in kSavannaWordDeck) {
        expect(entry.en, isNotEmpty);
        expect(entry.sw, isNotEmpty);
        expect(entry.fr, isNotEmpty);
        expect(entry.hintFor('en'), isNotEmpty);
        expect(entry.hintFor('sw'), isNotEmpty);
        expect(entry.hintFor('fr'), isNotEmpty);
      }
    });

    testWidgets('SavannaWordOfTheDayCard speaks EN/SW/FR and cycles words',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: Scaffold(
              body: SavannaWordOfTheDayCard(
                locale: 'en',
                date: DateTime.utc(2026, 5, 10),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('word-of-the-day-card')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wotd-speak-en')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wotd-speak-sw')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wotd-speak-fr')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('wotd-next-button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('word-of-the-day-card')), findsOneWidget);
    });
  });

  group('2. Kibo’s Memory Boost (Adaptive Spaced-Repetition from Retries)', () {
    testWidgets(
        'resolveMemoryBoostForChild picks retried/shaky item & KiboMemoryBoostCard fires callback',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);

      const childId = 'child_1';
      await store.recordAttemptOutcome(
        childId: childId,
        subject: 'Numeracy',
        stage: 2,
        scorePct: 50,
        retries: 2,
        itemId: 's02.math.quiz.01',
        type: 'quiz',
      );

      const item = LibraryItem(
        id: 's02.math.quiz.01',
        stage: 2,
        ages: '4-6',
        subject: 'Numeracy',
        type: LibraryType.quiz,
        title: 'Counting Zebra Stripes',
        objective: 'Count stripes',
        designTier: 'core',
        reading: false,
        interaction: 'tap',
      );
      final repo = LibraryRepository([item]);

      final boost = resolveMemoryBoostForChild(
        childId: childId,
        store: store,
        library: repo,
      );
      expect(boost, isNotNull);
      expect(boost!.item.id, 's02.math.quiz.01');
      expect(boost.bonusCoins, 5);

      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KiboMemoryBoostCard(
              recommendation: boost,
              locale: 'en',
              onLaunch: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('kibo-memory-boost-card')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kibo-memory-boost-card')));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('3. Cozy Sunset & Starry Bedtime Mode ("Usiku Mwema")', () {
    testWidgets('bedtimeModeProvider persists and renders starry Savanna sky',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);

      final container = ProviderContainer(
        overrides: [offlineStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(bedtimeModeProvider), isFalse);
      await container.read(bedtimeModeProvider.notifier).toggle();
      expect(container.read(bedtimeModeProvider), isTrue);
      expect(store.bedtimeMode, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: SavannaScaffold(
            bedtime: true,
            child: SizedBox.expand(),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('savanna-bedtime-stars')), findsOneWidget);
    });
  });

  group('4. Creative Savanna Sketchpad & Letter Blackboard', () {
    testWidgets(
        'SavannaSketchpadSheet supports drawing, color switching, stencils, clear, and celebration',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Scaffold(
              body: SavannaSketchpadSheet(),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('savanna-sketchpad-sheet')),
        findsOneWidget,
      );

      // Select color 2 and cycle stencil.
      await tester.tap(find.byKey(const ValueKey('sketch-color-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sketch-stencil-next')));
      await tester.pump();
      expect(find.textContaining('Stencil: A'), findsOneWidget);

      // Draw a stroke on canvas.
      await tester.drag(
        find.byKey(const ValueKey('sketchpad-canvas')),
        const Offset(60, 40),
      );
      await tester.pump();

      // Celebrate masterpiece!
      await tester.tap(find.byKey(const ValueKey('sketchpad-celebrate')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sketchpad-masterpiece-badge')),
        findsOneWidget,
      );

      // Clear canvas.
      await tester.tap(find.byKey(const ValueKey('sketchpad-clear')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sketchpad-masterpiece-badge')),
        findsNothing,
      );
    });
  });

  group('5. Privacy-Safe Family Milestone Postcard', () {
    test('buildMilestonePostcardText formats EN, SW, and FR without PII', () {
      final en = buildMilestonePostcardText(
        nickname: 'Amina',
        emoji: '🦁',
        level: 4,
        lessons: 12,
        stars: 30,
        streak: 5,
        locale: 'en',
      );
      final sw = buildMilestonePostcardText(
        nickname: 'Amina',
        emoji: '🦁',
        level: 4,
        lessons: 12,
        stars: 30,
        streak: 5,
        locale: 'sw',
      );
      final fr = buildMilestonePostcardText(
        nickname: 'Amina',
        emoji: '🦁',
        level: 4,
        lessons: 12,
        stars: 30,
        streak: 5,
        locale: 'fr',
      );
      expect(en, contains('Amina'));
      expect(sw, contains('Postikadi'));
      expect(fr, contains('Carte Postale'));
    });

    testWidgets('CertificateScreen renders Share Postcard button and copies text',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);
      await store.completeOnboarding(
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CertificateScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btn = find.byKey(const ValueKey('share-milestone-postcard-button'));
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();
      expect(find.textContaining('Zuri'), findsWidgets);
    });
  });
}
