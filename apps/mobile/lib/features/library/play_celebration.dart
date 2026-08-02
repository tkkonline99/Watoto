/// What a child sees when they finish: confetti, the stars they earned, a
/// rescued streak, and any badge that just unlocked.
library;


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/mascot_widget.dart';
import '../../l10n/gen/app_localizations.dart';
import '../gamification/achievements_sheet.dart' show badgeLabel;
import '../gamification/reward_outcome.dart';
import '../gamification/rewards.dart' as rewards;

class ProgressDots extends StatelessWidget {
  const ProgressDots({required this.count, required this.active});
  final int count;
  final int active;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= active ? WatotoColors.mango : Colors.black12,
            ),
          ),
      ],
    );
  }
}

class Celebration extends ConsumerStatefulWidget {
  const Celebration({
    required this.emoji,
    required this.title,
    required this.xp,
    this.stars = 0,
    this.nextId,
  });
  final String emoji;
  final String title;
  final int xp;
  final int stars;

  /// The next playable item in the same stage+subject, if any — keeps the
  /// homework session going instead of dumping the child back at home.
  final String? nextId;

  @override
  ConsumerState<Celebration> createState() => CelebrationState();
}

class CelebrationState extends ConsumerState<Celebration> {
  /// What this completion earned, latched the moment it arrives.
  ///
  /// It cannot simply be read in [initState]: the player marks itself done and
  /// builds this screen *before* the unawaited write that produces the reward
  /// has finished. On a fast in-memory store the write usually wins the race,
  /// which is why tests never saw it — but against real IndexedDB the frame
  /// renders first and the reward reads as null, silently dropping the coins,
  /// stars and badges. So watch the provider and latch the first non-null
  /// value instead of sampling once.
  RewardOutcome? _reward;

