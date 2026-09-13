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

/// The run as it stands on [todayKey] if the child does nothing more.
///
/// The stored count only moves when an activity is finished, so read raw it
/// keeps a run that ended last week at its old length — on the home pill, in
/// the parent insights and in the reminders — until the next activity resets
/// it. A run is still alive while finishing something today would extend it:
/// the last active day is today or yesterday, or the day before that with
/// this week's shield unspent.
int liveStreak({
  required String? lastDayKey,
  required String todayKey,
  required String yesterdayKey,
  required String dayBeforeYesterdayKey,
  required int stored,
  required bool shieldAvailable,
}) {
  if (lastDayKey == todayKey || lastDayKey == yesterdayKey) return stored;
  if (shieldAvailable && lastDayKey == dayBeforeYesterdayKey) return stored;
  return 0;
}

/// Day key `yyyy-MM-dd` for [d]'s calendar day, in [d]'s own time zone.
String dayKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Day key for the calendar day [days] before [d].
///
/// Counted on the calendar, not in 24-hour steps. A daylight-saving day is 23
/// or 25 hours long, so `d.subtract(Duration(days: 1))` taken in the hour
/// after midnight following a spring-forward day lands two days back, and a
/// child who played yesterday loses the run. Noon keeps the result clear of
/// zones that change their clocks at midnight.
String dayKeyBefore(DateTime d, int days) => dayKeyOf(
      d.isUtc
          ? DateTime.utc(d.year, d.month, d.day - days, 12)
          : DateTime(d.year, d.month, d.day - days, 12),
    );

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
