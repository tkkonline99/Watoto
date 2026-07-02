import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'content_i18n.dart';
import 'library_models.dart';
import 'library_repository.dart';

/// Plays a single library item by id, dispatching to the right player. Content
/// text is localized at runtime from the locale bundles (English fallback).
class LibraryPlayScreen extends ConsumerWidget {
  const LibraryPlayScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libAsync = ref.watch(libraryProvider);
    return libAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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

/// Builds the localized view of an item from the current locale.
LocalizedItem _localized(WidgetRef ref, LibraryItem item) {
  final lang = ref.watch(localeProvider).languageCode;
  final i18n = ref.watch(contentI18nProvider).asData?.value;
  return LocalizedItem(item, i18n, lang);
}

PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
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
  actions: const [_NarrationButton()],
);

/// Toggles spoken narration on/off; the icon reflects the current state.
class _NarrationButton extends ConsumerWidget {
  const _NarrationButton();

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
  bool _interacted = false; // the child completed this step's gesture
  bool _done = false;
  final _elapsed = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakStep());
  }

  /// Speaks the current step's narration (the caption), if narration is on.
  void _speakStep() {
    if (widget.item.steps.isEmpty) return;
    final lang = ref.read(localeProvider).languageCode;
    final loc = LocalizedItem(
      widget.item,
      ref.read(contentI18nProvider).asData?.value,
      lang,
    );
    ref.read(narrationProvider.notifier).speak(loc.stepNarration(_step), lang);
  }

  /// The child finished the step's interaction (tap / count / drag) — reveal
  /// the feedback and the Next button, with a success chime.
  void _onInteracted() {
    if (_interacted) return;
    setState(() => _interacted = true);
    ref.read(soundEffectsProvider).correct();
  }

  void _next() {
    final steps = widget.item.steps;
    if (_step < steps.length - 1) {
      setState(() {
        _step++;
        _interacted = false;
      });
      _speakStep();
    } else {
      _elapsed.stop();
      setState(() => _done = true);
      ref.read(soundEffectsProvider).celebrate();
      unawaited(
        ref
            .read(learningServiceProvider)
            .completeLibraryLesson(
              widget.item,
              timeSpentS: _elapsed.elapsed.inSeconds,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = _localized(ref, widget.item);
    if (_done) {
      return _Celebration(
        emoji: '🎉',
        title: l10n.greatJob,
        xp: widget.item.xp,
      );
    }
    final steps = widget.item.steps;
    if (steps.isEmpty) {
      // Defensive: content without steps still completes with a single tap.
      return Scaffold(
        appBar: _bar(context, loc.title),
        body: SafeArea(
          child: Center(
            child: FilledButton(onPressed: _next, child: Text(l10n.done)),
          ),
        ),
      );
    }
    final isLast = _step == steps.length - 1;
    final kind = playKind(widget.item.interaction);
    return Scaffold(
      appBar: _bar(context, loc.title),
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
                    // Narration is always shown (it doubles as the caption for
                    // the spoken line), in a live region so screen readers
                    // announce each new step.
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        loc.stepNarration(_step),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InteractionStage(
                      key: ValueKey(_step),
                      kind: kind,
                      emoji: stageEmoji(widget.item),
                      count: countForStep(widget.item, _step),
                      onCompleted: _onInteracted,
                      onTapSound: () => ref.read(soundEffectsProvider).tap(),
                    ),
                    if (_interacted) ...[
                      const SizedBox(height: 16),
                      Text(
                        loc.stepFeedback(_step),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          color: WatotoColors.leaf,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _interacted ? _next : null,
                  child: Text(isLast ? l10n.done : l10n.next),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------- interaction mechanics

/// The gesture family the player renders for a content [interaction] tag.
/// The content library declares ~30 fine-grained tags; they collapse to three
/// real mechanics that are age-appropriate and cover every item.
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

const _emojiRules = <(List<String>, String)>[
  (['animal', 'pet', 'farm', 'jungle', 'ocean'], '🐘'),
  (
    [
      'letter',
      'read',
      'word',
      'story',
      'writ',
      'literac',
      'vocab',
      'phon',
      'rhym',
    ],
    '🔤',
  ),
  (['color', 'colour', 'shape', 'art', 'draw', 'paint'], '🎨'),
  (['count', 'number', 'math', 'add', 'subtract', 'sort'], '🔢'),
  (['science', 'nature', 'plant', 'weather', 'water', 'sink', 'seed'], '🔬'),
  (['music', 'rhythm', 'sing', 'song'], '🎵'),
  (['body', 'feel', 'emotion', 'health', 'senses'], '❤️'),
  (['code', 'robot', 'tech', 'logic', 'digital'], '🤖'),
  (['map', 'world', 'social', 'community', 'globe'], '🌍'),
];

/// A friendly emoji for the stage, inferred from the item's subject/title.
String stageEmoji(LibraryItem item) {
  final s = '${item.subject} ${item.title}'.toLowerCase();
  for (final (keys, emoji) in _emojiRules) {
    if (keys.any(s.contains)) return emoji;
  }
  return '⭐';
}

/// How many objects a counting step shows. Steps don't carry a number, so pick
/// a small, stable count that varies a little across steps (2–4).
int countForStep(LibraryItem item, int step) => 2 + (step % 3);

/// Renders the right interactive element for [kind] and calls [onCompleted]
/// once the child has done the gesture.
class _InteractionStage extends StatelessWidget {
  const _InteractionStage({
    super.key,
    required this.kind,
    required this.emoji,
    required this.count,
    required this.onCompleted,
    required this.onTapSound,
  });

  final PlayKind kind;
  final String emoji;
  final int count;
  final VoidCallback onCompleted;
  final VoidCallback onTapSound;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      PlayKind.tap => _TapStage(emoji: emoji, onCompleted: onCompleted),
      PlayKind.count => _CountStage(
        emoji: '⭐',
        count: count,
        onCompleted: onCompleted,
        onTapSound: onTapSound,
      ),
      PlayKind.drag => _DragStage(emoji: emoji, onCompleted: onCompleted),
    };
  }
}

Widget _bigEmoji(String emoji) =>
    Text(emoji, style: const TextStyle(fontSize: 88));

/// Tap the big picture to make it pop — the dominant `tap` family.
class _TapStage extends StatefulWidget {
  const _TapStage({required this.emoji, required this.onCompleted});
  final String emoji;
  final VoidCallback onCompleted;
  @override
  State<_TapStage> createState() => _TapStageState();
}

class _TapStageState extends State<_TapStage> {
  bool _done = false;

  void _tap() {
    if (_done) return;
    setState(() => _done = true);
    HapticFeedback.lightImpact();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Semantics(
          button: true,
          label: l10n.tapToPlay,
          child: GestureDetector(
            onTap: _tap,
            child: AnimatedScale(
              scale: _done ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: _bigEmoji(widget.emoji),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!_done)
          Text(
            l10n.tapToPlay,
            style: const TextStyle(fontSize: 15, color: WatotoColors.sky),
          ),
      ],
    );
  }
}

/// Tap every object to count it — the `tap-to-count` / number family.
class _CountStage extends StatefulWidget {
  const _CountStage({
    required this.emoji,
    required this.count,
    required this.onCompleted,
    required this.onTapSound,
  });
  final String emoji;
  final int count;
  final VoidCallback onCompleted;
  final VoidCallback onTapSound;
  @override
  State<_CountStage> createState() => _CountStageState();
}

class _CountStageState extends State<_CountStage> {
  late final List<bool> _counted = List.filled(widget.count, false);
  int get _n => _counted.where((c) => c).length;

  void _tap(int i) {
    if (_counted[i]) return;
    setState(() => _counted[i] = true);
    HapticFeedback.lightImpact();
    if (_n == widget.count) {
      widget.onCompleted(); // completion chime handled by the parent
    } else {
      widget.onTapSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.tapEachPrompt,
          style: const TextStyle(fontSize: 15, color: WatotoColors.sky),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < widget.count; i++)
              Semantics(
                button: true,
                label: '${i + 1}',
                child: GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedScale(
                    scale: _counted[i] ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Badge(
                      isLabelVisible: _counted[i],
                      backgroundColor: WatotoColors.leaf,
                      label: Text(
                        '${_counted.take(i + 1).where((c) => c).length}',
                      ),
                      child: Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 56),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Drag the object into the basket — the `drag` / build / trace family. Also
/// completes on a tap so it stays reachable for screen-reader users.
class _DragStage extends StatefulWidget {
  const _DragStage({required this.emoji, required this.onCompleted});
  final String emoji;
  final VoidCallback onCompleted;
  @override
  State<_DragStage> createState() => _DragStageState();
}

class _DragStageState extends State<_DragStage> {
  bool _done = false;

  void _finish() {
    if (_done) return;
    setState(() => _done = true);
    HapticFeedback.mediumImpact();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.dragToBasket,
          style: const TextStyle(fontSize: 15, color: WatotoColors.sky),
        ),
        const SizedBox(height: 16),
        if (!_done)
          Semantics(
            button: true,
            label: l10n.dragToBasket,
            child: Draggable<int>(
              data: 1,
              feedback: _bigEmoji(widget.emoji),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _bigEmoji(widget.emoji),
              ),
              // Tap also completes, so the step is doable without a drag.
              child: GestureDetector(
                onTap: _finish,
                child: _bigEmoji(widget.emoji),
              ),
            ),
          ),
        const SizedBox(height: 24),
        DragTarget<int>(
          onAcceptWithDetails: (_) => _finish(),
          builder: (context, candidate, rejected) => Container(
            width: 120,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WatotoColors.sky.withValues(
                alpha: candidate.isNotEmpty ? 0.3 : 0.12,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _done ? '✅' : '🧺',
              style: const TextStyle(fontSize: 44),
            ),
          ),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakPrompt());
  }

  void _speakPrompt() {
    final lang = ref.read(localeProvider).languageCode;
    final loc = LocalizedItem(
      widget.item,
      ref.read(contentI18nProvider).asData?.value,
      lang,
    );
    ref.read(narrationProvider.notifier).speak(loc.questionPrompt(_q), lang);
  }

  void _pick(int index) {
    final question = widget.item.questions[_q];
    final loc = LocalizedItem(
      widget.item,
      ref.read(contentI18nProvider).asData?.value,
      ref.read(localeProvider).languageCode,
    );
    if (index == question.answer) {
      _answers.add({
        'questionId': '${widget.item.id}.q$_q',
        'selectedIndex': index,
      });
      if (!_wrongThisQ) _firstTryCorrect++;
      setState(() {
        _feedback = loc.questionCorrect(_q);
        _feedbackGood = true;
      });
      ref.read(soundEffectsProvider).correct();
      Timer(const Duration(milliseconds: 700), _next);
    } else {
      setState(() {
        _wrongThisQ = true;
        _feedback = loc.questionRetry(_q);
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
      _speakPrompt();
    } else {
      _elapsed.stop();
      final total = widget.item.questions.length;
      final scorePct = total == 0
          ? 0
          : ((_firstTryCorrect / total) * 100).round();
      final stars = scorePct >= 100 ? 3 : (scorePct >= 67 ? 2 : 1);
      setState(() {
        _done = true;
        _stars = stars;
      });
      ref.read(soundEffectsProvider).celebrate();
      unawaited(
        ref
            .read(learningServiceProvider)
            .completeLibraryQuiz(
              widget.item,
              scorePct: scorePct,
              passed: true,
              answers: _answers,
              durationS: _elapsed.elapsed.inSeconds,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = _localized(ref, widget.item);
    if (_done) {
      return _Celebration(
        emoji: '🎉',
        title: l10n.greatJob,
        xp: widget.item.xp,
        stars: _stars,
      );
    }
    final question = widget.item.questions[_q];
    return Scaffold(
      appBar: _bar(context, loc.title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _ProgressDots(count: widget.item.questions.length, active: _q),
              const SizedBox(height: 12),
              Text(
                loc.questionPrompt(_q),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
                            child: Text(loc.optionLabel(_q, i)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_feedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _feedbackGood
                          ? WatotoColors.leaf
                          : WatotoColors.berry,
                    ),
                  ),
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
    final loc = _localized(ref, widget.item);
    if (_done) {
      return _Celebration(emoji: '📖✨', title: l10n.theEnd, xp: widget.item.xp);
    }
    final pages = widget.item.pages;
    final isLast = _page == pages.length - 1;
    return Scaffold(
      appBar: _bar(context, loc.title),
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
  const _Celebration({
    required this.emoji,
    required this.title,
    required this.xp,
    this.stars = 0,
  });
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (stars > 0) ...[
                const SizedBox(height: 8),
                Text('⭐' * stars, style: const TextStyle(fontSize: 36)),
              ],
              const SizedBox(height: 8),
              Text(
                l10n.xpEarned(xp),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: WatotoColors.mango,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => context.go('/'),
                child: Text(l10n.done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
