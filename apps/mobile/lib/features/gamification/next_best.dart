/// Next-best activity resolver: daily challenge + adaptive + continue.
library;

import '../../core/offline/offline_store.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';
import '../profiles/child_profile.dart';
import 'adaptive.dart';
import 'continue_learning.dart';
import 'daily_challenge.dart';

/// Why we picked this activity (analytics + UI copy).
enum NextBestReason {
  dailyChallenge,
  continueNext,
  continueResume,
  adaptiveEasier,
  adaptiveHarder,
  discover,
}

class NextBestTarget {
  const NextBestTarget({
    required this.item,
    required this.reason,
    required this.nudge,
  });

  final LibraryItem item;
  final NextBestReason reason;
  final DifficultyNudge nudge;

  String get itemId => item.id;
}

List<AttemptOutcome> _outcomes(OfflineStore store, String childId) {
  return [
    for (final a in store.recentAttemptOutcomes(childId))
      AttemptOutcome(scorePct: a.scorePct, retries: a.retries, at: a.at),
  ];
}

/// Pick the best incomplete activity for this child.
///
/// Set [skipDailyChallenge] when the caller already renders the daily
/// challenge on its own surface — otherwise the home screen would show the
/// same activity twice, once as the challenge and once as "keep going".
NextBestTarget? resolveNextBestForChild({
  required ChildProfile child,
  required OfflineStore store,
  required LibraryRepository library,
  DateTime? now,
  bool skipDailyChallenge = false,
}) {
  final when = now ?? DateTime.now();
  final history = _outcomes(store, child.id);
  final nudge = recommendNudge(history, now: when);
  final preferred =
      store.preferredStage(child.id) ?? stageForChild(child, store).stage;

  // 1) Incomplete daily challenge — strongest habit hook.
  final challenge = resolveDailyChallenge(
    child: child,
    store: store,
    library: library,
    now: when,
  );
  if (challenge != null && !challenge.completed) {
    if (!skipDailyChallenge) {
      return NextBestTarget(
        item: challenge.item,
        reason: NextBestReason.dailyChallenge,
        nudge: nudge,
      );
    }
  }

  // When the caller renders the challenge itself, every later step has to skip
  // that item too — otherwise "continue" or "discover" just re-suggests it.
  final excludeId = skipDailyChallenge &&
          challenge != null &&
          !challenge.completed
      ? challenge.itemId
      : null;
  bool usable(LibraryItem i) => i.id != excludeId;

  // 2) Adaptive stage shift when the child is struggling or flying.
  if (nudge != DifficultyNudge.same) {
    final adaptedStage = clampStage(preferred, stageOffsetFor(nudge));
    final pool = library.all
        .where((i) => i.stage == adaptedStage)
        .where(
          (i) => !store.hasCompletedLibraryItem(child.id, i.id, i.type.name),
        )
        .where(usable)
        .toList();
    if (pool.isNotEmpty) {
      final last = store.lastPlayed(child.id);
      final subj = last?['subject'] as String?;
      final pick = subj == null
          ? pool.first
          : pool.firstWhere((i) => i.subject == subj, orElse: () => pool.first);
      return NextBestTarget(
        item: pick,
        reason: nudge == DifficultyNudge.easier
            ? NextBestReason.adaptiveEasier
            : NextBestReason.adaptiveHarder,
        nudge: nudge,
      );
    }
  }

  // 3) Continue in last subject.
  final cont = resolveContinueLearning(
    childId: child.id,
    store: store,
    library: library,
  );
  if (cont != null && usable(cont.item)) {
    return NextBestTarget(
      item: cont.item,
      reason: cont.reason == 'next'
          ? NextBestReason.continueNext
          : cont.reason == 'resume'
              ? NextBestReason.continueResume
              : NextBestReason.discover,
      nudge: nudge,
    );
  }

  // 4) Discover any incomplete item.
  for (final item in library.all) {
    if (!usable(item)) continue;
    if (!store.hasCompletedLibraryItem(child.id, item.id, item.type.name)) {
      return NextBestTarget(
        item: item,
        reason: NextBestReason.discover,
        nudge: nudge,
      );
    }
  }
  return null;
}
