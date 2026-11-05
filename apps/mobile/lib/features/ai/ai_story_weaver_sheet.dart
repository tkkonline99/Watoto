import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/watoto_ai_engine.dart';
import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../library/play_story_view.dart';

/// Interactive "Kibo's AI Story Weaver" modal sheet: kids pick a Hero, Place,
/// and Learning Theme to co-create a 3-page trilingual story (`EN`/`SW`/`FR`)
/// with live Karaoke Read-Along word highlighting and a comprehension check.
class AiStoryWeaverSheet extends ConsumerStatefulWidget {
  const AiStoryWeaverSheet({super.key});

  @override
  ConsumerState<AiStoryWeaverSheet> createState() => _AiStoryWeaverSheetState();
}

class _AiStoryWeaverSheetState extends ConsumerState<AiStoryWeaverSheet> {
  StoryHero _hero = StoryHero.lion;
  StoryPlace _place = StoryPlace.baobab;
  StoryTheme _theme = StoryTheme.sharing;

  WovenStory? _story;
  int _pageIndex = 0;
  int? _tappedWordIndex;
  bool _inQuestion = false;
  bool _completed = false;
  int? _selectedOption;

  void _weaveStory() {
    unawaited(HapticFeedback.mediumImpact());
    final locale = ref.read(localeProvider).languageCode;
    final story = ref.read(watotoAiEngineProvider).weaveCustomStory(
          hero: _hero,
          place: _place,
          theme: _theme,
          locale: locale,
        );
    setState(() {
      _story = story;
      _pageIndex = 0;
      _tappedWordIndex = null;
      _inQuestion = false;
      _completed = false;
      _selectedOption = null;
    });
    _speakCurrentPage(story, 0);
  }

  void _speakCurrentPage(WovenStory story, int pageIdx) {
    final bedtime = ref.read(bedtimeModeProvider);
    unawaited(
      ref.read(narrationProvider.notifier).speak(
            story.pages[pageIdx],
            story.locale,
            style: bedtime ? SpeakStyle.gentle : SpeakStyle.lesson,
          ),
    );
  }

  void _speakWord(int idx, String word) {
    final story = _story;
    if (story == null) return;
    setState(() => _tappedWordIndex = idx);
    ref.read(soundEffectsProvider).tap();
    unawaited(ref.read(narrationProvider.notifier).speak(word, story.locale));
  }

  void _nextPage() {
    final story = _story;
    if (story == null) return;
    if (_pageIndex < story.pages.length - 1) {
      final next = _pageIndex + 1;
      setState(() {
        _pageIndex = next;
        _tappedWordIndex = null;
      });
      ref.read(soundEffectsProvider).page();
      _speakCurrentPage(story, next);
    } else {
      setState(() => _inQuestion = true);
      unawaited(
        ref.read(narrationProvider.notifier).speak(
              story.questionPrompt,
              story.locale,
              style: SpeakStyle.lesson,
            ),
      );
    }
  }

  Future<void> _answerQuestion(int optionIndex) async {
    final story = _story;
    if (story == null) return;
    setState(() => _selectedOption = optionIndex);
    if (optionIndex == story.correctIndex) {
      unawaited(ref.read(soundEffectsProvider).celebrate());
      final child = ref.read(activeChildProvider);
      if (child != null) {
        await ref.read(offlineStoreProvider).grantCoins(child.id, 5);
        ref.read(economyTickProvider.notifier).state++;
      }
      if (!mounted) return;
      setState(() => _completed = true);
    } else {
      unawaited(ref.read(soundEffectsProvider).retry());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final header = switch (locale) {
      'sw' => '📖✨ Mtunzi wa Hadithi wa Kibo (AI)',
      'fr' => '📖✨ Tisseur d’Histoires de Kibo (IA)',
      _ => '📖✨ Kibo’s AI Story Weaver',
    };

    final story = _story;

    return SafeArea(
      child: Padding(
        key: const ValueKey('ai-story-weaver-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    header,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                ),
                if (story != null)
                  TextButton(
                    key: const ValueKey('story-weaver-reset'),
                    onPressed: () => setState(() => _story = null),
                    child: const Text('New Story ↻'),
                  ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (story == null) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final h in StoryHero.values)
                    ChoiceChip(
                      key: ValueKey('story-hero-${h.id}'),
                      avatar: Text(h.emoji),
                      label: Text(h.labelFor(locale)),
                      selected: _hero == h,
                      onSelected: (_) => setState(() => _hero = h),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in StoryPlace.values)
                    ChoiceChip(
                      key: ValueKey('story-place-${p.id}'),
                      avatar: Text(p.emoji),
                      label: Text(p.labelFor(locale)),
                      selected: _place == p,
                      onSelected: (_) => setState(() => _place = p),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in StoryTheme.values)
                    ChoiceChip(
                      key: ValueKey('story-theme-${t.id}'),
                      avatar: Text(t.emoji),
                      label: Text(t.labelFor(locale)),
                      selected: _theme == t,
                      onSelected: (_) => setState(() => _theme = t),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('weave-story-button'),
                onPressed: _weaveStory,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  switch (locale) {
                    'sw' => 'Tunga Hadithi Yangu! ✨',
                    'fr' => 'Tisse Mon Histoire ! ✨',
                    _ => 'Weave My Story! ✨',
                  },
                ),
              ),
            ] else if (_completed) ...[
              Container(
                key: const ValueKey('woven-story-celebration'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '${story.hero.emoji} 🎉 ${story.place.emoji}',
                      style: const TextStyle(fontSize: 34),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      switch (locale) {
                        'sw' => 'Hongera! Umepata Sarafu +5! 🪙',
                        'fr' => 'Bravo ! Tu as gagné +5 Pièces ! 🪙',
                        _ => 'Wonderful Reading! +5 Bonus Coins! 🪙',
                      },
                      style: const TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: WatotoColors.deep,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_inQuestion) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      story.questionPrompt,
                      key: const ValueKey('woven-story-question'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: WatotoColors.deep,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0; i < story.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          key: ValueKey('woven-story-option-$i'),
                          onPressed: () => _answerQuestion(i),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedOption == i
                                ? WatotoColors.berry.withValues(alpha: 0.12)
                                : Colors.white,
                          ),
                          child: Text(story.options[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: WatotoColors.sun.withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${story.title} (${_pageIndex + 1}/${story.pages.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: WatotoColors.mango,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story.pages[_pageIndex],
                      key: const ValueKey('woven-story-page-text'),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: WatotoColors.deep,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StoryReadAlongBar(
                      narration: story.pages[_pageIndex],
                      activeWordNotifier:
                          ref.read(narrationProvider.notifier).activeWord,
                      tappedWordIndex: _tappedWordIndex,
                      onWordTap: _speakWord,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('woven-story-next-page'),
                onPressed: _nextPage,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _pageIndex < story.pages.length - 1 ? 'Next Page' : 'Quiz Time!',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showAiStoryWeaver(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WatotoColors.cloud,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const AiStoryWeaverSheet(),
  );
}
