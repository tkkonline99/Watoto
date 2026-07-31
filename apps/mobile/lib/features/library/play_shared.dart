/// Pieces every play surface needs: the localized view of an item, the app bar,
/// the narration button, and the rules for what a stage shows.
///
/// These lived in library_play_screen.dart, which meant the stage widgets had to
/// import the screen that composes them. They belong below both.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/narration.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'content_art.dart';
import 'content_i18n.dart';
import 'library_models.dart';
import 'library_repository.dart';
import 'step_play.dart';
import 'step_visuals.dart';

/// Builds the localized view of an item from the current locale.
LocalizedItem localizedItem(WidgetRef ref, LibraryItem item) {
  final lang = ref.watch(localeProvider).languageCode;
  final i18n = ref.watch(contentI18nProvider).asData?.value;
  return LocalizedItem(item, i18n, lang);
}

PreferredSizeWidget playAppBar(BuildContext context, String title) => AppBar(
  backgroundColor: Colors.transparent,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
    onPressed: () => context.pop(),
  ),
  title: Text(
    title,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      color: WatotoColors.deep,
    ),
  ),
  actions: const [NarrationButton()],
);

/// Toggles spoken narration on/off; the icon reflects the current state.
class NarrationButton extends ConsumerWidget {
  const NarrationButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(narrationProvider);
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.readAloud,
      icon: Icon(
        on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        color: WatotoColors.deep,
      ),
      onPressed: () => ref.read(narrationProvider.notifier).toggle(),
    );
  }
}

/// Stages that print the step's prompt themselves, right beside the thing the
/// child touches. The caption-level hint is suppressed for these so the same
/// instruction is never shown twice on one screen.
bool stageShowsPrompt(StepMechanic mechanic) => switch (mechanic) {
      StepMechanic.tap ||
      StepMechanic.celebrate ||
      StepMechanic.count ||
      StepMechanic.drag ||
      StepMechanic.explain =>
        true,
      // A choice stage lists answers and nothing else: its question has to be
      // printed above them or the child is picking blind.
      StepMechanic.multiChoice ||
      StepMechanic.numberAnswer ||
      StepMechanic.buildArray ||
      StepMechanic.codeRun =>
        false,
    };

/// Stages that render the step's emoji as their own (tappable) hero. When one
/// of these is on screen the illustration above it would be a mute duplicate.
bool stageShowsEmoji(StepMechanic mechanic) => switch (mechanic) {
      StepMechanic.tap ||
      StepMechanic.multiChoice ||
      StepMechanic.celebrate ||
      StepMechanic.count ||
      StepMechanic.drag ||
      StepMechanic.explain =>
        true,
      StepMechanic.numberAnswer ||
      StepMechanic.buildArray ||
      StepMechanic.codeRun =>
        false,
    };

Widget emojiPlaceholder(String emoji) => Container(
  width: 140,
  height: 140,
  decoration: BoxDecoration(
    color: WatotoColors.sky.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(24),
  ),
  alignment: Alignment.center,
  child: Text(emoji, style: const TextStyle(fontSize: 72)),
);

/// Prefer a bundled illustration; fall back to emoji placeholder.
Widget artOrEmoji(LibraryItem item, String emoji) =>
    itemArt(item) ?? emojiPlaceholder(emoji);

/// The item's illustration, or null when nothing is bundled for it. Used above
/// stages that already show the emoji, where a placeholder would just be the
/// same picture twice — one dead, one alive.
Widget? artOnly(LibraryItem item) => itemArt(item);

/// The picture above a stage: this step's own illustration if one has been
/// drawn, otherwise the item's, otherwise nothing.
///
/// Per-step art is what actually depicts the sentence — the starter pack is
/// item-level and stops at stage 3, so a stage-9 reading step has no picture of
/// what it is describing. `image_manifest.csv` holds an `art_brief` for every
/// step; rendering one to the path [stepArtAsset] names makes it appear here.
Widget stepArt(LibraryItem item, int stepIndex) {
  final fallback = itemArt(item) ?? const SizedBox.shrink();
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Image.asset(
      stepArtAsset(item, stepIndex),
      width: 180,
      height: 180,
      fit: BoxFit.cover,
      // Nothing is drawn for most steps yet, so a miss is the normal path.
      errorBuilder: (_, _, _) => fallback,
    ),
  );
}

Widget? itemArt(LibraryItem item) {
  final path = artAssetForItem(item);
  if (path == null) return null;
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Image.asset(
      path,
      width: 180,
      height: 180,
      fit: BoxFit.cover,
      // A missing/unbundled file collapses to nothing rather than duplicating
      // the stage's emoji.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}


/// Legacy mapping kept for any remaining call sites / tests.
enum PlayKind { tap, count, drag }

PlayKind playKind(String interaction) {
  final i = interaction.toLowerCase();
  if (i.contains('count') || i.contains('number-line') || i.contains('array')) {
    return PlayKind.count;
  }
  if (i.startsWith('drag') ||
      i.contains('build') ||
      i.contains('order') ||
      i.contains('blocks') ||
      i.contains('trace')) {
    return PlayKind.drag;
  }
  return PlayKind.tap;
}

/// Item-level picture for the stage chrome. Delegates to the shared resolver
/// in step_visuals.dart, which is total over the library's subjects — there is
/// no meaningless ⭐ fallback any more.
String stageEmoji(LibraryItem item) => itemIllustration(item);

/// Next incomplete item after [item] in the same stage+subject, then any
/// incomplete in that subject (keeps the learning session going).
LibraryItem? nextInSubject(WidgetRef ref, LibraryItem item) {
  final repo = ref.watch(libraryProvider).asData?.value;
  if (repo == null) return null;
  final childId = ref.read(sessionProvider).activeChildId;
  final store = ref.read(offlineStoreProvider);
  final list = repo.forStageSubject(item.stage, item.subject);
  final i = list.indexWhere((x) => x.id == item.id);
  if (i >= 0) {
    for (var j = i + 1; j < list.length; j++) {
      final next = list[j];
      if (childId == null) return next;
      if (!store.hasCompletedLibraryItem(childId, next.id, next.type.name)) {
        return next;
      }
    }
  }
  // Fall back: any incomplete in subject (including earlier).
  if (childId != null) {
    for (final next in list) {
      if (next.id == item.id) continue;
      if (!store.hasCompletedLibraryItem(childId, next.id, next.type.name)) {
        return next;
      }
    }
  }
  return null;
}