  /// Latches [outcome] and consumes it, so leaving cannot carry the reward
  /// into the next celebration.
  void _takeReward(RewardOutcome outcome) {
    _reward = outcome;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Escalate the sound to match the moment: a new level and a rescued
      // streak should not sound identical to finishing a routine activity.
      final sfx = ref.read(soundEffectsProvider);
      if (outcome.levelUp > 0) {
        sfx.levelUp();
      } else if (outcome.streakSavedDays > 0) {
        sfx.streak();
      } else if (outcome.coins > 0) {
        sfx.coin();
      }
      // Badges are revealed here now, so drop the queue that would otherwise
      // re-announce them as a toast on the next visit to the home screen.
      if (outcome.badgeIds.isNotEmpty) {
        ref.read(pendingBadgeToastProvider.notifier).state = [];
      }
      ref.read(pendingRewardProvider.notifier).state = null;
    });
  }

  String get emoji => widget.emoji;
  String get title => widget.title;
  int get xp => widget.xp;
  int get stars => widget.stars;
  String? get nextId => widget.nextId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levelUp = ref.watch(pendingLevelUpProvider);
    final totalXp = ref.watch(xpProvider);
    final level = rewards.levelForXp(totalXp);
    final progress = rewards.levelProgress(totalXp);

    // Latch the outcome whenever the completion write lands — which may be
    // several frames after this screen first appeared.
    final incoming = ref.watch(pendingRewardProvider);
    if (incoming != null && _reward == null) {
      _takeReward(incoming);
    }

    // Everything the completion just earned. Null on the paths that have not
    // been migrated (or in tests that build this view directly), in which case
    // the screen degrades to the plain XP celebration it always was.
    final reward = _reward;
    final earnedStars = stars > 0 ? stars : (reward?.stars ?? 0);
    final coins = reward?.coins ?? 0;
    final badgeIds = reward?.badgeIds ?? const <String>[];
    final streakSaved = reward?.streakSavedDays ?? 0;
    final firstInSubject = reward?.firstInSubject ?? false;
    // Cool-down: the mascot and the big emoji stand down once a child has been
    // celebrated five times in one sitting, unless this one is a milestone.
    final brief = reward?.brief ?? false;
    // Whether anything beyond XP is on screen — drives how much room the
    // mascot is allowed to take.
    final hasExtras = earnedStars > 0 ||
        coins > 0 ||
        streakSaved > 0 ||
        badgeIds.isNotEmpty;

    final headline = levelUp > 0
        ? l10n.levelUp(levelUp)
        : earnedStars >= 3
            ? l10n.perfectRun
            : firstInSubject
                ? l10n.firstTimeHere
                : title;

    return Scaffold(
      body: SafeArea(
        // Scroll-safe at large text sizes.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!brief)
                  MascotWidget(
                    mood: MascotMood.cheer,
                    // The mascot yields room when there are real rewards to
                    // show below it, so the buttons stay reachable on a small
                    // phone without scrolling.
                    size: hasExtras ? 72 : 96,
                    label: levelUp > 0 ? l10n.levelUpShort : l10n.greatJob,
                  ),
                if (emoji.isNotEmpty && !brief && !hasExtras) ...[
                  const SizedBox(height: 8),
                  Text(emoji, style: const TextStyle(fontSize: 40)),
                ],
                const SizedBox(height: 12),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (earnedStars > 0) ...[
                  const SizedBox(height: 8),
                  EarnedStars(stars: earnedStars, animate: !brief),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.xpEarned(xp),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: WatotoColors.mango,
                  ),
                ),
                if (coins > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🪙 ${l10n.coinsEarned(coins)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: WatotoColors.deep,
                    ),
                  ),
                ],
                if (streakSaved > 0) ...[
                  const SizedBox(height: 12),
                  StreakSavedNote(days: streakSaved, l10n: l10n),
                ],
                if (badgeIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  BadgeReveal(badgeIds: badgeIds, l10n: l10n),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.levelLabel(level),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.deep,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: WatotoColors.sun.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation(WatotoColors.mango),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (nextId != null)
                      FilledButton(
                        onPressed: () =>
                            context.pushReplacement('/play/$nextId'),
                        child: Text(l10n.keepGoing),
                      ),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: Text(l10n.done),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EarnedStars extends StatelessWidget {
  const EarnedStars({required this.stars, this.animate = true});

  final int stars;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: i < stars
                    ? TweenAnimationBuilder<double>(
                        // Each star lands a beat after the one before it.
                        duration: Duration(
                          milliseconds: animate ? 260 + i * 180 : 1,
                        ),
                        curve: Curves.elasticOut,
                        tween: Tween(begin: animate ? 0 : 1, end: 1),
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: const Text(
                          '⭐',
                          style: TextStyle(fontSize: 40),
                        ),
                      )
                    : const Opacity(
                        opacity: 0.22,
                        child: Text(
                          '⭐',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Your streak survived" — shown when the weekly shield covered a missed day.
/// This used to happen silently, which threw away the one moment where the
/// streak system is genuinely reassuring rather than demanding.
class StreakSavedNote extends StatelessWidget {
  const StreakSavedNote({required this.days, required this.l10n});

  final int days;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WatotoColors.sky.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '🛡️ ${l10n.streakSavedTitle}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: WatotoColors.deep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.streakSavedBody(days),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Badges revealed at the moment they are earned, rather than as a toast the
/// next time the child happens to open the home screen.
class BadgeReveal extends StatelessWidget {
  const BadgeReveal({required this.badgeIds, required this.l10n});

  final List<String> badgeIds;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final catalog = {for (final b in rewards.allBadges) b.id: b};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WatotoColors.sun.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            l10n.badgeUnlocked,
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: WatotoColors.deep,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final id in badgeIds)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.elasticOut,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        catalog[id]?.emoji ?? '🏅',
                        style: const TextStyle(fontSize: 34),
                      ),
                      Text(
                        badgeLabel(l10n, id),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
