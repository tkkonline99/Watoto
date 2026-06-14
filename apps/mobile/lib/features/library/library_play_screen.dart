import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'library_models.dart';
import 'library_repository.dart';

/// Plays a single library item by id, dispatching to the right player. Content
/// text is English (as authored in the library); UI chrome is localized.
class LibraryPlayScreen extends ConsumerWidget {
  const LibraryPlayScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libAsync = ref.watch(libraryProvider);
    return libAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (repo) {
        final item = repo.byId[id];
        if (item == null) {
          return Scaffold(body: Center(child: Text('Not found: $id')));
        }
        return switch (item.type) {
          LibraryType.lesson => _LessonView(item: item),
          LibraryType.quiz => _QuizView(item: item),
          LibraryType.story => _StoryView(item: item),
        };
      },
    );
  }
}

PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
        onPressed: () => context.pop(),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.deep)),
    );

Widget _placeholder(String emoji) => Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: WatotoColors.sky.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 72)),
    );

// ----------------------------------------------------------------- lesson

class _LessonView extends ConsumerStatefulWidget {
  const _LessonView({required this.item});
  final LibraryItem item;
  @override
  ConsumerState<_LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends ConsumerState<_LessonView> {
  int _step = 0;
  bool _showFeedback = false;
  bool _done = false;
  final _elapsed = Stopwatch()..start();

  void _advance() {
    final steps = widget.item.steps;
    if (!_showFeedback) {
      setState(() => _showFeedback = true);
      return;
    }
    if (_step < steps.length - 1) {
      setState(() {
        _step++;
        _showFeedback = false;
      });
    } else {
      _elapsed.stop();
      setState(() => _done = true);
      unawaited(ref
          .read(learningServiceProvider)
          .completeLibraryLesson(widget.item, timeSpentS: _elapsed.elapsed.inSeconds));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_done) {
      return _Celebration(emoji: '🎉', title: l10n.greatJob, xp: widget.item.xp);
    }
    final steps = widget.item.steps;
    final step = steps[_step];
    final isLast = _step == steps.length - 1;
    return Scaffold(
      appBar: _bar(context, widget.item.title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _ProgressDots(count: steps.length, active: _step),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _placeholder('✨'),
                    const SizedBox(height: 24),
                    Text(step.narration,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    if (_showFeedback) ...[
                      const SizedBox(height: 16),
                      Text(step.feedback,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 17, color: WatotoColors.leaf)),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _advance,
                  child: Text(!_showFeedback
                      ? l10n.startLearning
                      : (isLast ? l10n.done : l10n.next)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- quiz

class _QuizView extends ConsumerStatefulWidget {
  const _QuizView({required this.item});
  final LibraryItem item;
  @override
  ConsumerState<_QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends ConsumerState<_QuizView> {
  int _q = 0;
  bool _wrongThisQ = false;
  int _firstTryCorrect = 0;
  String? _feedback;
  bool _feedbackGood = false;
  bool _done = false;
  int _stars = 0;
  final _answers = <Map<String, dynamic>>[];
  final _elapsed = Stopwatch()..start();

  void _pick(int index) {
    final question = widget.item.questions[_q];
    if (index == question.answer) {
      _answers.add({'questionId': '${widget.item.id}.q$_q', 'selectedIndex': index});
      if (!_wrongThisQ) _firstTryCorrect++;
      setState(() {
        _feedback = question.correctFeedback;
        _feedbackGood = true;
      });
      Timer(const Duration(milliseconds: 700), _next);
    } else {
      setState(() {
        _wrongThisQ = true;
        _feedback = question.retryFeedback;
        _feedbackGood = false;
      });
    }
  }

  void _next() {
    if (!mounted) return;
    if (_q < widget.item.questions.length - 1) {
      setState(() {
        _q++;
        _wrongThisQ = false;
        _feedback = null;
      });
    } else {
      _elapsed.stop();
      final total = widget.item.questions.length;
      final scorePct = total == 0 ? 0 : ((_firstTryCorrect / total) * 100).round();
      final stars = scorePct >= 100 ? 3 : (scorePct >= 67 ? 2 : 1);
      setState(() {
        _done = true;
        _stars = stars;
      });
      unawaited(ref.read(learningServiceProvider).completeLibraryQuiz(
            widget.item,
            scorePct: scorePct,
            passed: true,
            answers: _answers,
            durationS: _elapsed.elapsed.inSeconds,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_done) {
      return _Celebration(emoji: '🎉', title: l10n.greatJob, xp: widget.item.xp, stars: _stars);
    }
    final question = widget.item.questions[_q];
    return Scaffold(
      appBar: _bar(context, widget.item.title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _ProgressDots(count: widget.item.questions.length, active: _q),
              const SizedBox(height: 12),
              Text(question.prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < question.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: WatotoColors.sky,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: () => _pick(i),
                            child: Text(question.options[i].label),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_feedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_feedback!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _feedbackGood ? WatotoColors.leaf : WatotoColors.berry)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ story

class _StoryView extends ConsumerStatefulWidget {
  const _StoryView({required this.item});
  final LibraryItem item;
  @override
  ConsumerState<_StoryView> createState() => _StoryViewState();
}

class _StoryViewState extends ConsumerState<_StoryView> {
  int _page = 0;
  bool _done = false;

  void _finish() {
    setState(() => _done = true);
    unawaited(ref.read(learningServiceProvider).completeLibraryStory(widget.item));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_done) {
      return _Celebration(emoji: '📖✨', title: l10n.theEnd, xp: widget.item.xp);
    }
    final pages = widget.item.pages;
    final page = pages[_page];
    final isLast = _page == pages.length - 1;
    return Scaffold(
      appBar: _bar(context, widget.item.title),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _placeholder('📖'),
                    const SizedBox(height: 24),
                    Text(page.narration,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, height: 1.5, fontWeight: FontWeight.w600)),
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
                    onPressed: _page == 0 ? null : () => setState(() => _page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${_page + 1} / ${pages.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  FilledButton(
                    onPressed: isLast ? _finish : () => setState(() => _page++),
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

// ------------------------------------------------------------- shared bits

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.active});
  final int count;
  final int active;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= active ? WatotoColors.mango : Colors.black12,
            ),
          ),
      ],
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.emoji, required this.title, required this.xp, this.stars = 0});
  final String emoji;
  final String title;
  final int xp;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 96)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              if (stars > 0) ...[
                const SizedBox(height: 8),
                Text('⭐' * stars, style: const TextStyle(fontSize: 36)),
              ],
              const SizedBox(height: 8),
              Text(l10n.xpEarned(xp),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: WatotoColors.mango)),
              const SizedBox(height: 40),
              FilledButton(onPressed: () => context.go('/'), child: Text(l10n.done)),
            ],
          ),
        ),
      ),
    );
  }
}
