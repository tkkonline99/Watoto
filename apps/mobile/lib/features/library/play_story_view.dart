/// The storybook reader: pages, read-along narration, and a finish beat.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/stages/question_scaffold.dart';
import '../../l10n/gen/app_localizations.dart';
import 'content_i18n.dart';
import 'content_lexicon.dart';
import 'library_models.dart';
import 'play_celebration.dart';
import 'play_shared.dart';

class StoryView extends ConsumerStatefulWidget {
  const StoryView({super.key, required this.item});
  final LibraryItem item;
  @override
  ConsumerState<StoryView> createState() => StoryViewState();
}

class StoryViewState extends ConsumerState<StoryView> {
  int _page = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakPage());
  }

  void _speakPage() {
    if (widget.item.pages.isEmpty) return;
    final lang = ref.read(localeProvider).languageCode;
    final loc = LocalizedItem(
      widget.item,
      ref.read(contentI18nProvider).asData?.value,
      lang,
    );
    ref.read(narrationProvider.notifier).speak(loc.pageNarration(_page), lang);
  }

  void _go(int delta) {
    setState(() => _page += delta);
    ref.read(soundEffectsProvider).page();
    _speakPage();
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
        textHeavy: true,
        progress: QuestionProgress(
          index: _page,
          total: pages.length,
          asCount: true,
        ),
        // This page's own drawn picture; the item's art, then an emoji, only
        // if the page names none.
        stageVisual: storyPageArt(
          widget.item,
          page,
          illustrationFor(page.narration) ?? '📖',
        ),
        stageSemanticLabel: page.visual?.alt,
        prompt: loc.pageNarration(_page),
        promptAudio: ReplayNarrationButton(onReplay: _speakPage),
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
