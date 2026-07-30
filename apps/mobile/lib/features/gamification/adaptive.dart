/// Adaptive difficulty rules core (Phase 2 wave 2 light version).
///
/// Pure functions — no network, no ML. Uses recent attempt quality to suggest
/// whether the next item should be easier, same, or harder within a stage.
library;

/// Outcome of a single graded attempt (quiz or scored lesson step).
class AttemptOutcome {
  const AttemptOutcome({
    required this.scorePct,
    required this.retries,
    required this.at,
  });

  final int scorePct;
  final int retries;
  final DateTime at;
}

enum DifficultyNudge { easier, same, harder }

/// Rolling window: last [window] attempts within [maxAge].
DifficultyNudge recommendNudge(
  List<AttemptOutcome> history, {
  int window = 5,
  Duration maxAge = const Duration(days: 14),
  DateTime? now,
}) {
  final when = now ?? DateTime.now();
  final recent = history
      .where((a) => when.difference(a.at) <= maxAge)
      .toList()
    ..sort((a, b) => b.at.compareTo(a.at));
  if (recent.isEmpty) return DifficultyNudge.same;
  final slice = recent.take(window).toList();
  final avgScore =
      slice.map((a) => a.scorePct).reduce((a, b) => a + b) / slice.length;
  final avgRetries =
      slice.map((a) => a.retries).reduce((a, b) => a + b) / slice.length;

  // Struggling: low scores or many retries → easier.
  if (avgScore < 55 || avgRetries >= 2.5) return DifficultyNudge.easier;
  // Flying: high accuracy, few retries → harder.
  if (avgScore >= 90 && avgRetries < 0.5) return DifficultyNudge.harder;
  return DifficultyNudge.same;
}

/// Map a nudge onto a stage offset for next-item selection (−1 / 0 / +1).
int stageOffsetFor(DifficultyNudge nudge) => switch (nudge) {
      DifficultyNudge.easier => -1,
      DifficultyNudge.same => 0,
      DifficultyNudge.harder => 1,
    };

/// Clamp [stage] into 1–10 after applying [offset].
int clampStage(int stage, int offset) {
  final s = stage + offset;
  if (s < 1) return 1;
  if (s > 10) return 10;
  return s;
}
