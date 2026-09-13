/// Pieces every play surface needs: the localized view of an item, the app bar,
/// the narration button, and the rules for what a stage shows.
///
/// These lived in library_play_screen.dart, which meant the stage widgets had to
/// import the screen that composes them. They belong below both.
library;

import 'dart:async';

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
import 'play_style.dart';
import 'step_play.dart';
import 'step_visuals.dart';

/// Moves a play surface on once the child has had both a beat to see the
/// result and the time to hear it, whichever comes later.
///
/// Advancing on a fixed timer cut the spoken feedback off mid-sentence: the
/// next line stops the voice, and "Woof! The puppy woke up happy." does not
/// fit in 1.4 seconds. [cap] stops a voice that never reports finishing — a
/// browser drops the reply for an utterance that errors — from holding the
/// activity still. The Next button stays live throughout, so waiting never
/// blocks a child who wants to go on.
class SpeechBeat {
  SpeechBeat({
    required Future<void> speech,
    required Duration minimum,
    required this.onDone,
    Duration cap = const Duration(seconds: 8),
  }) {
    _minimum = Timer(minimum, () {
      _minimumPassed = true;
      _maybeFinish();
    });
    _cap = Timer(cap, () {
      _heard = true;
      _maybeFinish();
    });
    speech.catchError((Object _) {}).whenComplete(() {
      _heard = true;
      _maybeFinish();
    });
  }

  /// Runs once, when the beat has passed and the line has been heard.
  final VoidCallback onDone;
  late final Timer _minimum;
  late final Timer _cap;
  bool _minimumPassed = false;
  bool _heard = false;
  bool _finished = false;

  void _maybeFinish() {
    if (_finished || !_minimumPassed || !_heard) return;
    _finished = true;
    _cap.cancel();
    onDone();
  }

  /// Drops the pending move; the callback will not run.
  void cancel() {
    _finished = true;
    _minimum.cancel();
    _cap.cancel();
  }
}

/// Builds the localized view of an item from the current locale.
LocalizedItem localizedItem(WidgetRef ref, LibraryItem item) {
  final lang = ref.watch(localeProvider).languageCode;
  final i18n = ref.watch(contentI18nProvider).asData?.value;
  return LocalizedItem(item, i18n, lang);
}

/// The same view, but waited for rather than sampled.
///
/// [localizedItem] reads the locale bundle as a snapshot, which is right in a
/// `build`: it is null while the bundle loads, and the screen rebuilds when it
/// arrives. It is wrong for narration, which is fired once from a post-frame
/// callback and never repeated.
///
/// Nothing on the way to a play screen touches the bundle, so the first item
/// opened after a cold start is what starts it loading — and it then spoke
/// from the snapshot a frame later, while that load was still in flight. The
/// result was the English text read aloud by the child's own language voice,
/// on the first thing they played every time they opened the app.
Future<LocalizedItem> awaitLocalizedItem(WidgetRef ref, LibraryItem item) async {
  final lang = ref.read(localeProvider).languageCode;
  // ContentI18n.load never rejects — a bundle it cannot read becomes empty —
  // so this waits for the load, it does not gamble on it.
  final i18n = await ref.read(contentI18nProvider.future);
  return LocalizedItem(item, i18n, lang);
}

