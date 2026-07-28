/// Pure reward maths for levels and badges.
///
/// Levels use the design-doc curve (`100 × n^1.4` cumulative). Badges stay
/// here (UI labels keyed by [Badge.id]).
library;

export '../../domain/rules/levels.dart';

import '../../domain/rules/levels.dart';

/// A snapshot of one child's achievements, fed to [earnedBadges].
class BadgeStats {
  const BadgeStats({
    required this.xp,
    required this.streak,
    required this.lessons,
    required this.stories,
    this.dailyChallenges = 0,
  });

  final int xp;
  final int streak;
  final int lessons;
  final int stories;
  final int dailyChallenges;

  int get level => levelForXp(xp);
}

/// A badge definition: a stable [id] (used to look up a localized label),
/// an [emoji], and whether it is [earned] for a given stats snapshot.
class Badge {
  const Badge(this.id, this.emoji, this._earned);
  final String id;
  final String emoji;
  final bool Function(BadgeStats) _earned;

  bool earnedBy(BadgeStats s) => _earned(s);
}

/// The full badge catalogue, in display order.
const List<Badge> allBadges = [
  Badge('firstLesson', '🌱', _firstLesson),
  Badge('threeLessons', '🎯', _threeLessons),
  Badge('fiveLessons', '🖐️', _fiveLessons),
  Badge('tenLessons', '🔟', _tenLessons),
  Badge('streak3', '🔥', _streak3),
  Badge('streak7', '🗓️', _streak7),
  Badge('firstStory', '📖', _firstStory),
  Badge('level5', '🏅', _level5),
  Badge('dailyChallenge', '🦁', _dailyChallenge),
  // Expanded catalog (design doc ~40 launch target — seed more here over time)
  Badge('twentyLessons', '🌟', _twentyLessons),
  Badge('streak14', '💪', _streak14),
  Badge('level10', '👑', _level10),
  Badge('threeStories', '📚', _threeStories),
];

bool _firstLesson(BadgeStats s) => s.lessons >= 1;
bool _threeLessons(BadgeStats s) => s.lessons >= 3;
bool _fiveLessons(BadgeStats s) => s.lessons >= 5;
bool _tenLessons(BadgeStats s) => s.lessons >= 10;
bool _twentyLessons(BadgeStats s) => s.lessons >= 20;
bool _streak3(BadgeStats s) => s.streak >= 3;
bool _streak7(BadgeStats s) => s.streak >= 7;
bool _streak14(BadgeStats s) => s.streak >= 14;
bool _firstStory(BadgeStats s) => s.stories >= 1;
bool _threeStories(BadgeStats s) => s.stories >= 3;
bool _level5(BadgeStats s) => s.level >= 5;
bool _level10(BadgeStats s) => s.level >= 10;
bool _dailyChallenge(BadgeStats s) => s.dailyChallenges >= 1;

/// The badges [s] has earned, in catalogue order.
List<Badge> earnedBadges(BadgeStats s) => [
      for (final b in allBadges)
        if (b.earnedBy(s)) b,
    ];
