/// What (if anything) a family should be reminded about, and when.
///
/// Pure rules — no plugin, no platform. docs/12 §12.6 is explicit that
/// reminders go to **parents only and are off by default**; nothing here ever
/// targets a child, and nothing schedules unless a grown-up has opted in.
library;

import '../../../domain/rules/streak.dart' show isoWeekKey;

/// Days of silence before a family counts as lapsed.
const int inactiveAfterDays = 3;

/// A streak this long is worth protecting with a nudge.
const int streakWorthProtecting = 2;

/// How many days ahead to queue reminders. Local notifications cannot
/// recompute their text at fire time, so the app queues a short run and
/// refreshes it whenever it is opened.
const int reminderHorizonDays = 3;

enum ReminderKind {
  /// A live streak has no activity today and will lapse.
  streakAtRisk,

  /// Nobody has played for [inactiveAfterDays] or more.
  inactive,

  /// A gentle "carry on" for families in good standing.
  keepGoing,

  /// Say nothing.
  none,
}

/// Day key ('yyyy-MM-dd') in the family's local time — matches OfflineStore.
String reminderDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Whole days between two day keys, or null when either is unparseable.
///
/// Measured between UTC midnights. A key parses to *local* midnight, and
/// across a spring-forward night two consecutive local midnights are 23 hours
/// apart, which `inDays` truncates to 0.
int? daysBetweenKeys(String from, String to) {
  final a = DateTime.tryParse(from);
  final b = DateTime.tryParse(to);
  if (a == null || b == null) return null;
  return DateTime.utc(b.year, b.month, b.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
}

/// The reminder due on [onDay], given when the child was last active.
///
/// [lastActiveDayKey] is null for a child who has never finished anything —
/// they get the lapsed nudge rather than a streak warning about a streak they
/// do not have.
///
/// [shieldUsedWeek] is the ISO week the weekly streak shield was last spent
/// in. Two days after the last activity the run survives only if that day's
/// week still has its shield; otherwise it ended at midnight, and "ends today"
/// would be a warning about something already gone.
ReminderKind reminderFor({
  required String? lastActiveDayKey,
  required int streak,
  required DateTime onDay,
  String? shieldUsedWeek,
}) {
  final today = reminderDayKey(onDay);
  if (lastActiveDayKey == null) return ReminderKind.inactive;
  if (lastActiveDayKey == today) return ReminderKind.none;

  final gap = daysBetweenKeys(lastActiveDayKey, today);
  if (gap == null) return ReminderKind.none;
  if (gap >= inactiveAfterDays) return ReminderKind.inactive;
  final runAlive =
      gap == 1 || (gap == 2 && isoWeekKey(onDay) != shieldUsedWeek);
  if (runAlive && streak >= streakWorthProtecting) {
    return ReminderKind.streakAtRisk;
  }
  return ReminderKind.keepGoing;
}

/// One queued reminder.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.streak,
  });

  /// Stable per-slot id so re-planning replaces rather than duplicates.
  final int id;
  final ReminderKind kind;
  final DateTime at;
  final int streak;
}

/// The next [reminderHorizonDays] reminders, skipping days with nothing to
/// say. Times are local wall-clock at the parent's chosen [hour]:[minute].
///
/// The projection assumes no further activity — which is the case the reminder
/// exists for. Opening the app re-plans, so a family who plays never sees the
/// warning they were queued.
List<PlannedReminder> planReminders({
  required String? lastActiveDayKey,
  required int streak,
  required DateTime now,
  required int hour,
  required int minute,
  String? shieldUsedWeek,
  int horizonDays = reminderHorizonDays,
}) {
  final out = <PlannedReminder>[];
  for (var offset = 0; offset < horizonDays; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset, hour, minute);
    // Never schedule into the past — today's slot may already have passed.
    if (!day.isAfter(now)) continue;
    final kind = reminderFor(
      lastActiveDayKey: lastActiveDayKey,
      streak: streak,
      onDay: day,
      shieldUsedWeek: shieldUsedWeek,
    );
    if (kind == ReminderKind.none) continue;
    out.add(
      PlannedReminder(
        id: 1000 + offset,
        kind: kind,
        at: day,
        // A streak only survives the day it is warned about.
        streak: kind == ReminderKind.streakAtRisk ? streak : 0,
      ),
    );
  }
  return out;
}
