/// Pure reward maths for levels and badges (unit-tested directly; no Flutter
/// imports). The UI in the home and parent dashboard renders these; labels are
/// localized there, keyed by [Badge.id].
library;

/// Every level is one more [xpPerLevel] block of XP. Level 1 starts at 0 XP.
const int xpPerLevel = 100;

int levelForXp(int xp) => (xp < 0 ? 0 : xp) ~/ xpPerLevel + 1;

/// XP earned inside the current level (0..xpPerLevel-1).
int xpIntoLevel(int xp) => (xp < 0 ? 0 : xp) % xpPerLevel;

/// XP still needed to reach the next level.
int xpToNextLevel(int xp) => xpPerLevel - xpIntoLevel(xp);

/// 0..1 progress toward the next level, for the home progress ring/bar.
double levelProgress(int xp) => xpIntoLevel(xp) / xpPerLevel;

/// A snapshot of one child's achievements, fed to [earnedBadges].
class BadgeStats {
  const BadgeStats({
    required this.xp,
    required this.streak,
    required this.lessons,
    required this.stories,
  });

  final int xp;
  final int streak;
  final int lessons;
  final int stories;

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
  Badge('fiveLessons', '🖐️', _fiveLessons),
  Badge('streak3', '🔥', _streak3),
  Badge('streak7', '🗓️', _streak7),
  Badge('firstStory', '📖', _firstStory),
  Badge('level5', '🏅', _level5),
];

bool _firstLesson(BadgeStats s) => s.lessons >= 1;
bool _fiveLessons(BadgeStats s) => s.lessons >= 5;
bool _streak3(BadgeStats s) => s.streak >= 3;
bool _streak7(BadgeStats s) => s.streak >= 7;
bool _firstStory(BadgeStats s) => s.stories >= 1;
bool _level5(BadgeStats s) => s.level >= 5;

/// The badges [s] has earned, in catalogue order.
List<Badge> earnedBadges(BadgeStats s) => [
  for (final b in allBadges)
    if (b.earnedBy(s)) b,
];
