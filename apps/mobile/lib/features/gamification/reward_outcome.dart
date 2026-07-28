/// What the child just earned, as one object.
///
/// Before this, the celebration screen could only see XP: coins were granted
/// silently, badges were deferred to a toast on the *next* home visit, and the
/// weekly streak shield was spent without anyone being told. The reward
/// pipeline now hands the UI a single [RewardOutcome] describing the whole
/// moment, so it can be celebrated where it happened.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Celebrations shorten after this many activities in one sitting
/// (docs/12 §12.6 "reward cool-down"). Keeps the fifth win of a session from
/// feeling like the first — the reward stays, the fanfare gets out of the way.
const int celebrationCooldownAfter = 5;

class RewardOutcome {
  const RewardOutcome({
    this.xp = 0,
    this.coins = 0,
    this.stars = 0,
    this.levelUp = 0,
    this.badgeIds = const [],
    this.streakSavedDays = 0,
    this.streak = 0,
    this.firstInSubject = false,
    this.sessionIndex = 0,
  });

  final int xp;

  /// Coins actually granted — already capped by the daily limit, so this is 0
  /// once the child has hit the cap. Showing the real number keeps the economy
  /// honest rather than promising coins that were never banked.
  final int coins;

  /// 1–3 quality rating for this run (0 = not rated).
  final int stars;

  /// Level newly reached, or 0.
  final int levelUp;

  /// Badge ids newly earned by this activity.
  final List<String> badgeIds;

  /// Days of streak rescued by the weekly shield, or 0 when none was spent.
  final int streakSavedDays;

  /// The child's streak after this activity.
  final int streak;

  /// First ever completion in this subject — worth a bigger moment.
  final bool firstInSubject;

  /// 0-based count of activities finished in this app session.
  final int sessionIndex;

  /// A moment worth the full fanfare no matter how many have come before.
  bool get isMilestone =>
      levelUp > 0 ||
      badgeIds.isNotEmpty ||
      streakSavedDays > 0 ||
      firstInSubject ||
      stars >= 3;

  /// True once the novelty has worn off within a single sitting.
  bool get brief => sessionIndex >= celebrationCooldownAfter && !isMilestone;
}

/// The outcome of the most recent completion, consumed by the celebration.
final pendingRewardProvider = StateProvider<RewardOutcome?>((ref) => null);

/// Activities completed since the app launched — drives the cool-down.
final sessionCompletionCountProvider = StateProvider<int>((ref) => 0);

/// 1–3 stars for a lesson run, from mistakes made against work attempted.
///
/// Deliberately kind: finishing at all is worth a star, and a child has to
/// miss more than a third of the steps before dropping to one.
int starsForLessonRun({required int steps, required int mistakes}) {
  if (steps <= 0) return 0;
  if (mistakes <= 0) return 3;
  if (mistakes * 3 <= steps) return 2;
  return 1;
}

/// A lesson run as a percentage, for the store and the adaptive engine.
///
/// Every lesson used to report a flat 100%, which made the difficulty signal
/// meaningless — a constant 100 with zero retries reads as "always ready for
/// harder". This reports what actually happened.
int scorePctForLessonRun({required int steps, required int mistakes}) {
  if (steps <= 0) return 100;
  final pct = ((steps - mistakes) / steps * 100).round();
  return pct.clamp(0, 100);
}
