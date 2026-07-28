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
