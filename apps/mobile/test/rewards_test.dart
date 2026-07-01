import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/gamification/rewards.dart';

void main() {
  group('levels', () {
    test('level increments every 100 XP', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(99), 1);
      expect(levelForXp(100), 2);
      expect(levelForXp(250), 3);
    });

    test('progress within a level', () {
      expect(xpIntoLevel(0), 0);
      expect(xpIntoLevel(150), 50);
      expect(xpToNextLevel(150), 50);
      expect(levelProgress(150), 0.5);
    });

    test('negative XP is treated as zero', () {
      expect(levelForXp(-10), 1);
      expect(xpIntoLevel(-10), 0);
    });
  });

  group('badges', () {
    test('no achievements → no badges', () {
      const none = BadgeStats(xp: 0, streak: 0, lessons: 0, stories: 0);
      expect(earnedBadges(none), isEmpty);
    });

    test('a well-rounded child earns the full set', () {
      const rich = BadgeStats(xp: 500, streak: 7, lessons: 5, stories: 1);
      final ids = earnedBadges(rich).map((b) => b.id).toSet();
      expect(
        ids,
        containsAll(<String>[
          'firstLesson',
          'fiveLessons',
          'streak3',
          'streak7',
          'firstStory',
          'level5',
        ]),
      );
    });

    test('thresholds exclude anyone below the bar', () {
      const s = BadgeStats(xp: 0, streak: 2, lessons: 1, stories: 0);
      final ids = earnedBadges(s).map((b) => b.id).toSet();
      expect(ids, contains('firstLesson'));
      expect(ids, isNot(contains('fiveLessons')));
      expect(ids, isNot(contains('streak3')));
    });
  });
}
