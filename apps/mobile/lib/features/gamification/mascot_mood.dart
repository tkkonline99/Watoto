/// How the companion is feeling, derived from how the learning is going.
///
/// Pure rule so the moods are testable without a widget tree. Kept gentle on
/// purpose: the sleepy state reads as "missed you", never as a scolding — a
/// guilt mechanic aimed at a six-year-old is not something this app does.
library;

import '../../core/widgets/mascot_widget.dart';
import '../parent/reminders/reminder_policy.dart';

export '../../core/widgets/mascot_widget.dart' show MascotMood;

/// Days away before the companion is drawn asleep.
const int mascotSleepsAfterDays = 3;

/// A streak this long makes the companion visibly proud.
const int mascotProudAtStreak = 3;

MascotMood mascotMoodFor({
  required String? lastActiveDayKey,
  required int streak,
  required DateTime now,
}) {
  final today = reminderDayKey(now);
  if (lastActiveDayKey == null) return MascotMood.idle;

  final gap = daysBetweenKeys(lastActiveDayKey, today);
  if (gap == null) return MascotMood.idle;
  if (gap >= mascotSleepsAfterDays) return MascotMood.sleep;

  // Played today, on a run worth being proud of.
  if (gap == 0 && streak >= mascotProudAtStreak) return MascotMood.cheer;
  // Away a day or two — curious about where they went.
  if (gap > 0) return MascotMood.think;
  return MascotMood.idle;
}
