/// One place that reads a child's badge inputs out of the store.
///
/// [BadgeStats] itself stays pure (see rewards.dart) so the badge rules can be
/// unit-tested without Hive. This is the impure half.
///
/// It exists because the same object was being assembled by hand in four
/// places — the award pipeline, the child achievements sheet, the parent
/// dashboard, and the progress export. Any counter added to [BadgeStats] had to
/// be threaded through all four, and the award pipeline is the one that fires
/// the toast: miss it and a badge silently becomes unearnable.
library;

import '../../core/offline/offline_store.dart';
import 'rewards.dart';

BadgeStats badgeStatsFor(OfflineStore store, String? childId) {
  if (childId == null) {
    return const BadgeStats(xp: 0, streak: 0, lessons: 0, stories: 0);
  }
  return BadgeStats(
    xp: store.xpFor(childId),
    streak: store.streakFor(childId),
    lessons: store.completedLessonCount(childId),
    stories: store.completedStoryCount(childId),
    dailyChallenges: store.dailyChallengeTotalCount(childId),
    quizzes: store.completedQuizCount(childId),
    perfectQuizzes: store.perfectQuizCount(childId),
  );
}

/// The badges [childId] holds, in catalogue order.
///
/// A badge stays once awarded. The streak badges read a number that falls
/// back to 0 when a run ends, so judging a shelf on today's stats alone took
/// the 🔥 badge back from a child who had earned it.
List<Badge> heldBadgesFor(OfflineStore store, String? childId) {
  final stats = badgeStatsFor(store, childId);
  final awarded =
      childId == null ? const <String>{} : store.seenBadgeIds(childId);
  return [
    for (final b in allBadges)
      if (b.earnedBy(stats) || awarded.contains(b.id)) b,
  ];
}
