import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/watoto_status_views.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../router/return_to.dart';
import '../auth/entitlements.dart';
import '../curriculum/curriculum_data.dart';
import '../curriculum/subject_i18n.dart';
import '../gamification/daily_challenge.dart';
import '../library/completion.dart';
import '../library/content_i18n.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';

/// Storybook library — the story items from the content library, one age at a
/// time. Tapping one opens the story player.
///
/// It opens on the child's own age, with the other ages a chip away. It used
/// to list all 114 stories — ages 0–1 to 9–10 — in one column, so a
/// three-year-old scrolled past stories written for ten-year-olds, each
/// labelled with its subject in English whatever the family's language.
class StoryLibraryScreen extends ConsumerStatefulWidget {
  const StoryLibraryScreen({super.key});

  @override
  ConsumerState<StoryLibraryScreen> createState() =>
      _StoryLibraryScreenState();
}

class _StoryLibraryScreenState extends ConsumerState<StoryLibraryScreen> {
  /// The age the family picked; null until they pick one.
  int? _stage;

  final _selectedChip = GlobalKey();
  bool _revealedSelection = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final libAsync = ref.watch(libraryProvider);
    final child = ref.watch(activeChildProvider);
    final store = ref.watch(offlineStoreProvider);
    final childStage = child == null ? null : stageForChild(child, store).stage;
    final selected =
        _stage ?? childStage ?? publishedCurriculumStages.first.stage;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          l10n.storybooks,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: WatotoColors.deep,
          ),
        ),
      ),
      body: SafeArea(
        child: libAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => WatotoLoadError(
            onRetry: () => ref.invalidate(libraryProvider),
          ),
          data: (repo) {
            final lang = ref.watch(localeProvider).languageCode;
            final i18n = ref.watch(contentI18nProvider).asData?.value;
            final locked = !isStageUnlocked(
              selected,
              ref.watch(entitlementProvider),
              freeMax: ref.watch(freeStageMaxProvider),
            );
            final stories = [
              for (final item in repo.all)
                if (item.type == LibraryType.story && item.stage == selected)
                  item,
            ];
            _revealSelectedChipOnce();
            return Column(
              children: [
                SizedBox(
                  height: 56,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        for (final stage in publishedCurriculumStages)
                          Padding(
                            key: stage.stage == selected ? _selectedChip : null,
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: stage.stage == selected,
                              showCheckmark: false,
                              selectedColor: WatotoColors.sun,
                              onSelected: (_) =>
                                  setState(() => _stage = stage.stage),
                              // The child's own age wears a star.
                              avatar: stage.stage == childStage
                                  ? const ExcludeSemantics(child: Text('⭐'))
                                  : null,
                              label: Text(
                                l10n.ageBandLabel(stage.ageRange),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      for (final story in stories)
                        _StoryTile(
                          story: story,
                          title: itemTitle(i18n, lang, story),
                          subject: localizedSubject(story.subject, lang),
                          done: isItemDone(ref, story),
                          locked: locked,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// An older child's age chip starts off-screen to the right; bring it into
  /// view the first time the list is built.
  void _revealSelectedChipOnce() {
    if (_revealedSelection) return;
    _revealedSelection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _selectedChip.currentContext;
      if (chip != null && chip.mounted) {
        Scrollable.ensureVisible(chip, alignment: 0.5);
      }
    });
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.story,
    required this.title,
    required this.subject,
    this.done = false,
    this.locked = false,
  });

  final LibraryItem story;
  final String title;

  /// The story's subject in the family's language.
  final String subject;

  /// Whether the active child has already read this story.
  final bool done;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = locked
        ? l10n.premiumLocked
        : (done ? l10n.done : l10n.tapToPlay);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      // The label sits above the InkWell and the exclusion inside it, so the
      // reader hears one sentence and can still activate the tile: excluding
      // the InkWell itself would take its tap action away too.
      child: Semantics(
        button: true,
        enabled: !locked,
        label: '$title. $subject. $state',
        child: InkWell(
          onTap: () {
            if (locked) {
              context.go(gateWithReturn('/paywall', hereLocation(context)));
              return;
            }
            context.push('/play/${story.id}');
          },
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    locked ? '🔒' : '📖',
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject,
                          style: TextStyle(
                            fontSize: 14,
                            color: WatotoColors.deep.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  done
                      ? const Text(doneMark, style: TextStyle(fontSize: 22))
                      : const Icon(
                          Icons.play_circle_fill,
                          color: WatotoColors.mango,
                          size: 30,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
