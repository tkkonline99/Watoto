import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../features/curriculum/age_picker.dart';
import '../../features/curriculum/subject_catalog.dart';
import '../../features/curriculum/subject_i18n.dart';
import '../../l10n/gen/app_localizations.dart';

/// Child home — greeting, the day's playable challenge, the academic subjects,
/// and the storybook library. There is no fixed stage: the child picks an age
/// when they open a subject or the daily challenge, then sees content matched
/// to that age.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
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
            Text(l10n.subjects,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                for (final category in subjectCatalog)
                  _SubjectCard(category: category, lang: lang),
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

/// Opens the age picker for [subject], then drills into that subject's content
/// for the chosen age. Shared by the subject cards and the daily challenge.
Future<void> _openSubjectForAge(
  BuildContext context, {
  required SubjectCategory subject,
  required String heading,
}) async {
  final stage = await showAgePicker(
    context,
    stages: subject.stagesAvailable(),
    heading: heading,
  );
  if (stage == null || !context.mounted) return;
  final topic = subject.topicNameFor(stage)!;
  context.push('/subject/${stage.stage}/${Uri.encodeComponent(topic)}');
}

class _LanguageMenu extends ConsumerWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language_rounded, color: WatotoColors.deep),
      tooltip: l10n.chooseLanguage,
      onSelected: (locale) => ref.read(localeProvider.notifier).set(locale),
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
              // The daily challenge is age-aware too: pick an age, then play
              // the challenge for that age.
              onPressed: () => _openSubjectForAge(
                context,
                subject: dailyChallengeSubject,
                heading: l10n.dailyChallenge,
              ),
              child: Text(l10n.startLearning),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.category, required this.lang});

  final SubjectCategory category;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Pick an age first, then drill into this subject for that age.
        onTap: () => _openSubjectForAge(
          context,
          subject: category,
          heading: localizedSubject(category.englishLabel, lang),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [WatotoColors.sky.withValues(alpha: 0.18), Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                localizedSubject(category.englishLabel, lang),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
