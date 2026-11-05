/// The storybook reader: pages, read-along narration, and a finish beat.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/stages/question_scaffold.dart';
import '../../l10n/gen/app_localizations.dart';
import 'content_lexicon.dart';
import 'library_models.dart';
import 'play_celebration.dart';
import 'play_shared.dart';
import 'press_scenes.dart';

class StoryView extends ConsumerStatefulWidget {
  const StoryView({super.key, required this.item});
  final LibraryItem item;
  @override
  ConsumerState<StoryView> createState() => StoryViewState();
}

class StoryViewState extends ConsumerState<StoryView> {
  int _page = 0;
  bool _done = false;

  /// Whether the child has answered *this* page's invitation to press.
  /// Cleared on every page turn: the next page asks again.
  bool _pressed = false;

  /// Index of the word pill most recently tapped by the child for phonics
  /// read-along replay. Cleared when turning the page.
  int? _tappedWordIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakPage());
  }

  /// Does this page's own narration promise the child a touch?
  bool get _invitesPress {
    final pages = widget.item.pages;
    if (_page < 0 || _page >= pages.length) return false;
    // The English narration decides, not the translated one: the promise is a
    // property of the page, and a page must not become inert in Swahili
    // because the verb was rendered differently there.
    return pageInvitesPress(pages[_page].narration);
  }

  /// What the stage says once it has answered. Named for the four drawn Cause
  /// & Effect scenes — "It grew!" is the effect the child just caused, and
  /// naming it is the whole point — and a shared cheer everywhere else, where
  /// the page keeps its own art and there is no specific effect to name.
  String _bannerText(AppLocalizations l10n, LibPage page) =>
      switch (pressSceneForAsset(page.illustration)) {
        PressScene.seedFlower => l10n.pressItGrew,
        PressScene.skySun => l10n.pressSunCameUp,
        PressScene.cloudRain => l10n.pressRainFalls,
        PressScene.star => l10n.pressItTwinkles,
        null => l10n.pressYouDidIt,
      };

  void _onPressed() {
    if (_pressed) {
      // Replays are welcome — a one-year-old confirms they caused something by
      // doing it again — but the cheer is not re-fired, so it stays a reward
      // for making it happen rather than a noise that follows every tap.
      ref.read(soundEffectsProvider).tap();
      return;
    }
    setState(() => _pressed = true);
    ref.read(soundEffectsProvider).celebrate();
  }

  Future<void> _speakPage() async {
    if (widget.item.pages.isEmpty) return;
    final lang = ref.read(localeProvider).languageCode;
    // Waited for, not sampled — see awaitLocalizedItem. This fires from a
    // post-frame callback, so on a cold start it is a frame ahead of the load.
    final loc = await awaitLocalizedItem(ref, widget.item);
    if (!mounted) return;
    unawaited(
      ref.read(narrationProvider.notifier).speak(
            loc.pageNarration(_page),
            lang,
            audioKey: '${widget.item.id}.pages.$_page.narration',
          ),
    );
  }

  void _go(int delta) {
    setState(() {
      _page += delta;
      _pressed = false;
      _tappedWordIndex = null;
    });
    ref.read(soundEffectsProvider).page();
    _speakPage();
  }

  void _speakSingleWord(int index, String rawWord) {
    final cleaned = rawWord.replaceAll(RegExp(r'''[^\p{L}\p{N}'-]''', unicode: true), '');
    final spoken = cleaned.isEmpty ? rawWord : cleaned;
    setState(() => _tappedWordIndex = index);
    ref.read(soundEffectsProvider).tap();
    final lang = ref.read(localeProvider).languageCode;
    unawaited(
      ref.read(narrationProvider.notifier).speak(spoken, lang),
    );
  }

  void _finish() {
    setState(() => _done = true);
    ref.read(soundEffectsProvider).celebrate();
    unawaited(
      ref.read(learningServiceProvider).completeLibraryStory(widget.item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = localizedItem(ref, widget.item);
    if (_done) {
      return Celebration(
        emoji: '📖✨',
        title: l10n.theEnd,
        xp: widget.item.xp,
        nextId: nextInSubject(ref, widget.item)?.id,
      );
    }
    final pages = widget.item.pages;
    final isLast = _page == pages.length - 1;
    final page = pages[_page];
    return Scaffold(
      appBar: playAppBar(context, loc.title),
      body: QuestionScaffold(
        stage: widget.item.stage,
        // §26.2: a story page is text-heavy, so the stage takes 180dp and the
        // narration gets the rest. The picture still has a fixed home, which
        // is what stops a two-line page and a six-line page laying out
        // differently.
        //
        // Except on a page whose picture *is* the activity. The four Cause &
        // Effect pages are pressed, not read — the narration is one short line
        // and the child's whole job is the flower — so those take the full
        // 300dp stage and the scene fills it. Pages that keep a 180dp bitmap
        // stay text-heavy; giving them 300 would only add white space.
        textHeavy: pressSceneForAsset(page.illustration) == null,
        progress: QuestionProgress(
          index: _page,
          total: pages.length,
          asCount: true,
        ),
        // This page's own drawn picture; the item's art, then an emoji, only
        // if the page names none. Where the page's text promises a touch, that
        // picture becomes the tap target and answers it.
        stageVisual: _invitesPress
            ? PressableStage(
                // Per page: the growth is State, and a page turn must start
                // its own scene from the seed rather than inherit the last
                // page's finished one.
                key: ValueKey('press-${widget.item.id}-$_page'),
                scene: pressSceneForAsset(page.illustration),
                semanticLabel: loc.pageNarration(_page),
                onPressed: _onPressed,
                child: storyPageArt(
                  widget.item,
                  page,
                  illustrationFor(page.narration) ?? '📖',
                ),
              )
            : storyPageArt(
                widget.item,
                page,
                illustrationFor(page.narration) ?? '📖',
              ),
        stageInteractive: _invitesPress,
        stageBanner: _invitesPress
            ? _PressBanner(shown: _pressed, text: _bannerText(l10n, page))
            : null,
        // Localized, so a French or Swahili reader is not read the English
        // brief before the page's own narration.
        stageSemanticLabel: loc.pageVisual(_page)?.alt,
        prompt: loc.pageNarration(_page),
        promptAudio: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StoryReadAlongBar(
              key: ValueKey('story-read-along-$_page'),
              narration: loc.pageNarration(_page),
              activeWordNotifier: ref.read(narrationProvider.notifier).activeWord,
              tappedWordIndex: _tappedWordIndex,
              onWordTap: _speakSingleWord,
            ),
            const SizedBox(height: 4),
            ReplayNarrationButton(onReplay: _speakPage),
          ],
        ),
        response: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              onPressed: _page == 0 ? null : () => _go(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_page + 1} / ${pages.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            FilledButton(
              onPressed: isLast ? _finish : () => _go(1),
              child: Text(isLast ? l10n.done : l10n.next),
            ),
          ],
        ),
        // A bedtime story for a one-year-old is read *by* someone. The note
        // tells them how ("Dim your screen and read in a low voice").
        assist: CoPlayTip(item: widget.item),
      ),
    );
  }
}

