import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'badge_stats_source.dart';
import 'rewards.dart';

/// Localized label for a badge id (shared by parent dashboard + child sheet).
///
/// The fallback returns the raw id, which is a camelCase debug string — six
/// badges in the expanded catalogue used to reach it, so children were shown
/// "twentyLessons" as an achievement name. `badgeLabelCoverage` in
/// test/rewards_test.dart now fails if a badge is added without a label here.
String badgeLabel(AppLocalizations l10n, String id) => switch (id) {
      'firstLesson' => l10n.badgeFirstLesson,
      'threeLessons' => l10n.badgeThreeLessons,
      'fiveLessons' => l10n.badgeFiveLessons,
      'tenLessons' => l10n.badgeTenLessons,
      'twentyLessons' => l10n.badgeTwentyLessons,
      'streak3' => l10n.badgeStreak3,
      'streak7' => l10n.badgeStreak7,
      'streak14' => l10n.badgeStreak14,
      'firstStory' => l10n.badgeFirstStory,
      'threeStories' => l10n.badgeThreeStories,
      'level5' => l10n.badgeLevel5,
      'level10' => l10n.badgeLevel10,
      'dailyChallenge' => l10n.badgeDailyChallenge,
      'firstQuiz' => l10n.badgeFirstQuiz,
      'perfectQuiz' => l10n.badgePerfectQuiz,
      _ => id,
    };

/// Opens a kid-friendly achievements sheet (level bar + badge grid).
Future<void> showAchievementsSheet(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final store = ref.read(offlineStoreProvider);
  final child = ref.read(activeChildProvider);
  final childId = child?.id;
  final xp = childId == null ? 0 : store.xpFor(childId);
  final held = heldBadgesFor(store, childId).map((b) => b.id).toSet();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final level = levelForXp(xp);
      final into = xpIntoLevel(xp);
      final progress = levelProgress(xp);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.achievements,
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.levelLabel(level),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: WatotoColors.deep.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: WatotoColors.sun.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation(WatotoColors.mango),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.xpToNextLevel(
                  into,
                  xpSpanForLevel(level),
                  xpToNextLevel(xp),
                ),
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.badgesTitle,
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final b in allBadges)
                    _BadgeChip(
                      emoji: b.emoji,
                      label: badgeLabel(l10n, b.id),
                      earned: held.contains(b.id),
                    ),
                ],
              ),
              if (held.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.noBadgesYet,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.emoji,
    required this.label,
    required this.earned,
  });

  final String emoji;
  final String label;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1 : 0.38,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: earned
              ? WatotoColors.sun.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? WatotoColors.mango : Colors.black12,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WatotoColors.deep.withValues(alpha: earned ? 1 : 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
