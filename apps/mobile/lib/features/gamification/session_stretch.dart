/// Soft mid-session stretch nudge — healthy play without hard lock-outs.
///
/// After [stretchAfterSeconds] of continuous activity time *this calendar day*
/// (not counting already-shown stretch dismissals), the play UI may show a
/// friendly "wiggle break" sheet. Kids can stretch and keep going, or go home.
library;

/// Default: gentle nudge around 15 minutes of play today.
const int stretchAfterSeconds = 15 * 60;

/// Minimum gap between stretch prompts (avoid nagging).
const int stretchCooldownDownSeconds = 20 * 60;

/// Pure decision: should we offer a stretch break right now?
bool shouldOfferStretch({
  required int screenTimeUsedSecondsToday,
  required int? lastStretchAtEpochS,
  required int nowEpochS,
  int thresholdS = stretchAfterSeconds,
  int cooldownS = stretchCooldownDownSeconds,
}) {
  if (screenTimeUsedSecondsToday < thresholdS) return false;
  if (lastStretchAtEpochS == null) return true;
  return nowEpochS - lastStretchAtEpochS >= cooldownS;
}
