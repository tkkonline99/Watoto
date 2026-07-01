import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/narration.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../features/gamification/rewards.dart';
import '../../l10n/gen/app_localizations.dart';

/// Parent dashboard: per-child progress, consent management, add child.
/// Reached only through the PIN gate (router guard).
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.watch(sessionProvider); // rebuild after consent / profile changes
    final store = ref.watch(offlineStoreProvider);
    final children = ref.watch(childrenProvider);
    final consent = store.consent;
    final textScale = ref.watch(textScaleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.parentZone),
        actions: [
          IconButton(
            tooltip: l10n.lockParentZone,
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(sessionProvider.notifier).lockParent();
              context.go('/');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.children, style: _section),
            const SizedBox(height: 8),
            for (final child in children)
              Builder(
                builder: (context) {
                  final xp = store.xpFor(child.id);
                  final stats = BadgeStats(
                    xp: xp,
                    streak: store.streakFor(child.id),
                    lessons: store.completedLessonCount(child.id),
                    stories: store.completedStoryCount(child.id),
                  );
                  final badges = earnedBadges(stats);
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: WatotoColors.sun,
                            child: Text(
                              child.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          title: Text(
                            child.nickname,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${l10n.ageBandLabel(child.ageBand.label)} · '
                            '${l10n.levelLabel(stats.level)}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$xp XP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: WatotoColors.mango,
                                ),
                              ),
                              Text(
                                l10n.lessonsDone(
                                  store.completedLessonCount(child.id),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: badges.isEmpty
                                ? Text(
                                    l10n.noBadgesYet,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      for (final b in badges)
                                        Tooltip(
                                          message: badgeLabel(l10n, b.id),
                                          child: Text(
                                            b.emoji,
                                            style: const TextStyle(
                                              fontSize: 22,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.addChild),
              onPressed: () => context.go('/profiles/add'),
            ),
            const Divider(height: 32),
            Text(l10n.privacyData, style: _section),
            const SizedBox(height: 8),
            SwitchListTile(
              value: consent.aiFeatures,
              title: Text(l10n.consentAi),
              subtitle: Text(l10n.consentAiBody),
              onChanged: (v) => ref
                  .read(sessionProvider.notifier)
                  .saveConsent(consent.copyWith(aiFeatures: v)),
            ),
            SwitchListTile(
              value: consent.voiceRecording,
              title: Text(l10n.consentVoice),
              subtitle: Text(l10n.consentVoiceBody),
              onChanged: (v) => ref
                  .read(sessionProvider.notifier)
                  .saveConsent(consent.copyWith(voiceRecording: v)),
            ),
            const Divider(height: 32),
            Text(l10n.accessibility, style: _section),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.format_size, color: WatotoColors.deep),
                const SizedBox(width: 12),
                Text(
                  l10n.textSize,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _sizeChip(ref, l10n.textSizeSmall, 1.0, textScale),
                _sizeChip(ref, l10n.textSizeMedium, 1.3, textScale),
                _sizeChip(ref, l10n.textSizeLarge, 1.6, textScale),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ref.watch(narrationProvider),
              title: Text(l10n.readAloud),
              subtitle: Text(l10n.readAloudBody),
              onChanged: (_) => ref.read(narrationProvider.notifier).toggle(),
            ),
            const Divider(height: 32),
            Text(l10n.legalSection, style: _section),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              subtitle: Text(l10n.legalDraftNote),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/parent/legal/privacy'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.termsOfService),
              subtitle: Text(l10n.legalDraftNote),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/parent/legal/terms'),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.switch_account),
              title: Text(l10n.switchChild),
              onTap: () {
                ref.read(sessionProvider.notifier).lockParent();
                ref.read(sessionProvider.notifier).switchChild();
                context.go('/profiles');
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _section = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: WatotoColors.deep,
  );
}

/// A selectable text-size chip; [value] is the multiplier it applies.
Widget _sizeChip(WidgetRef ref, String label, double value, double current) {
  return ChoiceChip(
    label: Text(label),
    selected: (current - value).abs() < 0.01,
    onSelected: (_) => ref.read(textScaleProvider.notifier).set(value),
  );
}

/// Localized label for a badge id (see [rewards.dart]).
String badgeLabel(AppLocalizations l10n, String id) => switch (id) {
  'firstLesson' => l10n.badgeFirstLesson,
  'fiveLessons' => l10n.badgeFiveLessons,
  'streak3' => l10n.badgeStreak3,
  'streak7' => l10n.badgeStreak7,
  'firstStory' => l10n.badgeFirstStory,
  'level5' => l10n.badgeLevel5,
  _ => id,
};
