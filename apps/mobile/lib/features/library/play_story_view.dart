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
    return Scaffold(
      appBar: playAppBar(context, loc.title),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // Scroll-safe: long page narrations at large text sizes must
              // never overflow on small screens.
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bundled art when available; emoji otherwise.
                      artOrEmoji(
                        widget.item,
                        illustrationFor(
                              widget.item.pages[_page].narration,
                            ) ??
                            '📖',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.pageNarration(_page),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // A bedtime story for a one-year-old is read *by* someone. The
            // note tells them how ("Dim your screen and read in a low voice").
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CoPlayTip(item: widget.item),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
}
