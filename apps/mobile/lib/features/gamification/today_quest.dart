/// "Today's quest" — a short daily goal that pulls kids into 2–3 activities
/// without pressure timers or competitive leaderboards.
library;

import '../../core/offline/offline_store.dart';

/// Target activities per day for the quest card (gentle, age-agnostic).
const int todayQuestGoal = 3;

class TodayQuest {
  const TodayQuest({
    required this.done,
    required this.goal,
  });

  final int done;
  final int goal;

  bool get complete => done >= goal;
  double get progress => (done / goal).clamp(0.0, 1.0);
  int get remaining => (goal - done).clamp(0, goal);
}

/// Count distinct learning events for [childId] on the local calendar day.
TodayQuest todayQuestFor(
  OfflineStore store,
  String childId, {
  DateTime? now,
  int goal = todayQuestGoal,
}) {
  final when = now ?? DateTime.now();
  final day =
      '${when.year.toString().padLeft(4, '0')}-'
      '${when.month.toString().padLeft(2, '0')}-'
      '${when.day.toString().padLeft(2, '0')}';
  var count = 0;
  for (final e in store.progressEntriesFor(childId)) {
    final at = e.at;
    if (at == null) continue;
    final k =
        '${at.year.toString().padLeft(4, '0')}-'
        '${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
    if (k == day) count++;
  }
  return TodayQuest(done: count, goal: goal);
}

/// Subject completion 0–1 at [stage] for progress rings on home tiles.
double subjectProgress({
  required OfflineStore store,
  required String childId,
  required int stage,
  required String subject,
  required Iterable<({String id, String type})> items,
}) {
  final list = items.toList();
  if (list.isEmpty) return 0;
  var done = 0;
  for (final i in list) {
    if (store.hasCompletedLibraryItem(childId, i.id, i.type)) done++;
  }
  return done / list.length;
}
