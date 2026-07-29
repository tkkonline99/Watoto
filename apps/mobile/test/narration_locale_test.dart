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
}