/// The co-play prompt for a grown-up, on activities aimed at the very young.
///
/// Stages 1–2 are `parent-led`: the design tier says outright that the parent
/// is the primary user, and the content is written to match — "Pat a real pot
/// or drum together to feel the beat", "Play real peekaboo first with your
/// hands, then on screen". Those notes are the lesson at this age; the screen
/// is only the prompt. They were authored on every item and displayed nowhere,
/// because their only reader was [coPlayTipFor] in play_style.dart, which
/// nothing called.
///
/// Deliberately quiet: small, low-contrast, at the foot of the screen. It is
/// addressed to the adult holding the device, and must not compete with the
/// child for the middle of it.
class CoPlayTip extends ConsumerWidget {
  const CoPlayTip({super.key, required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Older bands get no tip: the child is the user by then, and a standing
    // instruction to a grown-up who is not there is just clutter.
    if (!isToddlerStage(item.stage)) return const SizedBox.shrink();
    final loc = localizedItem(ref, item);
    final tip = coPlayTipFor(
      stage: item.stage,
      subject: item.subject,
      parentNote: loc.parentNote,
      lang: loc.lang,
    );
    if (tip.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: WatotoColors.deep.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.forGrownups.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: WatotoColors.deep.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: WatotoColors.deep.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

/// "Hear it again" — replays the sentence the child is answering.
///
/// The narration speaks itself once when a step arrives and is then gone. A
/// two-year-old who missed it had no way to ask for it back: the only audio
/// control on the screen was the app-bar toggle, which *silences* narration
/// rather than repeating it, and reads as a mute button to anyone who does not
/// already know better.
///
/// Hidden when narration is switched off, because a button offering to say
/// something aloud must not be there when nothing will be said.
class ReplayNarrationButton extends ConsumerWidget {
  const ReplayNarrationButton({super.key, required this.onReplay});

  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(narrationProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.hearItAgain,
      child: InkWell(
        onTap: onReplay,
        borderRadius: BorderRadius.circular(20),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: WatotoColors.sun,
                    boxShadow: [
                      BoxShadow(
                        color: WatotoColors.deep.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    size: 38,
                    color: WatotoColors.deep,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.hearItAgain,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.mango,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      // The circuit board carries "Drop each part into its socket" inside the
      // loop, where the child is already looking.
      StepMechanic.buildCircuit => true,
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
      StepMechanic.codeRun ||
      StepMechanic.buildCircuit =>
        false,
    };

/// Stages that are the whole picture themselves, so the decorative slot above
/// them is not just redundant but crowds the thing being handled off screen.
/// The code editor and the circuit board both want the canvas.
bool stageOwnsCanvas(StepMechanic mechanic) =>
    mechanic == StepMechanic.codeRun || mechanic == StepMechanic.buildCircuit;

/// Stages whose instruction reads as a caption *under* the workspace, the way
/// a figure is captioned. Putting "Connect the battery, wire and bulb" above a
/// 300px board pushed the parts tray below the fold on a small phone.
bool stageCaptionsBelow(StepMechanic mechanic) =>
    mechanic == StepMechanic.buildCircuit;

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
/// [visual] is the step's declared visual (docs/26). A declared slot names the
/// art outright, which is how a step points at a file the naming convention
/// would never have found; without one this falls back to the convention.
Widget stepArt(LibraryItem item, int stepIndex, {Visual? visual}) {
  final fallback = itemArt(item) ?? const SizedBox.shrink();
  final path = visual is SlotVisual
      ? visual.assetPath
      : stepArtAsset(item, stepIndex);
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Image.asset(
      path,
      width: 180,
      height: 180,
      fit: BoxFit.cover,
      // Nothing is drawn for most steps yet, so a miss is the normal path.
      errorBuilder: (_, _, _) => fallback,
    ),
  );
}

/// The picture above a story page: the page's own illustration, then the
/// item's, then the emoji.
///
/// Story pages are the one surface where per-page art already exists for the
/// whole library, so unlike [stepArt] a miss here is the exception, not the
/// normal path.
Widget storyPageArt(LibraryItem item, LibPage page, String emoji) {
  // The page's declared visual is authoritative; `illustration` is the same
  // ref for every page authored so far, so this is a no-op today and the seam
  // a page needing a scene or token would come through.
  final visual = page.visual;
  final path = visual is SlotVisual ? visual.assetPath : pageArtAsset(page);
  final fallback = artOrEmoji(item, emoji);
  if (path == null) return fallback;
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Image.asset(
      path,
      width: 180,
      height: 180,
      fit: BoxFit.cover,
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
