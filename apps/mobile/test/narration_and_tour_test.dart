import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/audio/narration.dart';
import 'package:watoto_mobile/features/onboarding/guided_tour.dart';
import 'package:watoto_mobile/features/parent/weekly_snapshot.dart';
import 'package:watoto_mobile/features/profiles/child_profile.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';

void main() {
  group('natural speech', () {
    test('naturalize adds terminal punctuation', () {
      expect(NarrationController.naturalize('Hello friend'), 'Hello friend.');
      expect(NarrationController.naturalize('Wow!'), 'Wow!');
    });

    test('naturalize speaks print() like a coach', () {
      final s = NarrationController.naturalize(
        'Type: print("Hello, world!") then press RUN.',
      );
      expect(s.toLowerCase(), contains('print'));
      expect(s.toLowerCase(), contains('hello'));
      expect(s.contains('print("'), isFalse);
    });

    test('symbols are spoken in the child\'s language', () {
      // The defect this pins: symbol names were hardcoded English, so a
      // French child heard "3 times 4" inside a French question.
      expect(NarrationController.naturalize('3 × 4', lang: 'en'),
          contains('times'));
      expect(NarrationController.naturalize('3 × 4', lang: 'fr'),
          contains('fois'));
      expect(NarrationController.naturalize('3 × 4', lang: 'sw'),
          contains('mara'));
      expect(NarrationController.naturalize('84 ÷ 4', lang: 'fr'),
          contains('divisé par'));
    });

    test('a fraction is read as a fraction, not a division', () {
      // "1/5" in a fractions lesson is one fifth. Reading it as "1 divided
      // by 5" teaches the wrong thing in the very lesson about fractions.
      final en = NarrationController.naturalize('1/5 + 2/5', lang: 'en');
      expect(en, contains('one fifth'));
      expect(en, contains('2 fifths'));
      expect(en, isNot(contains('divided')));
      expect(NarrationController.naturalize('1/2', lang: 'en'),
          contains('one half'));
      expect(NarrationController.naturalize('1/5', lang: 'fr'),
          contains('cinquième'));
      expect(NarrationController.naturalize('1/2', lang: 'sw'),
          contains('nusu'));
    });

    test('decimals survive, in either notation', () {
      // French writes 0,7 — the old comma-spacing rule split it into two
      // numbers, so the child heard "zero, seven".
      expect(NarrationController.naturalize('0,7', lang: 'fr'),
          contains('0 virgule 7'));
      expect(NarrationController.naturalize('0.25', lang: 'en'),
          contains('0 point 25'));
    });

    test('a blank becomes a spoken question', () {
      // "___" was read out as underscores or swallowed entirely.
      final en = NarrationController.naturalize('That is a ___.', lang: 'en');
      expect(en, 'That is a what?');
      expect(NarrationController.naturalize('Ni ___?', lang: 'sw'),
          contains('nini'));
      // "= ?" is the same hole in a different costume.
      expect(NarrationController.naturalize('3 × 4 = ?', lang: 'en'),
          '3 times 4 equals what?');
    });

    test('a hyphen inside a word is not a minus sign', () {
      expect(NarrationController.naturalize('non-living', lang: 'en'),
          contains('non-living'));
      expect(NarrationController.naturalize('13 - 4', lang: 'en'),
          contains('minus'));
    });

    test('emoji are not read aloud', () {
      expect(
        NarrationController.naturalize('Tap the pyramid 🔺 now.', lang: 'en'),
        'Tap the pyramid now.',
      );
    });

    test('code coaching stays in the English lessons it belongs to', () {
      // These rewrites inject English words; they must not fire on other
      // languages, whose content has no Python in it anyway.
      expect(
        NarrationController.naturalize('Type: print("Hi")', lang: 'en'),
        contains('Let us write'),
      );
      expect(
        NarrationController.naturalize('Andika: print("Hi")', lang: 'sw'),
        isNot(contains('Let us write')),
      );
    });

    test('no punctuation debris is left for the engine', () {
      for (final lang in ['en', 'sw', 'fr']) {
        for (final s in ['Andika: print("Hi")', '3 × 4 = ?', 'Ni ___?']) {
          final out = NarrationController.naturalize(s, lang: lang);
          expect(out, isNot(contains(' ,')), reason: '$lang "$s"');
          expect(out, isNot(contains(',,')), reason: '$lang "$s"');
          expect(out, isNot(startsWith(',')), reason: '$lang "$s"');
        }
      }
    });

    test('chunk splits long multi-sentence text', () {
      final chunks = NarrationController.chunkForSpeech(
        'Tap the star. Great job! Now try the next one.',
      );
      expect(chunks.length, greaterThanOrEqualTo(2));
    });
  });

  group('guided tour', () {
    test('picks curated first lesson for stage 1 age', () {
      final items = [
        LibraryItem(
          id: 's01.cause.lesson.01',
          stage: 1,
          ages: '0-1',
          subject: 'Cause & Effect',
          type: LibraryType.lesson,
          title: 'Tap to Make a Star',
          objective: '',
          designTier: 'A',
          reading: false,
          interaction: 'tap',
        ),
      ];
      final lib = LibraryRepository(items);
      final child = ChildProfile(
        id: 'c',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: DateTime.now().year, // age 0 → stage 1
        ageBand: AgeBand.b0_2,
      );
      final item = firstTourItem(child: child, library: lib);
      expect(item?.id, 's01.cause.lesson.01');
    });

    test('welcome speech includes nickname', () {
      expect(tourWelcomeSpeech('Amani', 'en'), contains('Amani'));
      expect(tourWelcomeSpeech('Amani', 'fr'), contains('Amani'));
      expect(tourWelcomeSpeech('Amani', 'sw'), contains('Amani'));
    });
  });

  group('weekly snapshot window', () {
    test('startOfWeek is Monday', () {
      // 2026-07-16 is a Thursday
      final mon = startOfWeek(DateTime(2026, 7, 16));
      expect(mon.weekday, DateTime.monday);
      expect(mon.day, 13);
    });
  });
}
