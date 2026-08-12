import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/audio/narration.dart';

/// The 0–5 band is audio-first, and Swahili voices ship on almost no device.
/// The old code set `sw-KE` unconditionally: engines that lacked it either
/// refused or kept the previous voice, so Swahili sentences came out with
/// English phonetics and nothing in the app noticed.
void main() {
  const resolve = NarrationController.resolveLocale;

  group('locale resolution', () {
    test('prefers the first tag in the chain when the device has it', () {
      expect(resolve('sw', ['en-US', 'sw-KE', 'sw-TZ']), 'sw-KE');
      expect(resolve('fr', ['fr-CA', 'fr-FR']), 'fr-FR');
    });

    test('falls back down the chain rather than giving up', () {
      // A Tanzanian device with only sw-TZ must still speak Swahili.
      expect(resolve('sw', ['en-US', 'sw-TZ']), 'sw-TZ');
      expect(resolve('fr', ['en-US', 'fr-CA']), 'fr-CA');
      expect(resolve('en', ['en-GB']), 'en-GB');
    });

    test('accepts a bare language tag', () {
      expect(resolve('sw', ['sw']), 'sw');
    });

    test('matches an unlisted regional variant of the right language', () {
      // sw-UG is not in the chain, but a Swahili voice is a Swahili voice.
      expect(resolve('sw', ['en-US', 'sw-UG']), 'sw-ug');
    });

    test('tolerates the tag shapes engines actually report', () {
      // Android returns sw_KE, some web engines lowercase everything.
      expect(resolve('sw', ['sw_KE']), 'sw-KE');
      expect(resolve('fr', ['FR-fr']), 'fr-FR');
    });

    test('returns null when the device has no voice for the language', () {
      // The case that matters: an English-only phone asked to speak Swahili.
      expect(resolve('sw', ['en-US', 'en-GB', 'fr-FR']), isNull);
      expect(resolve('fr', ['en-US']), isNull);
    });

    test('returns null when the engine reports nothing', () {
      expect(resolve('en', const []), isNull);
    });

    test('never answers with a different language', () {
      // Speaking Swahili text with a French voice is worse than silence, so
      // no near-miss may ever be returned.
      for (final lang in ['en', 'sw', 'fr']) {
        final got = resolve(lang, ['en-US', 'sw-KE', 'fr-FR']);
        expect(got, isNotNull);
        expect(
          got!.toLowerCase().startsWith(lang),
          isTrue,
          reason: '$lang resolved to $got',
        );
      }
    });

    test('every supported app language has a fallback chain', () {
      for (final lang in ['en', 'sw', 'fr']) {
        expect(
          NarrationController.localeChain[lang],
          isNotNull,
          reason: '$lang has no chain, so it can only ever try one tag',
        );
        expect(NarrationController.localeChain[lang]!.length, greaterThan(1));
      }
    });
  });

  /// flutter_tts hands the same double to four engines that each mean
  /// something different by it. The app used to pass one constant, so the
  /// browser build spoke at 40% while Android spoke at 80% — the reason
  /// narration sounded like a slowed-down recording on web.
  group('speech rate', () {
    const rate = NarrationController.engineRate;

    // What each platform must receive for the child to hear 80% of normal.
    test('one pace lands on the same speed on every platform', () {
      // web: utterance.rate, normal 1.0 -> pass it straight through.
      expect(rate(0.80, isWeb: true, platform: TargetPlatform.android), 0.80);
      // Android: the plugin doubles it before the engine sees it.
      expect(rate(0.80, isWeb: false, platform: TargetPlatform.android), 0.40);
      // iOS/macOS: AVSpeechUtteranceDefaultSpeechRate is 0.5, not 1.0.
      expect(rate(0.80, isWeb: false, platform: TargetPlatform.iOS), 0.40);
      expect(rate(0.80, isWeb: false, platform: TargetPlatform.macOS), 0.40);
      // Windows: the plugin adds 0.5 before setting SpeakingRate.
      expect(
        rate(0.80, isWeb: false, platform: TargetPlatform.windows),
        closeTo(0.30, 1e-9),
      );
    });

    test('web is never handed the mobile number', () {
      // The regression itself: 0.40 on web is 40% speed, half what is meant.
      final web = rate(0.80, isWeb: true, platform: TargetPlatform.android);
      expect(web, greaterThan(0.6),
          reason: 'anything near 0.4 on web is the slowed-down-recording bug');
    });

    test('stays inside every engine\'s accepted range', () {
      for (final pace in [0.1, 0.5, 0.72, 0.8, 1.0]) {
        for (final p in TargetPlatform.values) {
          expect(rate(pace, isWeb: false, platform: p), greaterThanOrEqualTo(0));
          expect(rate(pace, isWeb: true, platform: p), greaterThanOrEqualTo(0.1));
        }
      }
    });
  });
}
