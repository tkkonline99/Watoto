/// One-tap "Play now" resolver — the snappiest path into learning.
///
/// Priority (kid engagement):
/// 1. Incomplete daily challenge (habit + bonus XP/coins)
/// 2. Continue-learning next in last subject
/// 3. Short incomplete lesson at preferred stage (quick win)
/// 4. Any incomplete discover item
library;

import '../../core/offline/offline_store.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';
import '../profiles/child_profile.dart';
import 'continue_learning.dart';
import 'daily_challenge.dart';

/// Why [PlayNowTarget] was chosen — for cheerful home subtitle copy.
enum PlayNowReason {
  dailyChallenge,
  resume,
  next,
  quickWin,
  discover,
}

class PlayNowTarget {
  const PlayNowTarget({
    required this.item,
    required this.reason,
  });

  final LibraryItem item;
  final PlayNowReason reason;

  String get itemId => item.id;
  String get title => item.title;
}

/// Best single activity to start right now for [child].
PlayNowTarget? resolvePlayNow({
  required ChildProfile child,
  required OfflineStore store,
  required LibraryRepository library,
  DateTime? now,
}) {
  final date = now ?? DateTime.now();

  // 1) Daily challenge still open — strongest daily hook.
  final challenge = resolveDailyChallenge(
    child: child,
    store: store,
    library: library,
    now: date,
  );
  if (challenge != null && !challenge.completed) {
    return PlayNowTarget(
      item: challenge.item,
      reason: PlayNowReason.dailyChallenge,
    );
  }

  // 2) Continue in last subject / discover.
  final cont = resolveContinueLearning(
    childId: child.id,
    store: store,
    library: library,
  );
  if (cont != null) {
    // Prefer short lessons as "quick wins" when discovering.
    if (cont.reason == 'discover') {
      final quick = _quickWin(child, store, library);
      if (quick != null) {
        return PlayNowTarget(item: quick, reason: PlayNowReason.quickWin);
      }
    }
    return PlayNowTarget(
      item: cont.item,
      reason: switch (cont.reason) {
        'resume' => PlayNowReason.resume,
        'next' => PlayNowReason.next,
        _ => PlayNowReason.discover,
      },
    );
  }

  final quick = _quickWin(child, store, library);
  if (quick != null) {
    return PlayNowTarget(item: quick, reason: PlayNowReason.quickWin);
  }
  return null;
}

/// Incomplete lesson with the fewest steps (fast dopamine hit).
LibraryItem? _quickWin(
  ChildProfile child,
  OfflineStore store,
  LibraryRepository library,
) {
  final stage = stageForChild(child, store).stage;
  final pool = library.all
      .where(
        (i) =>
            i.stage == stage &&
            i.type == LibraryType.lesson &&
            !store.hasCompletedLibraryItem(child.id, i.id, i.type.name),
      )
      .toList()
    ..sort((a, b) => a.steps.length.compareTo(b.steps.length));
  return pool.isEmpty ? null : pool.first;
}
