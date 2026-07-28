/// Pure streak arithmetic with optional weekly shield (docs/12).
///
/// Day keys are 'yyyy-MM-dd' in the family's local time.
library;

/// Result of advancing a learning streak for one calendar day of activity.
class StreakTick {
  const StreakTick({
    required this.streak,
    this.usedShield = false,
  });

  final int streak;
  final bool usedShield;
}

/// Legacy API — no shield.
int nextStreak({
  required String? lastDayKey,
  required String todayKey,
  required String yesterdayKey,
  required int current,
}) =>
    nextStreakTick(
      lastDayKey: lastDayKey,
      todayKey: todayKey,
      yesterdayKey: yesterdayKey,
      dayBeforeYesterdayKey: null,
      current: current,
      shieldAvailable: false,
    ).streak;

/// Full streak rules with one free "shield" per week: miss exactly one day
/// and the run continues (shield consumed). Longer gaps still reset.
StreakTick nextStreakTick({
  required String? lastDayKey,
  required String todayKey,
  required String yesterdayKey,
  required String? dayBeforeYesterdayKey,
  required int current,
  required bool shieldAvailable,
}) {
  if (lastDayKey == todayKey) {
    return StreakTick(streak: current == 0 ? 1 : current);
  }
  if (lastDayKey == yesterdayKey) {
    return StreakTick(streak: current + 1);
  }
  // Missed exactly one day → optional shield keeps the chain kind.
  if (shieldAvailable &&
      dayBeforeYesterdayKey != null &&
      lastDayKey == dayBeforeYesterdayKey &&
      current > 0) {
    return StreakTick(streak: current + 1, usedShield: true);
  }
  return const StreakTick(streak: 1);
}

/// ISO week key `yyyy-Www` for weekly shield allotment.
String isoWeekKey(DateTime d) {
  // Thursday-based ISO week (same as package:intl without the dependency).
  final date = DateTime.utc(d.year, d.month, d.day);
  final dayOfWeek = date.weekday; // Mon=1 … Sun=7
  final thursday = date.add(Duration(days: 4 - dayOfWeek));
  final firstDay = DateTime.utc(thursday.year);
  final week = 1 + ((thursday.difference(firstDay).inDays) / 7).floor();
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}
