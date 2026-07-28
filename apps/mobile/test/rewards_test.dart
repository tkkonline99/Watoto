import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/gamification/rewards.dart';

void main() {
  group('levels', () {
    test('curve: enter Ln at floor(100×n^1.4)', () {
      expect(levelForXp(0), 1);
      final l2 = cumulativeXpToEnterLevel(2);
      final l5 = cumulativeXpToEnterLevel(5);
      final l10 = cumulativeXpToEnterLevel(10);
      // Anchors ≈ design doc (L2≈264, L5≈951, L10≈2512).
      expect(l2, inInclusiveRange(260, 265));
      expect(l5, inInclusiveRange(948, 955));
      expect(l10, inInclusiveRange(2508, 2515));
      expect(levelForXp(l2 - 1), 1);
      expect(levelForXp(l2), 2);
      expect(levelForXp(l5), 5);
    });

    test('progress within a level', () {
      expect(xpIntoLevel(0), 0);
      final l2 = cumulativeXpToEnterLevel(2);
      expect(xpIntoLevel(l2), 0);
      expect(xpToNextLevel(l2), cumulativeXpToEnterLevel(3) - l2);
      expect(levelProgress(l2), 0);
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
      const rich = BadgeStats(
        xp: 1000, // past L5 threshold (~951)
        streak: 7,
        lessons: 5,
        stories: 1,
        dailyChallenges: 1,
      );
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
          'dailyChallenge',
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
