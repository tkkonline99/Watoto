import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';

class _SubjectIsland {
  const _SubjectIsland({
    required this.label,
    required this.emoji,
    required this.color,
    this.lessonSlug,
    this.locked = false,
  });

  final String Function(AppLocalizations) label;
  final String emoji;
  final Color color;
  final String? lessonSlug;
  final bool locked;
}

final _islands = <_SubjectIsland>[
  _SubjectIsland(
    label: (l) => l.subjectMath,
    emoji: '🔢',
    color: WatotoColors.sky,
    lessonSlug: 'counting-1-3',
  ),
  _SubjectIsland(label: (l) => l.subjectEnglish, emoji: '📚', color: WatotoColors.leaf),
  _SubjectIsland(label: (l) => l.subjectScience, emoji: '🌱', color: WatotoColors.mango),
  _SubjectIsland(label: (l) => l.subjectArt, emoji: '🎨', color: WatotoColors.berry, locked: true),
];

class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final child = ref.watch(activeChildProvider);
    final nickname = child?.nickname ?? '';
    final xp = ref.watch(xpProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: l10n.whoIsLearning,
          icon: Text(child?.emoji ?? '🦁', style: const TextStyle(fontSize: 24)),
          onPressed: () => context.go('/profiles'),
        ),
        title: Text(
          l10n.homeGreeting(nickname),
          style: const TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.deep),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              avatar: const Icon(Icons.star_rounded, color: WatotoColors.mango),
              label: Text('$xp XP'),
            ),
          ),
          const _LanguageMenu(),
          IconButton(
            tooltip: l10n.parentZone,
            icon: const Icon(Icons.lock_outline, color: WatotoColors.deep),
            onPressed: () => context.go('/parent'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DailyChallengeCard(l10n: l10n),
            const SizedBox(height: 16),
            Text(
              l10n.subjects,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [for (final island in _islands) _IslandCard(island: island)],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageMenu extends ConsumerWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language_rounded, color: WatotoColors.deep),
      tooltip: l10n.chooseLanguage,
      onSelected: (locale) => ref.read(localeProvider.notifier).state = locale,
      itemBuilder: (context) => const [
        PopupMenuItem(value: Locale('en'), child: Text('English')),
        PopupMenuItem(value: Locale('sw'), child: Text('Kiswahili')),
        PopupMenuItem(value: Locale('fr'), child: Text('Français')),
      ],
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: WatotoColors.sun,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 40)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.dailyChallenge,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: WatotoColors.deep,
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.go('/lesson/counting-1-3'),
              child: Text(l10n.startLearning),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslandCard extends StatelessWidget {
  const _IslandCard({required this.island});

  final _SubjectIsland island;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = island.lessonSlug != null && !island.locked;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => context.go('/lesson/${island.lessonSlug}') : null,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [island.color.withValues(alpha: 0.25), Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(island.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                island.label(l10n),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (island.locked) ...[
                const SizedBox(height: 4),
                Tooltip(
                  message: l10n.premiumLocked,
                  child: const Icon(Icons.lock_rounded, color: WatotoColors.deep),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
