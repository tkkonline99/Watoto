/// Rule-based parent insights (AI-free v1 of Parent Insights).
///
/// Produces insight codes the UI localizes via ARB — no cloud model, no child
/// free text leaves the device.
library;

import '../../core/offline/offline_store.dart';
import 'weekly_snapshot.dart';

/// Insight kind keys mapped to AppLocalizations in the parent dashboard.
enum InsightKind {
  quietWeek,
  strongWeek,
  streak,
  stars,
  oneDay,
}

class ParentInsight {
  const ParentInsight({
    required this.kind,
    required this.tone, // 'cheer' | 'nudge' | 'neutral'
    this.count = 0,
    this.days = 0,
  });

  final InsightKind kind;
  final String tone;
  final int count;
  final int days;
}

/// Build 1–3 insights for [childId]. Copy is localized at the call site.
List<ParentInsight> buildParentInsights({
  required OfflineStore store,
  required String childId,
  required String nickname,
  DateTime? now,
}) {
  final snap = weeklySnapshotFor(store, childId, now: now);
  final streak = store.streakFor(childId);
  final out = <ParentInsight>[];

  if (snap.activities == 0) {
    out.add(const ParentInsight(kind: InsightKind.quietWeek, tone: 'nudge'));
    return out;
  }

  if (snap.lessonsThisWeek >= 3) {
    out.add(ParentInsight(
      kind: InsightKind.strongWeek,
      tone: 'cheer',
      count: snap.lessonsThisWeek,
    ));
  }

  if (streak >= 3) {
    out.add(ParentInsight(
      kind: InsightKind.streak,
      tone: 'cheer',
      days: streak,
    ));
  }

  if (snap.starsEarned >= 3) {
    out.add(ParentInsight(
      kind: InsightKind.stars,
      tone: 'cheer',
      count: snap.starsEarned,
    ));
  }

  if (snap.activeDays == 1 && snap.activities >= 1) {
    out.add(const ParentInsight(kind: InsightKind.oneDay, tone: 'nudge'));
  }

  if (out.isEmpty) {
    out.add(const ParentInsight(kind: InsightKind.oneDay, tone: 'neutral'));
  }

  return out.take(3).toList();
}
