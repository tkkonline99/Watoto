import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'story_models.dart';
import 'story_repository.dart';

class StoryReaderScreen extends ConsumerWidget {
  const StoryReaderScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyAsync = ref.watch(storyProvider(slug));
    return storyAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (story) => _Reader(story: story),
    );
  }
}

class _Reader extends ConsumerStatefulWidget {
  const _Reader({required this.story});
  final StoryBody story;

  @override
  ConsumerState<_Reader> createState() => _ReaderState();
}

class _ReaderState extends ConsumerState<_Reader> {
  int _page = 0;
  bool _finished = false;
  double _textScale = 1.0;
  int? _highlightWord; // tap-to-highlight read-along

  void _cycleTextSize() => setState(() {
        _textScale = _textScale >= 1.6 ? 1.0 : _textScale + 0.3;
      });

  void _next() {
    setState(() => _highlightWord = null);
    if (_page < widget.story.pages.length - 1) {
      setState(() => _page++);
    } else {
      setState(() => _finished = true);
      unawaited(ref.read(learningServiceProvider).completeStory(widget.story));
    }
  }

  void _prev() {
    if (_page > 0) {
      setState(() {
        _page--;
        _highlightWord = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;

    if (_finished) {
      return _TheEndView(
        xp: widget.story.xp,
        onReadAgain: () => setState(() {
          _finished = false;
          _page = 0;
          _highlightWord = null;
        }),
        onDone: () => context.go('/stories'),
      );
    }

    final page = widget.story.pages[_page];
    final words = page.words(lang);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
          onPressed: () => context.go('/stories'),
        ),
        title: Text(widget.story.localizedTitle(lang),
            style: const TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.deep)),
        actions: [
          IconButton(
            tooltip: l10n.textSize,
            icon: const Text('Aa',
                style: TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.deep)),
            onPressed: _cycleTextSize,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(page.emoji, style: const TextStyle(fontSize: 120)),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < words.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _highlightWord = i),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: _highlightWord == i
                                    ? WatotoColors.sun
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                words[i],
                                style: TextStyle(
                                  fontSize: 24 * _textScale,
                                  height: 1.6,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    onPressed: _page == 0 ? null : _prev,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${_page + 1} / ${widget.story.pages.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page == widget.story.pages.length - 1
                        ? l10n.done
                        : l10n.next),
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

class _TheEndView extends StatelessWidget {
  const _TheEndView({
    required this.xp,
    required this.onReadAgain,
    required this.onDone,
  });

  final int xp;
  final VoidCallback onReadAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📖✨', style: TextStyle(fontSize: 96)),
              const SizedBox(height: 16),
              Text(l10n.theEnd,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(l10n.xpEarned(xp),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: WatotoColors.mango)),
              const SizedBox(height: 40),
              Wrap(
                spacing: 16,
                children: [
                  FilledButton(onPressed: onReadAgain, child: Text(l10n.readAgain)),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: WatotoColors.deep),
                    onPressed: onDone,
                    child: Text(l10n.done),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