/// The line above the stage naming what the child just caused.
///
/// It holds its height from the start and only fades its text in. Inserting a
/// line on press would shove the picture down the screen at the exact moment
/// the child is looking at it — and on a page they can replay, it would jump
/// on every tap.
class _PressBanner extends StatelessWidget {
  const _PressBanner({required this.shown, required this.text});

  final bool shown;
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: Center(
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            child: Semantics(
              liveRegion: true,
              child: Text(
                shown ? text : '',
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.berry,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Interactive karaoke read-along word pills + tap-a-word phonics bar.
///
/// Highlights each word in a warm golden pill as [activeWordNotifier] advances
/// during spoken narration, and lets the child tap any individual word pill to
/// hear that single word pronounced aloud.
class StoryReadAlongBar extends StatelessWidget {
  const StoryReadAlongBar({
    super.key,
    required this.narration,
    required this.activeWordNotifier,
    required this.tappedWordIndex,
    required this.onWordTap,
  });

  final String narration;
  final ValueNotifier<NarrationWordSpan?> activeWordNotifier;
  final int? tappedWordIndex;
  final void Function(int index, String word) onWordTap;

  static List<({String word, int start, int end})> tokenize(String text) {
    final matches = RegExp(r'\S+').allMatches(text);
    return [
      for (final m in matches)
        (word: m.group(0)!, start: m.start, end: m.end),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = tokenize(narration);
    if (tokens.isEmpty) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: ValueListenableBuilder<NarrationWordSpan?>(
        valueListenable: activeWordNotifier,
        builder: (context, span, _) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              key: const ValueKey('story-read-along-bar'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tokens.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Builder(
                      builder: (context) {
                        final token = tokens[i];
                        final isSpokenNow = span != null &&
                            span.text == narration &&
                            span.start < token.end &&
                            span.end > token.start;
                        final isHighlighted =
                            isSpokenNow || tappedWordIndex == i;
                        return GestureDetector(
                          key: ValueKey('story-word-$i'),
                          onTap: () => onWordTap(i, token.word),
                          child: AnimatedScale(
                            scale: isHighlighted ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isHighlighted
                                    ? WatotoColors.sun.withValues(alpha: 0.42)
                                    : WatotoColors.sky.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isHighlighted
                                      ? WatotoColors.mango
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  text: token.word,
                                  style: TextStyle(
                                    fontFamily: 'Baloo2',
                                    fontSize: 13,
                                    fontWeight: isHighlighted
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: WatotoColors.deep,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
