import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../library/content_i18n.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';
import 'curriculum_data.dart';
import 'curriculum_models.dart';
import 'subject_i18n.dart';

/// Shows a single subject for one stage — only that subject's playable items
/// and topics, nothing else. Reached by tapping a subject on the home.
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.stage, required this.subject});

  final int stage;
  final String subject; // canonical English subject name

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final repo = ref.watch(libraryProvider).asData?.value;
    final i18n = ref.watch(contentI18nProvider).asData?.value;

    final stageData = (stage >= 1 && stage <= curriculumStages.length)
        ? curriculumStages[stage - 1]
        : curriculumStages.first;
    final CurriculumTopic? topic =
        stageData.topics.where((t) => t.name == subject).firstOrNull;
    final items = repo?.forStageSubject(stage, subject) ?? const <LibraryItem>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
        title: Text(localizedSubject(subject, lang),
            style: const TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.deep)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text(topic?.emoji ?? '⭐', style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(localizedSubject(subject, lang),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(l10n.stageOf(stage, stageData.ageRange),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: WatotoColors.sky)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Playable items for this subject, if any are authored yet.
            if (items.isNotEmpty) ...[
              Text(l10n.startLearning,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final item in items)
                _PlayTile(item: item, title: itemTitle(i18n, lang, item)),
              const SizedBox(height: 16),
            ],

            // The curriculum plan (what this subject covers) for this stage.
            if (topic != null) ...[
              Text(l10n.subjects,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final activity in topic.activities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(activity, style: const TextStyle(fontSize: 15))),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayTile extends StatelessWidget {
  const _PlayTile({required this.item, required this.title});

  final LibraryItem item;
  final String title;

  static const _typeEmoji = {
    LibraryType.lesson: '📘',
    LibraryType.quiz: '❓',
    LibraryType.story: '📖',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/play/${item.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: WatotoColors.sun.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Text(_typeEmoji[item.type] ?? '⭐', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.play_circle_fill, color: WatotoColors.mango, size: 28),
          ]),
        ),
      ),
    );
  }
}
