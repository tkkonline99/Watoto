/// What makes the narration voice sound smooth rather than stop-start: the
/// right speed on every platform, the best voice the device has, one line at
/// a time, and feedback that is allowed to finish.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/audio/narration.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/features/library/play_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speaking pace', () {
    double rate(TargetPlatform p, {bool web = false}) =>
        NarrationController.engineRate(0.9, platform: p, isWeb: web);

    test('the same pace is the same speed on every platform', () {
      // 0.9 of normal. AVSpeech's normal is 0.5; Android's and the browser's
      // is 1.0; the Windows plugin adds 0.5 before WinRT, whose normal is 1.0.
      expect(rate(TargetPlatform.iOS), closeTo(0.45, 1e-9));
      expect(rate(TargetPlatform.android), closeTo(0.9, 1e-9));
      expect(rate(TargetPlatform.windows, web: true), closeTo(0.9, 1e-9));
      expect(rate(TargetPlatform.windows) + 0.5, closeTo(0.9, 1e-9));
    });
  });

  group('voice choice', () {
    Map<String, String>? pick(List<Map<String, String>> voices) =>
        NarrationController.pickVoice(voices, 'en-US');

    test('an offline high-quality Android voice beats an online one', () {
      // The online voice's name sorts first, so only the network penalty —
      // not the tie-break — can put the offline one ahead.
      final best = pick([
        {
          'name': 'en-us-x-iob-network',
          'locale': 'en-US',
          'quality': 'very high',
          'network_required': '1',
        },
        {
          'name': 'en-us-x-sfg-local',
          'locale': 'en-US',
          'quality': 'normal',
          'network_required': '0',
        },
        {
          'name': 'en-us-x-tpc-local',
          'locale': 'en-US',
          'quality': 'very high',
          'network_required': '0',
        },
      ]);
      expect(best?['name'], 'en-us-x-tpc-local');
    });

    test('a voice whose data is not downloaded is never chosen', () {
      final best = pick([
        {
          'name': 'en-us-x-iol-local',
          'locale': 'en-US',
          'quality': 'very high',
          'features': 'notInstalled',
        },
        {'name': 'en-us-x-sfg-local', 'locale': 'en-US', 'quality': 'normal'},
      ]);
      expect(best?['name'], 'en-us-x-sfg-local');
    });

    test('iOS quality is read from its field, not guessed from the name', () {
      // "Fred" sorts before "Zoe", so only the quality field can pick Zoe.
      final best = pick([
        {'name': 'Fred', 'locale': 'en-US', 'quality': 'default'},
        {'name': 'Zoe', 'locale': 'en-US', 'quality': 'premium'},
      ]);
      expect(best?['name'], 'Zoe');
    });

    test('the resolved accent wins a tie, and ties are stable', () {
      final voices = [
        {'name': 'Zira', 'locale': 'en-GB', 'gender': 'female'},
        {'name': 'Mark', 'locale': 'en-US', 'gender': 'male'},
        {'name': 'Aria', 'locale': 'en-US', 'gender': 'female'},
      ];
      expect(pick(voices)?['name'], 'Aria');
      expect(pick(voices.reversed.toList())?['name'], 'Aria');
    });

    test('a voice for another language is never picked', () {
      expect(
        pick([
          {'name': 'Amélie', 'locale': 'fr-FR', 'quality': 'premium'},
        ]),
        isNull,
      );
    });
  });

  group('one line at a time', () {
    const channel = MethodChannel('flutter_tts');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late OfflineStore store;
    late ProviderContainer container;
    late List<String> spoken;
    late List<Completer<Object?>> pending;

    setUpAll(() => Hive.init(Directory.systemTemp.path));

    /// A fake engine. [answersInterrupted] is Android and Windows, which
    /// reply to a `speak` call when `stop` cuts it off; the browser never does.
    void installEngine({required bool answersInterrupted}) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getLanguages':
            return ['en-US'];
          case 'getVoices':
            return <Object>[];
          case 'speak':
            spoken.add(call.arguments as String);
            final done = Completer<Object?>();
            pending.add(done);
            return done.future;
          case 'stop':
            if (answersInterrupted) {
              for (final p in pending) {
                if (!p.isCompleted) p.complete(0);
              }
            }
            return 1;
        }
        return 1;
      });
    }

    Future<void> until(bool Function() ok) async {
      for (var i = 0; i < 400 && !ok(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(ok(), isTrue, reason: 'timed out; spoken so far: $spoken');
    }

    setUp(() async {
      spoken = [];
      pending = [];
      store = await OfflineStore.open(inMemory: true);
      container = ProviderContainer(
        overrides: [offlineStoreProvider.overrideWithValue(store)],
      );
      container.read(narrationProvider);
    });

    tearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      container.dispose();
      await store.close();
    });

    final longPage = List.generate(
      12,
      (i) => 'This is sentence number ${i + 1} of a long story page.',
    ).join(' ');

    for (final answersInterrupted in [true, false]) {
      final platform = answersInterrupted ? 'Android/Windows' : 'browser';

      test('a new line is not talked over by the old one ($platform)',
          () async {
        installEngine(answersInterrupted: answersInterrupted);
        final narration = container.read(narrationProvider.notifier);
        final utterances = NarrationController.chunkForSpeech(longPage);
        expect(utterances.length, greaterThan(1));

        final page = narration.speak(longPage, 'en');
        await until(() => spoken.length == 1);
        final praise = narration.speak('Well done!', 'en');
        await until(() => spoken.length == 2);

        // Let every pending utterance finish, then give a stale loop every
        // chance to carry on reading the page.
        for (final p in pending) {
          if (!p.isCompleted) p.complete(1);
        }
        await praise.timeout(const Duration(seconds: 2));
        await page.timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('the replaced page never finished'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(spoken, [utterances.first, 'Well done!']);
      });
    }

    test('a short passage reaches the engine as one utterance', () async {
      installEngine(answersInterrupted: true);
      final narration = container.read(narrationProvider.notifier);
      final line = narration.speak('Tap the star. Great job!', 'en');
      await until(() => spoken.isNotEmpty);
      pending.single.complete(1);
      await line.timeout(const Duration(seconds: 2));
      expect(spoken, ['Tap the star. Great job!']);
    });
  });

  group('SpeechBeat', () {
    testWidgets('waits for a line that outlasts the beat', (tester) async {
      final speech = Completer<void>();
      var moved = 0;
      SpeechBeat(
        speech: speech.future,
        minimum: const Duration(milliseconds: 1400),
        onDone: () => moved++,
      );
      await tester.pump(const Duration(milliseconds: 2500));
      expect(moved, 0, reason: 'moved on while the feedback was still playing');
      speech.complete();
      await tester.pump();
      expect(moved, 1);
    });

    testWidgets('never moves on sooner than the beat', (tester) async {
      var moved = 0;
      SpeechBeat(
        speech: Future<void>.value(),
        minimum: const Duration(milliseconds: 1400),
        onDone: () => moved++,
      );
      await tester.pump(const Duration(milliseconds: 1000));
      expect(moved, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(moved, 1);
    });

    testWidgets('a voice that never reports finishing cannot stall the lesson',
        (tester) async {
      var moved = 0;
      SpeechBeat(
        speech: Completer<void>().future,
        minimum: const Duration(milliseconds: 1400),
        onDone: () => moved++,
      );
      await tester.pump(const Duration(seconds: 8));
      expect(moved, 1);
    });

    testWidgets('a cancelled beat never fires', (tester) async {
      final speech = Completer<void>();
      var moved = 0;
      SpeechBeat(
        speech: speech.future,
        minimum: const Duration(milliseconds: 1400),
        onDone: () => moved++,
      ).cancel();
      speech.complete();
      await tester.pump(const Duration(seconds: 10));
      expect(moved, 0);
    });
  });
}
