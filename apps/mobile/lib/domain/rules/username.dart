/// Child nickname ("username") change policy.
///
/// Parents may update a child's display nickname at most once every 90 days
/// to discourage frequent identity churn while still allowing growth renames.
library;

/// Minimum gap between nickname changes.
const Duration nicknameChangeCooldown = Duration(days: 90);

/// Whether a nickname change is allowed given the last change time.
bool canChangeNickname(DateTime? lastChangedAt, {DateTime? now}) {
  if (lastChangedAt == null) return true;
  final n = now ?? DateTime.now();
  return !n.isBefore(lastChangedAt.add(nicknameChangeCooldown));
}

/// Time remaining until the next allowed change, or null if allowed now.
Duration? nicknameCooldownRemaining(DateTime? lastChangedAt, {DateTime? now}) {
  if (lastChangedAt == null) return null;
  final n = now ?? DateTime.now();
  final unlock = lastChangedAt.add(nicknameChangeCooldown);
  if (!n.isBefore(unlock)) return null;
  return unlock.difference(n);
}

/// Calendar days remaining (rounded up), for parent-facing copy.
int nicknameCooldownDaysRemaining(DateTime? lastChangedAt, {DateTime? now}) {
  final left = nicknameCooldownRemaining(lastChangedAt, now: now);
  if (left == null) return 0;
  return (left.inHours / 24).ceil().clamp(1, nicknameChangeCooldown.inDays);
}
