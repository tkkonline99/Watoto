import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/entitlements.dart';
import '../library/completion.dart';
import '../library/content_i18n.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';
import 'curriculum_data.dart';
import 'curriculum_i18n.dart';
import 'curriculum_models.dart';
import 'subject_catalog.dart';
import 'subject_i18n.dart';
import '../../router/return_to.dart';

/// Shows one subject for one stage: its playable items, how far the child has
/// got, and what the curriculum covers. Reached by tapping a subject on the
/// home.
///
/// A home subject can hold several topics at one age — Reading *and* Writing
/// from age 8, four science topics for a baby — so they sit side by side as
/// chips and the child moves between them here. [subject] is the topic the
/// screen opens on.
class SubjectDetailScreen extends ConsumerStatefulWidget {
  const SubjectDetailScreen({
    super.key,
    required this.stage,
    required this.subject,
  });

  final int stage;
  final String subject; // canonical English topic name

  @override
  ConsumerState<SubjectDetailScreen> createState() =>
      _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  late String _topicName = widget.subject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final repo = ref.watch(libraryProvider).asData?.value;
    final i18n = ref.watch(contentI18nProvider).asData?.value;
    final entitlement = ref.watch(entitlementProvider);
    final stage = widget.stage;
    final locked = !isStageUnlocked(
      stage,
      entitlement,
      freeMax: ref.watch(freeStageMaxProvider),
    );

    final stageData = (stage >= 1 && stage <= curriculumStages.length)
        ? curriculumStages[stage - 1]
        : curriculumStages.first;
    // The opened topic's neighbours under the same home subject. Offered only
    // when the opened topic is one of them, so a link to a topic from another
    // stage still shows just that topic.
    final siblings = homeSubjectFor(widget.subject)?.topicNamesFor(stageData) ??
        const <String>[];
    final topicChoices =
        siblings.contains(widget.subject) ? siblings : const <String>[];
    final CurriculumTopic? topic = stageData.topics
        .where((t) => t.name == _topicName)
        .firstOrNull;
    final items =
        repo?.forStageSubject(stage, _topicName) ?? const <LibraryItem>[];
    final done = [for (final item in items) isItemDone(ref, item)];
    final doneCount = done.where((d) => d).length;
    // Where to carry on: the first unfinished item. None while locked, and
    // none once everything is done.
    final nextIndex = locked ? -1 : done.indexOf(false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          localizedSubject(_topicName, lang),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: WatotoColors.deep,
          ),
        ),
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
                      Text(
                        localizedSubject(_topicName, lang),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.stageOf(stage, stageData.ageRange),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: WatotoColors.sky,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (topicChoices.length > 1) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in topicChoices)
                    ChoiceChip(
                      selected: name == _topicName,
                      showCheckmark: false,
                      selectedColor: WatotoColors.sun,
                      onSelected: (_) => setState(() => _topicName = name),
                      avatar: ExcludeSemantics(
                        child: Text(
                          stageData.topics
                              .firstWhere((t) => t.name == name)
                              .emoji,
                        ),
                      ),
                      label: Text(
                        localizedSubject(name, lang),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ],
            if (locked) ...[
              const SizedBox(height: 16),
              Card(
                color: WatotoColors.sun.withValues(alpha: 0.15),
                child: ListTile(
                  leading: const Icon(Icons.lock_rounded),
                  title: Text(l10n.premiumLocked),
                  subtitle: Text(l10n.premiumAskGrownUp),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    gateWithReturn('/paywall', hereLocation(context)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Playable items for this topic, if any are authored yet.
            if (items.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.startLearning,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    l10n.subjectDoneCount(doneCount, items.length),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WatotoColors.deep.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // The count beside it already says this aloud.
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: doneCount / items.length,
                    minHeight: 8,
                    color: WatotoColors.leaf,
                    backgroundColor: WatotoColors.sun.withValues(alpha: 0.22),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < items.length; i++)
                _PlayTile(
                  item: items[i],
                  title: itemTitle(i18n, lang, items[i]),
                  done: done[i],
                  locked: locked,
                  upNext: i == nextIndex,
                ),
              const SizedBox(height: 16),
            ] else ...[
              // Never a dead-end: a friendly note when nothing is authored yet.
              _ComingSoonCard(
                title: l10n.comingSoonTitle,
                body: l10n.comingSoonBody,
              ),
              const SizedBox(height: 16),
            ],

            // The curriculum plan (what this topic covers) for this stage.
            if (topic != null) ...[
              Text(
                l10n.subjectPlanTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final activity in topic.activities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          localizedCurriculum(activity, lang),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
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

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WatotoColors.sky.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🚧', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayTile extends StatelessWidget {
  const _PlayTile({
    required this.item,
    required this.title,
    this.done = false,
    this.locked = false,
    this.upNext = false,
  });

  final LibraryItem item;
  final String title;

  /// Whether the active child has already completed this item.
  final bool done;
  final bool locked;

  /// The first unfinished item on the page — where the child carries on.
  final bool upNext;

  static const _typeEmoji = {
    LibraryType.lesson: '📘',
    LibraryType.quiz: '❓',
    LibraryType.story: '📖',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Locked / done state lives in a 🔒 or ✓ glyph, which assistive tech
    // either skips or reads as its Unicode name. The kind comes from the ARB
    // files, not the enum: `item.type.name` is English in every language.
    final state = locked
        ? l10n.premiumLocked
        : (done ? l10n.done : l10n.tapToPlay);
    final next = upNext ? '. ${l10n.upNext}' : '';
    return Semantics(
      button: true,
      enabled: !locked,
      label: '$title. ${itemTypeLabel(l10n, item.type)}. $state$next',
      child: _tile(context, l10n),
    );
  }

  Widget _tile(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (locked) {
            context.go(gateWithReturn('/paywall', hereLocation(context)));
            return;
          }
          context.push('/play/${item.id}');
        },
        // Excluded inside the InkWell, not around it: around it, the tap
        // action went too, and a screen reader could hear the lesson but
        // not open it.
        child: ExcludeSemantics(
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: WatotoColors.sun.withValues(alpha: upNext ? 0.30 : 0.18),
            borderRadius: BorderRadius.circular(14),
            border: upNext
                ? Border.all(color: WatotoColors.mango, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Text(
                locked ? '🔒' : (_typeEmoji[item.type] ?? '⭐'),
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (upNext) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: WatotoColors.mango,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.upNext,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              done
                  ? const Text(doneMark, style: TextStyle(fontSize: 22))
                  : const Icon(
                      Icons.play_circle_fill,
                      color: WatotoColors.mango,
                      size: 28,
                    ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
