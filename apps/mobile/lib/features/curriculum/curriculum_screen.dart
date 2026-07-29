import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../library/completion.dart';
import '../library/content_i18n.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';
import 'curriculum_data.dart';
import 'curriculum_models.dart';
import 'subject_i18n.dart';

/// Browsable view of the full 10-stage curriculum (curriculum.pptx) with the
/// playable content library wired in per subject. Defaults to the active
/// child's stage; subject names follow the chosen language.
class CurriculumScreen extends ConsumerStatefulWidget {
  const CurriculumScreen({super.key});

  @override
  ConsumerState<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends ConsumerState<CurriculumScreen> {
  int? _selectedStage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final child = ref.watch(activeChildProvider);
    final repo = ref.watch(libraryProvider).asData?.value;
    final i18n = ref.watch(contentI18nProvider).asData?.value;
    final defaultStage = child == null
        ? 1
        : stageForBirthYear(child.birthYear).stage;
    final selected = _selectedStage ?? defaultStage;
    final stage = curriculumStages[selected - 1];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          l10n.curriculum,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: WatotoColors.deep,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StageSelector(
              selected: selected,
              childStage: defaultStage,
              onSelect: (s) => setState(() => _selectedStage = s),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _StageHeader(stage: stage, l10n: l10n),
                  const SizedBox(height: 12),
                  _DesignTip(text: stage.designTip, label: l10n.forGrownups),
                  const SizedBox(height: 16),
                  for (final topic in stage.topics)
                    _TopicCard(
                      topic: topic,
                      lang: lang,
                      i18n: i18n,
                      items:
                          repo?.forStageSubject(stage.stage, topic.name) ??
                          const [],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageSelector extends StatelessWidget {
  const _StageSelector({
    required this.selected,
    required this.childStage,
    required this.onSelect,
  });

  final int selected;
  final int childStage;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: curriculumStages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final stage = curriculumStages[i];
          final isSelected = stage.stage == selected;
          final isChild = stage.stage == childStage;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onSelect(stage.stage),
            selectedColor: WatotoColors.sun,
            avatar: isChild ? const Text('⭐') : null,
            label: Text(
              stage.ageRange,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected ? WatotoColors.deep : Colors.black54,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage, required this.l10n});

  final CurriculumStage stage;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final sub = stage.grade == null
        ? stage.band
        : '${stage.band} · ${stage.grade}';
    return Card(
      color: WatotoColors.sky.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.stageOf(stage.stage, stage.ageRange),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WatotoColors.sky,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stage.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              stage.theme,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignTip extends StatelessWidget {
  const _DesignTip({required this.text, required this.label});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WatotoColors.sun.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🛟', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 14, height: 1.3)),
        ],
      ),
    );
  }
}

class _TopicCard extends ConsumerWidget {
  const _TopicCard({
    required this.topic,
    required this.lang,
    required this.i18n,
    required this.items,
  });

  final CurriculumTopic topic;
  final String lang;
  final ContentI18n? i18n;
  final List<LibraryItem> items;

  static const _typeEmoji = {
    LibraryType.lesson: '📘',
    LibraryType.quiz: '❓',
    LibraryType.story: '📖',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(topic.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    localizedSubject(topic.name, lang),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            // Playable items from the content library, if any exist yet.
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Semantics(
                    button: true,
                    // Done-ness is shown with a ✓ glyph and type with an emoji;
                    // both are silent to a screen reader without this.
                    label: '${itemTitle(i18n, lang, item)}. '
                        '${item.type.name}. '
                        '${isItemDone(ref, item) ? l10n.done : l10n.tapToPlay}',
                    child: ExcludeSemantics(
                      child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/play/${item.id}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: WatotoColors.sun.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(_typeEmoji[item.type] ?? '⭐'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              itemTitle(i18n, lang, item),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          isItemDone(ref, item)
                              ? const Text(
                                  doneMark,
                                  style: TextStyle(fontSize: 20),
                                )
                              : const Icon(
                                  Icons.play_circle_fill,
                                  color: WatotoColors.mango,
                                ),
                        ],
                      ),
                    ),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            for (final activity in topic.activities)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '•  ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        activity,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
