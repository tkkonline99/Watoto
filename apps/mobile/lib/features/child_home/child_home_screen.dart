import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../features/curriculum/curriculum_data.dart';
import '../../features/curriculum/curriculum_models.dart';
import '../../features/curriculum/subject_i18n.dart';
import '../../l10n/gen/app_localizations.dart';

/// Child home — greeting, the child's current curriculum stage (from
/// curriculum.pptx), the day's playable challenge, the stage's subjects, and
/// the storybook library.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final child = ref.watch(activeChildProvider);
    final nickname = child?.nickname ?? '';
    final xp = ref.watch(xpProvider);
    final stage =
        child == null ? curriculumStages.first : stageForBirthYear(child.birthYear);

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
            _StageBanner(stage: stage, l10n: l10n),
            const SizedBox(height: 12),
            _DailyChallengeCard(l10n: l10n),
            const SizedBox(height: 16),
            Text(l10n.subjects,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                for (final topic in stage.topics)
                  _SubjectCard(emoji: topic.emoji, label: localizedSubject(topic.name, lang)),
              ],
            ),
            const SizedBox(height: 16),
            _StorybooksCard(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.stage, required this.l10n});

  final CurriculumStage stage;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('/curriculum'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: WatotoColors.sky.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.stageOf(stage.stage, stage.ageRange),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: WatotoColors.sky)),
                  Text(stage.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: WatotoColors.deep),
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

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/curriculum'),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [WatotoColors.sky.withValues(alpha: 0.18), Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorybooksCard extends StatelessWidget {
  const _StorybooksCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: WatotoColors.leaf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go('/stories'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.storybooks,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
