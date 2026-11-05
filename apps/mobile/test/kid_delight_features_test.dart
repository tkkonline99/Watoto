import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/audio/narration.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/domain/models/consent.dart';
import 'package:watoto_mobile/features/child_home/child_home_screen.dart';
import 'package:watoto_mobile/features/gamification/savanna_world.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/library/play_celebration.dart';
import 'package:watoto_mobile/features/library/play_stages.dart';
import 'package:watoto_mobile/features/library/play_story_view.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
  });

  group('1. Karaoke Read-Along Word Highlighting & Tap-a-Word', () {
    test('StoryReadAlongBar.tokenize splits sentence into word spans', () {
      const sentence = 'Little Duck waddled to the pond.';
      final tokens = StoryReadAlongBar.tokenize(sentence);
      expect(tokens.map((t) => t.word).toList(), [
        'Little',
        'Duck',
        'waddled',
        'to',
        'the',
        'pond.',
      ]);
      expect(sentence.substring(tokens[1].start, tokens[1].end), 'Duck');
    });

    testWidgets('tapping a word pill triggers phonics replay and activeWord highlights', (
      tester,
    ) async {
      const sentence = 'Jambo Simba rafiki!';
      final activeWord = ValueNotifier<NarrationWordSpan?>(null);
      addTearDown(activeWord.dispose);

      int? tappedIdx;
      String? tappedWord;

      await tester.pumpWidget(
        _host(
          StoryReadAlongBar(
            narration: sentence,
            activeWordNotifier: activeWord,
            tappedWordIndex: tappedIdx,
            onWordTap: (i, w) {
              tappedIdx = i;
              tappedWord = w;
            },
          ),
        ),
      );

      expect(find.byKey(const ValueKey('story-read-along-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('story-word-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('story-word-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('story-word-2')), findsOneWidget);

      // Update activeWord notifier as TTS progresses across 'Simba'.
      activeWord.value = const NarrationWordSpan(
        text: sentence,
        start: 6,
        end: 11,
        word: 'Simba',
      );
      await tester.pump(const Duration(milliseconds: 160));

      // Tap the second word pill ('Simba').
      await tester.tap(find.byKey(const ValueKey('story-word-1')));
      await tester.pump();
      expect(tappedIdx, 1);
      expect(tappedWord, 'Simba');
    });
  });

  group('2 & 4. Interactive Savanna Sticker World & Ticklish Mascot Companion', () {
    test('savannaStickerGreeting and mascotTickleSpeech support EN, SW, and FR', () {
      expect(savannaStickerGreeting('zebra', 'en'), contains('zebra'));
      expect(savannaStickerGreeting('zebra', 'sw'), contains('punda milia'));
      expect(savannaStickerGreeting('zebra', 'fr'), contains('zèbre'));

      expect(mascotTickleSpeech(0, 'en', hour: 9), contains('Good morning'));
      expect(mascotTickleSpeech(0, 'sw', hour: 9), contains('asubuhi'));
      expect(mascotTickleSpeech(0, 'fr', hour: 20), contains('Bonsoir'));
    });

    testWidgets('ChildHomeScreen lets child tickle Kibo and tap unlocked Savanna stickers', (
      tester,
    ) async {
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
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: 2020,
      );
      await store.markGuidedTourDone(child.id);
      await store.markSubjectCompleted(child.id, 'Math'); // unlocks 'zebra'

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            offlineStoreProvider.overrideWithValue(store),
            libraryProvider.overrideWith(
              (ref) async => LibraryRepository(const <LibraryItem>[]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChildHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tickle Kibo on the home screen.
      final tickleTarget = find.byKey(const ValueKey('mascot-tickle-target'));
      expect(tickleTarget, findsOneWidget);
      await tester.tap(tickleTarget);
      await tester.pumpAndSettle();

      // Speech line updates to a playful tickle greeting.
      final speechWidget = tester.widget<Text>(
        find.byKey(const ValueKey('mascot-speech-line')),
      );
      expect(speechWidget.data, isNotNull);
      expect(speechWidget.data!.isNotEmpty, isTrue);

      // 2. Tap the unlocked zebra sticker in the Savanna Sticker Bar.
      expect(find.byKey(const ValueKey('savanna-sticker-bar')), findsOneWidget);
      final zebraSticker = find.byKey(const ValueKey('savanna-sticker-zebra'));
      expect(zebraSticker, findsOneWidget);
      await tester.tap(zebraSticker);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('savanna-sticker-fact')), findsOneWidget);
      expect(
        find.text('Jambo! Every zebra has one-of-a-kind stripes!'),
        findsOneWidget,
      );
    });
  });

  group('3. Tactile Savanna Marimba & Drum Rhythm Pad', () {
    test('SavannaRhythmPad.isMusicStep detects music and drum prompts', () {
      expect(SavannaRhythmPad.isMusicStep('🥁', null), isTrue);
      expect(SavannaRhythmPad.isMusicStep('🎵', null), isTrue);
      expect(
        SavannaRhythmPad.isMusicStep('👏', 'Tap the rhythm on the drum!'),
        isTrue,
      );
      expect(SavannaRhythmPad.isMusicStep('🐘', 'Tap the elephant!'), isFalse);
    });

    testWidgets('SavannaRhythmPad plays notes and completes after target beats', (
      tester,
    ) async {
      var completed = false;
      final playedBars = <int>[];

      await tester.pumpWidget(
        _host(
          SavannaRhythmPad(
            targetBeats: 3,
            onNotePlayed: playedBars.add,
            onCompleted: () => completed = true,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('savanna-rhythm-pad')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('marimba-bar-0')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(completed, isFalse);

      await tester.tap(find.byKey(const ValueKey('marimba-bar-1')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(completed, isFalse);

      await tester.tap(find.byKey(const ValueKey('marimba-bar-2')));
      await tester.pumpAndSettle();
      expect(playedBars, [0, 1, 2]);
      expect(completed, isTrue);
    });
  });

  group('5. Interactive Balloon-Pop Celebration Screen', () {
    testWidgets('CelebrationBalloonPop pops balloons when tapped', (
      tester,
    ) async {
      var pops = 0;
      await tester.pumpWidget(
        _host(
          CelebrationBalloonPop(onPop: () => pops++),
        ),
      );

      expect(
        find.byKey(const ValueKey('celebration-balloon-pop')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('celebration-balloon-0')));
      await tester.pump(const Duration(milliseconds: 180));
      expect(pops, 1);

      // Tapping an already-popped balloon does not double-count.
      await tester.tap(find.byKey(const ValueKey('celebration-balloon-0')));
      await tester.pump(const Duration(milliseconds: 180));
      expect(pops, 1);

      await tester.tap(find.byKey(const ValueKey('celebration-balloon-2')));
      await tester.pumpAndSettle();
      expect(pops, 2);
    });
  });
}
