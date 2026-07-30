/// The family layer: a grown-up noticing, and a goal the household shares.
///
/// docs/12 §12.5 keeps every social feature parent-gated, and this build stays
/// deliberately on the safe side of it: no leaderboards, no cross-family
/// comparison, and **no free text between children**. A cheer is a grown-up
/// picking one of a fixed set of phrases for their own child on their own
/// device — the highest-leverage social mechanic for this age group, and the
/// one with the least surface area.
library;

import '../../core/offline/offline_store.dart';
import 'weekly_snapshot.dart';

/// The fixed set of things a grown-up can send. Ids are stored, not text, so
/// the message is localized when the child reads it.
enum CheerKind { proud, wow, keepGoing, loveIt }

const List<CheerKind> allCheers = CheerKind.values;

String cheerEmoji(CheerKind kind) => switch (kind) {
      CheerKind.proud => '🌟',
      CheerKind.wow => '🎉',
      CheerKind.keepGoing => '💪',
      CheerKind.loveIt => '❤️',
    };

/// How long an unread cheer waits before it stops being news.
const Duration cheerFreshness = Duration(days: 3);

/// A cheer waiting for the child to see.
class PendingCheer {
  const PendingCheer({required this.kind, required this.sentAt});

  final CheerKind kind;
  final DateTime sentAt;

  bool isFreshAt(DateTime now) =>
      now.difference(sentAt).abs() <= cheerFreshness;
}

/// Parses a stored 'kindName|iso8601' cheer record.
PendingCheer? parseCheer(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('|');
  if (parts.length != 2) return null;
  final kind = CheerKind.values
      .where((k) => k.name == parts[0])
      .firstOrNull;
  final at = DateTime.tryParse(parts[1]);
  if (kind == null || at == null) return null;
  return PendingCheer(kind: kind, sentAt: at);
}

String encodeCheer(CheerKind kind, DateTime at) =>
    '${kind.name}|${at.toIso8601String()}';

// --------------------------------------------------------------- challenge

/// Activities the household is aiming for together this week.
///
/// Shared rather than competitive on purpose: siblings pulling toward one
/// number cannot produce a loser, which a leaderboard always does.
const int familyWeeklyGoal = 12;

class FamilyChallenge {
  const FamilyChallenge({
    required this.done,
    required this.goal,
    required this.contributors,
  });

  final int done;
  final int goal;

  /// Per-child contribution, keyed by child id — for the parent view only.
  final Map<String, int> contributors;

  bool get complete => done >= goal;
  double get progress => goal <= 0 ? 0 : (done / goal).clamp(0.0, 1.0);
  int get remaining => (goal - done).clamp(0, goal);
}

/// This week's family total across every child profile on the device.
FamilyChallenge familyChallengeFor(
  OfflineStore store, {
  DateTime? now,
  int goal = familyWeeklyGoal,
}) {
  final when = now ?? DateTime.now();
  final contributors = <String, int>{};
  var total = 0;
  for (final child in store.children) {
    final snap = weeklySnapshotFor(store, child.id, now: when);
    contributors[child.id] = snap.activities;
    total += snap.activities;
  }
  return FamilyChallenge(
    done: total,
    goal: goal,
    contributors: contributors,
  );
}
