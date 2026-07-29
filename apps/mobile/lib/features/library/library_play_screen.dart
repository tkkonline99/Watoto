import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/mascot_widget.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/entitlements.dart';
import '../gamification/achievements_sheet.dart' show badgeLabel;
import '../gamification/reward_outcome.dart';
import '../gamification/rewards.dart' as rewards;
import 'content_art.dart';
import 'content_i18n.dart';
import 'content_lexicon.dart';
import 'library_models.dart';
import 'lesson_recap.dart';
import 'library_repository.dart';
import 'quiz_review.dart';
import 'step_play.dart';
import 'step_visuals.dart';
import '../../router/return_to.dart';

/// Plays a single library item by id, dispatching to the right player. Content
/// text is localized at runtime from the locale bundles (English fallback).
class LibraryPlayScreen extends ConsumerWidget {
  const LibraryPlayScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libAsync = ref.watch(libraryProvider);
    final entitlement = ref.watch(entitlementProvider);
    final l10n = AppLocalizations.of(context);
    return libAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (repo) {
        final item = repo.byId[id];
        if (item == null) {
          return Scaffold(body: Center(child: Text('Not found: $id')));
        }
        if (!isContentUnlocked(
          item.stage,
          entitlement,
          freeMax: ref.watch(freeStageMaxProvider),
        )) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      l10n.premiumLocked,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.premiumAskGrownUp, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      // Straight to the unlock surface, carrying this activity
                      // so the family lands back on it once it is unlocked.
                      onPressed: () => context.go(
                        gateWithReturn('/paywall', '/play/${item.id}'),
                      ),
                      child: Text(l10n.parentZone),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // Keyed by item id: "Keep going!" replaces /play/:id with another
        // /play/:id, which is the *same* route. Without a key Flutter reuses
        // the previous view's State, so the child would land on the finished
        // lesson's celebration instead of the new activity.
        final key = ValueKey('play-${item.id}');
        return switch (item.type) {
          LibraryType.lesson => _LessonView(key: key, item: item),
          LibraryType.quiz => _QuizView(key: key, item: item),
          LibraryType.story => _StoryView(key: key, item: item),
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

/// Stages that print the step's prompt themselves, right beside the thing the
/// child touches. The caption-level hint is suppressed for these so the same
/// instruction is never shown twice on one screen.
bool _stageShowsPrompt(StepMechanic mechanic) => switch (mechanic) {
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
bool _stageShowsEmoji(StepMechanic mechanic) => switch (mechanic) {
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

/// Prefer a bundled illustration; fall back to emoji placeholder.
Widget _artOrEmoji(LibraryItem item, String emoji) =>
    _art(item) ?? _placeholder(emoji);

/// The item's illustration, or null when nothing is bundled for it. Used above
/// stages that already show the emoji, where a placeholder would just be the
/// same picture twice — one dead, one alive.
Widget? _artOnly(LibraryItem item) => _art(item);

Widget? _art(LibraryItem item) {
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

// ----------------------------------------------------------------- lesson

class _LessonView extends ConsumerStatefulWidget {
  const _LessonView({super.key, required this.item});
  final LibraryItem item;
  @override
  ConsumerState<_LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends ConsumerState<_LessonView> {
  int _step = 0;
  bool _interacted = false; // the child completed this step's gesture
  bool _done = false;
  int _combo = 0; // consecutive correct steps — dopamine loop
  int _mistakes = 0; // wrong picks across the run — rates the finish
  int? _shownAnswer; // digit they just got right (for workspace)

  /// The end-of-lesson recap, built from this lesson's own content. Empty for
  /// pre-reader lessons, for lessons that teach no crisp checkable fact, and —
  /// outside English — for lessons whose recap is derived rather than authored.
  late final List<RecapQuestion> _recap = buildLessonRecap(
    widget.item,
    lang: ref.read(localeProvider).languageCode,
  );

  /// True while the recap is on screen (after the last step, before the
  /// celebration).
  bool _inRecap = false;

  /// Recap questions answered wrong on the first attempt.
  int _recapWrong = 0;

  /// Steps that present a real choice, so a wrong answer is even possible.
  ///
  /// Rating a run only makes sense against these: a lesson made entirely of
  /// "tap the picture" steps cannot be got wrong, and calling every such run
  /// "Perfect!" would drain the word of meaning within a day.
  late final int _gradeableSteps = _countGradeableSteps();

  int _countGradeableSteps() {
    var count = 0;
    for (var i = 0; i < widget.item.steps.length; i++) {
      final step = widget.item.steps[i];
      final plan = planStep(item: widget.item, stepIndex: i, step: step);
      final gradeable = switch (plan.mechanic) {
        StepMechanic.tap =>
          (choicePlanFor(widget.item.id, i, step.narration)?.options.length ??
                  0) >
              1,
        StepMechanic.multiChoice => plan.choices.length > 1,
        _ => false,
      };
      if (gradeable) count++;
    }
    return count;
  }
  final _elapsed = Stopwatch()..start();
  Timer? _autoAdvance; // pending "move on a beat after the interaction"

  /// Held directly rather than read through `ref` in [dispose], where the
  /// element is already torn down and `ref.read` throws.
  late final AnalyticsService _analytics;

  @override
  void initState() {
    super.initState();
    _analytics = ref.read(analyticsProvider);
    _analytics.log(AnalyticsEvents.activityStart, {
      'stage': widget.item.stage,
      'type': widget.item.type.name,
      'steps': widget.item.steps.length,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakStep());
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    // Leaving before the celebration is the drop-off signal: which step and
    // how far in tells us where activities lose children.
    if (!_done) {
      _analytics.log(AnalyticsEvents.activityAbandon, {
        'stage': widget.item.stage,
        'type': widget.item.type.name,
        'atStep': _step,
        'ofSteps': widget.item.steps.length,
        'secondsIn': _elapsed.elapsed.inSeconds,
      });
    }
    super.dispose();
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
    ref.read(narrationProvider.notifier).speak(
          loc.stepNarration(_step),
          lang,
          style: SpeakStyle.lesson,
        );
  }

  /// The child finished the step's interaction — reveal feedback, SFX, combo.
  void _onInteracted({int? answer}) {
    if (_interacted) return;
    setState(() {
      _interacted = true;
      _combo++;
      _shownAnswer = answer;
    });
    ref.read(soundEffectsProvider).correct();
    final lang = ref.read(localeProvider).languageCode;
    final loc = LocalizedItem(
      widget.item,
      ref.read(contentI18nProvider).asData?.value,
      lang,
    );
    unawaited(
      ref.read(narrationProvider.notifier).speak(
            loc.stepFeedback(_step),
            lang,
            style: SpeakStyle.cheer,
          ),
    );
    // Auto-advance after a beat so the loop stays snappy. User can still tap
    // Next/Done immediately — button is enabled as soon as [_interacted] is true.
    // Held in a field so a manual Next cancels it: a stale timer would other-
    // wise fire on the *following* step and skip (or complete) it early.
    _autoAdvance?.cancel();
    _autoAdvance = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || !_interacted) return;
      // Only auto-advance if we're still on the same completed step.
      _next();
    });
  }

  void _next() {
    if (_done) return;
    _autoAdvance?.cancel();
    final steps = widget.item.steps;
    if (_step < steps.length - 1) {
      setState(() {
        _step++;
        _interacted = false;
        _shownAnswer = null;
      });
      _speakStep();
    } else if (_recap.isNotEmpty && !_inRecap) {
      // One more beat before the confetti: ask the child to retrieve what they
      // just saw. Retrieval is what makes it stick, and it is the only honest
      // read on whether the lesson landed.
      setState(() => _inRecap = true);
    } else {
      _finishLesson();
    }
  }

  /// Banks the completion once the lesson (and its recap, if any) is done.
  void _finishLesson() {
    _elapsed.stop();
    setState(() {
      _inRecap = false;
      _done = true;
    });
    ref.read(soundEffectsProvider).celebrate();
    // Rate the run from what actually happened. Reporting a flat 100% for
    // every lesson (as this used to) left the adaptive engine blind. Runs
    // with nothing gradeable in them are still completions, just unrated.
    // Recap questions count as gradeable work: they are the part that
    // actually measures learning rather than tapping.
    final graded = _gradeableSteps + _recap.length;
    final mistakes = _mistakes + _recapWrong;
    unawaited(
      ref.read(learningServiceProvider).completeLibraryLesson(
            widget.item,
            timeSpentS: _elapsed.elapsed.inSeconds,
            scorePct: scorePctForLessonRun(
              steps: graded,
              mistakes: mistakes,
            ),
            mistakes: mistakes,
            graded: graded > 0,
            stars: graded == 0
                ? 0
                : starsForLessonRun(steps: graded, mistakes: mistakes),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = _localized(ref, widget.item);
    if (_inRecap) {
      return _LessonRecapView(
        title: loc.title,
        localized: loc,
        questions: _recap,
        onWrong: () => _recapWrong++,
        onFinished: _finishLesson,
      );
    }
    if (_done) {
      return _Celebration(
        emoji: '🎉',
        title: l10n.greatJob,
        xp: widget.item.xp,
        nextId: _nextInSubject(ref, widget.item)?.id,
      );
    }
    final steps = widget.item.steps;
    if (steps.isEmpty) {
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
    final step = steps[_step];
    final plan = planStep(
      item: widget.item,
      stepIndex: _step,
      step: step,
    );
    // Lexicon multi-choice still wins for "Tap the ball…" when plan is plain tap.
    final narrationEn = step.narration;
    final choice = switch (plan.mechanic) {
      // "Tap the ball" → the lexicon stages the ball among look-alikes.
      StepMechanic.tap => choicePlanFor(widget.item.id, _step, narrationEn),
      // A comprehension check ("Partial products = ?") is a choice too: the
      // child picks, and is told right or wrong. Options come from the
      // localized content, not the English baked into the plan — the order is
      // fixed by the content file, so plan.choiceIndex still points at the
      // right answer in every language.
      StepMechanic.multiChoice when plan.choices.length > 1 => ChoicePlan(
          [for (final c in loc.stepChoices(_step)) ChoiceOption(c, c)],
          plan.choiceIndex,
        ),
      _ => null,
    };
    // Authored questions are translated by key; prompts the planner derives
    // from English narration stay English-only for now and are suppressed in
    // other languages, where the localized caption already carries the ask.
    final stepPrompt = widget.item.steps[_step].prompt != null
        ? loc.stepPrompt(_step)
        : (loc.lang == 'en' ? plan.promptHint : null);
    final emoji = stepIllustration(item: widget.item, narration: narrationEn);
    return Scaffold(
      appBar: _bar(context, loc.title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ProgressDots(
                      count: steps.length,
                      active: _step,
                    ),
                  ),
                  if (_combo > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: WatotoColors.mango.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🔥 ×$_combo',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: WatotoColors.mango,
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        if (stepPrompt != null &&
                            !_interacted &&
                            !_stageShowsPrompt(plan.mechanic)) ...[
                          const SizedBox(height: 6),
                          Text(
                            stepPrompt,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: WatotoColors.deep.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (plan.workspace != null)
                          _DivisionWorkspace(
                            workspace: plan.workspace!,
                            filledDigit: _shownAnswer ??
                                (_interacted ? plan.answer : null),
                          )
                        // No illustration above a staged choice: the art *is*
                        // the answer, so showing it next to the options gives
                        // the question away. Stages that already render the
                        // step's emoji as their tap target skip it too — the
                        // child was seeing the same picture twice, once dead
                        // and once alive.
                        else if (plan.mechanic != StepMechanic.codeRun &&
                            choice == null)
                          ExcludeSemantics(
                            // Emoji-showing stages get the bundled artwork or
                            // nothing; other stages still get the emoji, since
                            // there it is the only picture on screen.
                            child: _stageShowsEmoji(plan.mechanic)
                                ? (_artOnly(widget.item) ??
                                    const SizedBox.shrink())
                                : _artOrEmoji(widget.item, emoji),
                          ),
                        const SizedBox(height: 16),
                        _SmartInteractionStage(
                          key: ValueKey('step-$_step'),
                          plan: plan,
                          prompt: stepPrompt,
                          emoji: emoji,
                          choice: choice,
                          done: _interacted,
                          onCompleted: _onInteracted,
                          onTapSound: () =>
                              ref.read(soundEffectsProvider).tap(),
                          onWrong: () {
                            setState(() {
                              _combo = 0;
                              _mistakes++;
                            });
                            // A distinct, gentle "not that one" — the plain
                            // tap sound gave a wrong pick no feedback at all.
                            ref.read(soundEffectsProvider).retry();
                          },
                        ),
                        if (_interacted) ...[
                          const SizedBox(height: 16),
                          Text(
                            loc.stepFeedback(_step),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: WatotoColors.leaf,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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

/// Long-division style workspace — digits the child enters appear *above*
/// the dividend so "write it above the 8" is real, not empty advice.
class _DivisionWorkspace extends StatelessWidget {
  const _DivisionWorkspace({
    required this.workspace,
    this.filledDigit,
  });

  final MathWorkspace workspace;
  final int? filledDigit;

  @override
  Widget build(BuildContext context) {
    final divStr = '${workspace.dividend}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WatotoColors.deep.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quotient line
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 36),
              ...List.generate(divStr.length, (i) {
                final show = filledDigit != null && i == 0;
                return Container(
                  width: 28,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: WatotoColors.deep.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    show ? '$filledDigit' : '',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: WatotoColors.mango,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${workspace.divisor}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: WatotoColors.deep, width: 3),
                    top: BorderSide(color: WatotoColors.deep, width: 3),
                  ),
                ),
                child: Text(
                  divStr,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: WatotoColors.deep,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Routes a [StepPlayPlan] to the matching fun mechanic.
class _SmartInteractionStage extends StatelessWidget {
  const _SmartInteractionStage({
    super.key,
    this.prompt,
    required this.plan,
    required this.emoji,
    required this.onCompleted,
    required this.onTapSound,
    required this.onWrong,
    required this.done,
    this.choice,
  });

  final StepPlayPlan plan;

  /// The localized instruction for this step, already resolved by the view.
  /// The plan's own hint is English — using it here would put an English line
  /// under a Swahili caption.
  final String? prompt;
  final String emoji;
  final void Function({int? answer}) onCompleted;
  final VoidCallback onTapSound;
  final VoidCallback onWrong;
  final bool done;
  final ChoicePlan? choice;

  @override
  Widget build(BuildContext context) {
    if (choice != null) {
      return _ChoiceStage(
        plan: choice!,
        onCompleted: () => onCompleted(),
      );
    }
    return switch (plan.mechanic) {
      StepMechanic.numberAnswer => _NumberAnswerStage(
          plan: plan,
          done: done,
          onCorrect: (n) => onCompleted(answer: n),
          onWrong: onWrong,
        ),
      StepMechanic.buildArray => _ArrayBuildStage(
          rows: plan.rows,
          cols: plan.cols,
          onCompleted: () => onCompleted(answer: plan.answer),
        ),
      StepMechanic.codeRun => _KidCodeStage(
          plan: plan,
          onCompleted: () => onCompleted(),
          onTapSound: onTapSound,
        ),
      StepMechanic.explain => _ExplainStage(
          emoji: emoji,
          prompt: prompt,
          onCompleted: () => onCompleted(),
        ),
      StepMechanic.celebrate => _TapStage(
          emoji: emoji,
          prompt: prompt,
          onCompleted: () => onCompleted(),
        ),
      StepMechanic.count => _CountStage(
          emoji: emoji,
          prompt: prompt,
          count: plan.count,
          onCompleted: () => onCompleted(),
          onTapSound: onTapSound,
        ),
      StepMechanic.drag => _DragStage(
          emoji: emoji,
          prompt: prompt,
          onCompleted: () => onCompleted(),
        ),
      StepMechanic.tap || StepMechanic.multiChoice => _TapStage(
          emoji: emoji,
          prompt: prompt,
          onCompleted: () => onCompleted(),
        ),
    };
  }
}

/// Big digit buttons or a mini pad — never a dead "write it" prompt.
class _NumberAnswerStage extends StatefulWidget {
  const _NumberAnswerStage({
    required this.plan,
    required this.onCorrect,
    required this.onWrong,
    required this.done,
  });

  final StepPlayPlan plan;
  final void Function(int answer) onCorrect;
  final VoidCallback onWrong;
  final bool done;

  @override
  State<_NumberAnswerStage> createState() => _NumberAnswerStageState();
}

class _NumberAnswerStageState extends State<_NumberAnswerStage> {
  String _buf = '';
  int? _wrongFlash;

  void _pickDigit(int d) {
    if (widget.done) return;
    final answer = widget.plan.answer;
    if (answer == null) return;

    // Choice mode (big buttons with pre-made options).
    if (widget.plan.choices.isNotEmpty) {
      if (d == answer) {
        HapticFeedback.lightImpact();
        widget.onCorrect(d);
      } else {
        setState(() => _wrongFlash = d);
        HapticFeedback.heavyImpact();
        widget.onWrong();
        Timer(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _wrongFlash = null);
        });
      }
      return;
    }

    // Pad mode — build multi-digit then check.
    final next = _buf.length < 3 ? '$_buf$d' : _buf;
    setState(() => _buf = next);
    final typed = int.tryParse(_buf);
    if (typed == null) return;
    final target = '$answer';
    if (typed == answer) {
      HapticFeedback.lightImpact();
      widget.onCorrect(typed);
      return;
    }
    // Not a prefix of the answer, or already as long as the answer → reset.
    // (Avoids the stuck "typed 1, answer is 21" dead-end.)
    final isPrefix = target.startsWith(_buf);
    if (!isPrefix || _buf.length >= target.length) {
      HapticFeedback.heavyImpact();
      widget.onWrong();
      Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _buf = '');
      });
    }
  }

  void _backspace() {
    if (widget.done || _buf.isEmpty) return;
    setState(() => _buf = _buf.substring(0, _buf.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.plan.answer ?? 0;
    final useChoices = widget.plan.choices.isNotEmpty;

    if (useChoices) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final c in widget.plan.choices)
            _DigitChip(
              label: c,
              highlight: widget.done && c == '$answer',
              wrong: _wrongFlash != null && c == '$_wrongFlash',
              onTap: widget.done ? null : () => _pickDigit(int.parse(c)),
            ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: WatotoColors.sky.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _buf.isEmpty ? '·' : _buf,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: WatotoColors.deep,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
          [-1, 0, -2], // -1 spacer visual, -2 backspace
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: d == -1
                        ? const SizedBox(width: 64)
                        : d == -2
                            ? _DigitChip(
                                label: '⌫',
                                onTap: widget.done ? null : _backspace,
                              )
                            : _DigitChip(
                                label: '$d',
                                onTap:
                                    widget.done ? null : () => _pickDigit(d),
                              ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DigitChip extends StatelessWidget {
  const _DigitChip({
    required this.label,
    this.onTap,
    this.highlight = false,
    this.wrong = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool highlight;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? WatotoColors.leaf
        : wrong
            ? WatotoColors.berry
            : WatotoColors.sky;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tap empty cells to fill an m×n array — multiplication made tactile.
class _ArrayBuildStage extends StatefulWidget {
  const _ArrayBuildStage({
    required this.rows,
    required this.cols,
    required this.onCompleted,
  });

  final int rows;
  final int cols;
  final VoidCallback onCompleted;

  @override
  State<_ArrayBuildStage> createState() => _ArrayBuildStageState();
}

class _ArrayBuildStageState extends State<_ArrayBuildStage> {
  late final List<bool> _filled =
      List.filled(widget.rows * widget.cols, false);

  void _tap(int i) {
    if (_filled[i]) return;
    setState(() => _filled[i] = true);
    HapticFeedback.selectionClick();
    if (_filled.every((f) => f)) {
      HapticFeedback.lightImpact();
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _filled.where((f) => f).length;
    final total = widget.rows * widget.cols;
    return Column(
      children: [
        Text(
          '$n / $total',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: WatotoColors.mango,
          ),
        ),
        const SizedBox(height: 10),
        for (var r = 0; r < widget.rows; r++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var c = 0; c < widget.cols; c++)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: GestureDetector(
                    onTap: () => _tap(r * widget.cols + c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _filled[r * widget.cols + c]
                            ? WatotoColors.mango
                            : WatotoColors.sky.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: WatotoColors.deep.withValues(alpha: 0.15),
                        ),
                      ),
                      child: _filled[r * widget.cols + c]
                          ? const Icon(Icons.circle, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Kid coding mini-game: build / choose → big RUN → animated terminal output.
/// Designed so every code-run step is a clear win loop, never a vague button.
class _KidCodeStage extends StatefulWidget {
  const _KidCodeStage({
    required this.plan,
    required this.onCompleted,
    required this.onTapSound,
  });

  final StepPlayPlan plan;
  final VoidCallback onCompleted;
  final VoidCallback onTapSound;

  @override
  State<_KidCodeStage> createState() => _KidCodeStageState();
}

class _KidCodeStageState extends State<_KidCodeStage>
    with SingleTickerProviderStateMixin {
  /// 0 = build, 1 = ready to run, 2 = running animation, 3 = done
  int _phase = 0;
  final List<String> _built = [];
  late List<String> _pool;
  String? _message;
  String? _name;
  int _age = 8;
  int _loopN = 3;
  int _score = 12;
  String _output = '';
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    final challenge = widget.plan.codeChallenge ?? 'print';
    _pool = List<String>.from(widget.plan.codeTokens);
    if (_pool.isEmpty && challenge == 'print') {
      final msg = widget.plan.outputLine ?? 'Hello, world!';
      _pool = ['print', '(', '"$msg"', ')'];
    }
    _pool.shuffle();
    _message = widget.plan.outputLine ?? 'Hello, world!';
    _name = (widget.plan.messageChoices.isNotEmpty)
        ? widget.plan.messageChoices.first
        : 'Sam';
    _loopN = widget.plan.answer ?? 3;
    // Message / variable challenges start ready once a choice is implicit.
    if (challenge == 'message' ||
        challenge == 'variable' ||
        challenge == 'twoLines' ||
        challenge == 'loop' ||
        challenge == 'if') {
      _phase = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _codePreview {
    final c = widget.plan.codeChallenge ?? 'print';
    switch (c) {
      case 'message':
        return 'print("${_message ?? 'Hi!'}")';
      case 'variable':
        return 'name = "${_name ?? 'Sam'}"\nprint(name)';
      case 'twoLines':
        return 'print("${_name ?? 'Amani'}")\nprint($_age)';
      case 'loop':
        return 'for i in range($_loopN):\n  print("Hi")';
      case 'if':
        return 'score = $_score\nif score >= 10:\n  print("You win!")\nelse:\n  print("Try again")';
      default:
        if (_built.isEmpty) return '…';
        return _built.join(' ');
    }
  }

  String get _expectedOutput {
    final c = widget.plan.codeChallenge ?? 'print';
    switch (c) {
      case 'message':
        return _message ?? 'Hi!';
      case 'variable':
        return _name ?? 'Sam';
      case 'twoLines':
        return '${_name ?? 'Amani'}\n$_age';
      case 'loop':
        return List.filled(_loopN, 'Hi').join('\n');
      case 'if':
        return _score >= 10 ? 'You win!' : 'Try again';
      default:
        return widget.plan.outputLine ?? 'Hello, world!';
    }
  }

  bool get _buildComplete {
    final tokens = widget.plan.codeTokens.isNotEmpty
        ? widget.plan.codeTokens
        : ['print', '(', '"${widget.plan.outputLine ?? 'Hello, world!'}"', ')'];
    if (_built.length != tokens.length) return false;
    for (var i = 0; i < tokens.length; i++) {
      if (_built[i] != tokens[i]) return false;
    }
    return true;
  }

  void _tapToken(String token) {
    if (_phase != 0) return;
    final tokens = widget.plan.codeTokens.isNotEmpty
        ? widget.plan.codeTokens
        : ['print', '(', '"${widget.plan.outputLine ?? 'Hello, world!'}"', ')'];
    final next = tokens[_built.length];
    widget.onTapSound();
    if (token == next) {
      HapticFeedback.selectionClick();
      setState(() {
        _built.add(token);
        _pool.remove(token);
        if (_buildComplete) _phase = 1;
      });
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _run() async {
    if (_phase != 1) return;
    setState(() {
      _phase = 2;
      _output = '';
    });
    HapticFeedback.mediumImpact();
    final full = _expectedOutput;
    // Typewriter output — addictive "it worked!" moment.
    for (var i = 1; i <= full.length; i++) {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 28));
      setState(() => _output = full.substring(0, i));
    }
    if (!mounted) return;
    setState(() => _phase = 3);
    HapticFeedback.lightImpact();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.plan.codeChallenge ?? 'print';
    return Column(
      children: [
        // Mascot reacts to phase.
        Text(
          _phase >= 3
              ? '🎉'
              : _phase == 2
                  ? '🤖'
                  : '🧑‍💻',
          style: const TextStyle(fontSize: 48),
        ),
        const SizedBox(height: 8),
        Text(
          _phase == 0
              ? 'Tap blocks in order!'
              : _phase == 1
                  ? 'Ready — smash RUN!'
                  : _phase == 2
                      ? 'Running…'
                      : 'It worked!',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: WatotoColors.deep,
          ),
        ),
        const SizedBox(height: 12),

        // Challenge-specific choosers — each challenge gets the controls it needs.
        if (c == 'twoLines') ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '1. Your name',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final m in widget.plan.messageChoices)
                ChoiceChip(
                  label: Text(m),
                  selected: _name == m,
                  selectedColor: WatotoColors.sun,
                  onSelected: _phase >= 2
                      ? null
                      : (_) => setState(() {
                            _name = m;
                            _phase = 1;
                          }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '2. Your age: $_age',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          Slider(
            value: _age.toDouble(),
            min: 5,
            max: 12,
            divisions: 7,
            label: '$_age',
            activeColor: WatotoColors.mango,
            onChanged: _phase >= 2
                ? null
                : (v) => setState(() {
                      _age = v.round();
                      _phase = 1;
                    }),
          ),
          // Age quick-picks (slider alone is easy to miss on web).
          Wrap(
            spacing: 6,
            children: [
              for (final a in [6, 7, 8, 9, 10, 11])
                ActionChip(
                  label: Text('$a'),
                  backgroundColor: _age == a
                      ? WatotoColors.mango.withValues(alpha: 0.35)
                      : null,
                  onPressed: _phase >= 2
                      ? null
                      : () => setState(() {
                            _age = a;
                            _phase = 1;
                          }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Will print:\n${_name ?? 'Amani'}\n$_age',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: WatotoColors.leaf,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
        ] else if (c == 'message' || c == 'variable') ...[
          Text(
            c == 'message' ? 'What should it say?' : 'What goes in the box?',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final m in widget.plan.messageChoices)
                ChoiceChip(
                  label: Text(m),
                  selected: c == 'variable' ? _name == m : _message == m,
                  selectedColor: WatotoColors.sun,
                  onSelected: _phase >= 2
                      ? null
                      : (_) => setState(() {
                            if (c == 'message') {
                              _message = m;
                            } else {
                              _name = m;
                            }
                            _phase = 1;
                          }),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (c == 'loop') ...[
          Text(
            'Repeat $_loopN times',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final n in [2, 3, 4, 5])
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: _loopN == n,
                    onSelected: _phase >= 2
                        ? null
                        : (_) => setState(() {
                              _loopN = n;
                              _phase = 1;
                            }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (c == 'if') ...[
          Text(
            'score = $_score',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final n in [4, 8, 12, 15])
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: _score == n,
                    onSelected: _phase >= 2
                        ? null
                        : (_) => setState(() {
                              _score = n;
                              _phase = 1;
                            }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Token build tray (print assembly).
        if (c == 'print' || c == 'fix') ...[
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WatotoColors.sky, width: 2),
            ),
            child: Text(
              _built.isEmpty ? '⬇ drop blocks here' : _built.join(' '),
              style: TextStyle(
                fontFamily: 'monospace',
                color: _built.isEmpty
                    ? Colors.white38
                    : const Color(0xFF7DD3FC),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final t in _pool)
                Material(
                  color: WatotoColors.sun,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _tapToken(t),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          color: WatotoColors.deep,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Live code preview for non-token modes.
        if (c != 'print' && c != 'fix') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _codePreview,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF7DD3FC),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Output console
        if (_phase >= 2) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF14532D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OUTPUT',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _output.isEmpty ? ' ' : _output,
                  style: const TextStyle(
                    color: Color(0xFFBBF7D0),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Big pulsing RUN
        if (_phase == 1 || _phase == 0)
          ScaleTransition(
            scale: Tween(begin: 1.0, end: _phase == 1 ? 1.08 : 1.0).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    _phase == 1 ? WatotoColors.mango : Colors.black26,
                foregroundColor: WatotoColors.deep,
                minimumSize: const Size(200, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _phase == 1 ? _run : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 32),
              label: const Text(
                'RUN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        if (_phase >= 3)
          const Text(
            '⭐ You made the computer talk! ⭐',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: WatotoColors.leaf,
            ),
          ),
      ],
    );
  }
}

/// Item-level picture for the stage chrome. Delegates to the shared resolver
/// in step_visuals.dart, which is total over the library's subjects — there is
/// no meaningless ⭐ fallback any more.
String stageEmoji(LibraryItem item) => itemIllustration(item);

/// A staged multiple-choice question: the narration names an object and the
/// child picks it from look-alike distractors. Wrong picks shrink and grey
/// out (with a gentle haptic) so the child can keep trying; the right pick
/// pops and advances the step.
class _ChoiceStage extends StatefulWidget {
  const _ChoiceStage({
    super.key,
    required this.plan,
    required this.onCompleted,
    this.onWrong,
  });

  final ChoicePlan plan;
  final VoidCallback onCompleted;

  /// Fired on each new wrong pick, so callers can score first-attempt
  /// accuracy. The child is never blocked — they keep trying either way.
  final VoidCallback? onWrong;

  @override
  State<_ChoiceStage> createState() => _ChoiceStageState();
}

class _ChoiceStageState extends State<_ChoiceStage> {
  final _wrong = <int>{};
  bool _done = false;

  void _pick(int i) {
    if (_done) return;
    if (i == widget.plan.targetIndex) {
      setState(() => _done = true);
      HapticFeedback.lightImpact();
      widget.onCompleted();
    } else if (_wrong.add(i)) {
      setState(() {});
      widget.onWrong?.call();
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < widget.plan.options.length; i++)
              Semantics(
                button: true,
                label: widget.plan.options[i].word,
                child: GestureDetector(
                  onTap: () => _pick(i),
                  child: AnimatedScale(
                    scale: _done && i == widget.plan.targetIndex
                        ? 1.2
                        : (_wrong.contains(i) ? 0.85 : 1.0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity:
                          _wrong.contains(i) ||
                              (_done && i != widget.plan.targetIndex)
                          ? 0.35
                          : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 92,
                          minHeight: 92,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _done && i == widget.plan.targetIndex
                                ? WatotoColors.leaf
                                : WatotoColors.sky.withValues(alpha: 0.25),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: WatotoColors.deep.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        // Reading choices ("cap" vs "cape") render as words,
                        // not emoji-sized glyphs.
                        child: _isWordOption(widget.plan.options[i].emoji)
                            ? Text(
                                widget.plan.options[i].emoji,
                                style: const TextStyle(
                                  fontFamily: 'Baloo2',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: WatotoColors.deep,
                                ),
                              )
                            : Text(
                                widget.plan.options[i].emoji,
                                style: const TextStyle(fontSize: 48),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_wrong.isNotEmpty && !_done) ...[
          const SizedBox(height: 12),
          Text(
            l10n.tryAgain,
            style: const TextStyle(fontSize: 15, color: WatotoColors.berry),
          ),
        ],
      ],
    );
  }
}

/// A multi-letter alphabetic option is a word to read, not an emoji/symbol.
/// True for anything meant to be *read* — a word, a number, "80 and 12" — as
/// opposed to a single pictorial glyph.
bool _isWordOption(String s) =>
    s.length > 1 && RegExp(r'[A-Za-z0-9]').hasMatch(s);

Widget _bigEmoji(String emoji) =>
    Text(emoji, style: const TextStyle(fontSize: 88));

/// Exposition, demonstration or celebration: there is nothing to find, so the
/// child gets the picture and a plain "Got it!" button. No invented puzzle.
class _ExplainStage extends StatelessWidget {
  const _ExplainStage({
    required this.emoji,
    required this.onCompleted,
    this.prompt,
  });
  final String emoji;
  final VoidCallback onCompleted;

  /// Button label when the step asks for something specific ("Think… then tap
  /// to check!"). Plain exposition just says "Got it!".
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        ExcludeSemantics(child: _bigEmoji(emoji)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onCompleted,
          child: Text(prompt ?? l10n.gotIt),
        ),
      ],
    );
  }
}

/// Tap the big picture to make it pop — bounce + stars so plain taps still feel fun.
class _TapStage extends StatefulWidget {
  const _TapStage({
    required this.emoji,
    required this.onCompleted,
    this.prompt,
  });
  final String emoji;
  final VoidCallback onCompleted;

  /// What the child is being asked to do, from the step plan ("Tap the little
  /// a!", "Shake it — then tap!"). Falls back to the generic invitation only
  /// when the step named nothing.
  final String? prompt;
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
    final prompt = widget.prompt;
    return Column(
      children: [
        Semantics(
          button: true,
          // Screen readers still need a name for the target even when the
          // caption above carries the visible instruction.
          label: prompt ?? l10n.tapEachPrompt,
          child: GestureDetector(
            onTap: _tap,
            child: AnimatedScale(
              scale: _done ? 1.28 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_done ? WatotoColors.leaf : WatotoColors.sun)
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  _bigEmoji(widget.emoji),
                  if (_done)
                    const Positioned(
                      top: 0,
                      right: 8,
                      child: Text('⭐', style: TextStyle(fontSize: 28)),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_done || prompt != null) ...[
          const SizedBox(height: 12),
          Text(
            _done ? 'Yes!' : prompt!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _done ? WatotoColors.leaf : WatotoColors.sky,
            ),
          ),
        ],
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
    this.prompt,
  });
  final String emoji;
  final String? prompt;
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
          widget.prompt ?? l10n.tapEachPrompt,
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
  const _DragStage({
    required this.emoji,
    required this.onCompleted,
    this.prompt,
  });
  final String emoji;
  final String? prompt;
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
          widget.prompt ?? l10n.dragToBasket,
          textAlign: TextAlign.center,
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
  const _QuizView({super.key, required this.item});
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
  int? _hintHideIndex; // dim one wrong option after a miss
  bool _hintShown = false;
  final _answers = <Map<String, dynamic>>[];
  final _elapsed = Stopwatch()..start();

  /// The questions actually played, already localized.
  ///
  /// Most quizzes ship a single question, which is not a check on anything, so
  /// this tops them up with review questions from the same subject's lessons
  /// (see quiz_review.dart). Resolved once per run: rebuilding it mid-quiz
  /// could change the question under a child's finger.
  List<LibQuestion>? _questionsCache;

  List<LibQuestion> get _questions {
    return _questionsCache ??= localizedQuizQuestions(
      quiz: widget.item,
      library: ref.read(libraryProvider).asData?.value.all ?? const [],
      i18n: ref.read(contentI18nProvider).asData?.value,
      lang: ref.read(localeProvider).languageCode,
      correctFeedback: AppLocalizations.of(context).quizPerfect,
      retryFeedback: AppLocalizations.of(context).quizNiceTry,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakPrompt());
  }

  void _speakPrompt() {
    final lang = ref.read(localeProvider).languageCode;
    ref.read(narrationProvider.notifier).speak(
          _questions[_q].prompt,
          lang,
          style: SpeakStyle.lesson,
        );
  }

  void _offerHint() {
    final question = _questions[_q];
    final lang = ref.read(localeProvider).languageCode;
    final l10n = AppLocalizations.of(context);
    // Hide one incorrect option (first wrong index).
    int? hide;
    for (var i = 0; i < question.options.length; i++) {
      if (i != question.answer) {
        hide = i;
        break;
      }
    }
    setState(() {
      _hintHideIndex = hide;
      _hintShown = true;
      _feedback = l10n.quizHintBody;
      _feedbackGood = false;
    });
    ref.read(narrationProvider.notifier).speak(
          l10n.quizHintBody,
          lang,
          style: SpeakStyle.hint,
        );
  }

  void _pick(int index) {
    final question = _questions[_q];
    final lang = ref.read(localeProvider).languageCode;
    final l10n = AppLocalizations.of(context);
    if (index == question.answer) {
      _answers.add({
        'questionId': '${widget.item.id}.q$_q',
        'selectedIndex': index,
      });
      if (!_wrongThisQ) _firstTryCorrect++;
      final praise = _wrongThisQ ? l10n.quizNiceTry : question.correctFeedback;
      setState(() {
        _feedback = praise;
        _feedbackGood = true;
      });
      ref.read(soundEffectsProvider).correct();
      ref.read(narrationProvider.notifier).speak(
            praise,
            lang,
            style: SpeakStyle.cheer,
          );
      Timer(const Duration(milliseconds: 900), _next);
    } else {
      setState(() {
        _wrongThisQ = true;
        _feedback = question.retryFeedback;
        _feedbackGood = false;
      });
      ref.read(narrationProvider.notifier).speak(
            question.retryFeedback,
            lang,
            style: SpeakStyle.hint,
          );
    }
  }

  void _next() {
    if (!mounted) return;
    if (_q < _questions.length - 1) {
      setState(() {
        _q++;
        _wrongThisQ = false;
        _feedback = null;
        _hintHideIndex = null;
        _hintShown = false;
      });
      _speakPrompt();
    } else {
      _elapsed.stop();
      final total = _questions.length;
      final scorePct = total == 0
          ? 0
          : ((_firstTryCorrect / total) * 100).round();
      // starsFromScorePct is applied inside LearningService; mirror for UI.
      final stars = scorePct >= 100 ? 3 : (scorePct >= 67 ? 2 : (scorePct >= 40 ? 1 : 0));
      setState(() {
        _done = true;
        _stars = stars;
      });
      ref.read(soundEffectsProvider).celebrate();
      final lang = ref.read(localeProvider).languageCode;
      final l10n = AppLocalizations.of(context);
      ref.read(narrationProvider.notifier).speak(
            stars >= 3
                ? l10n.quizPerfect
                : l10n.greatJob,
            lang,
            style: SpeakStyle.cheer,
          );
      unawaited(
        ref
            .read(learningServiceProvider)
            .completeLibraryQuiz(
              widget.item,
              scorePct: scorePct,
              passed: scorePct >= 40,
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
        title: _stars >= 3 ? l10n.quizPerfect : l10n.greatJob,
        xp: widget.item.xp,
        stars: _stars,
        nextId: _nextInSubject(ref, widget.item)?.id,
      );
    }
    final question = _questions[_q];
    return Scaffold(
      appBar: _bar(context, loc.title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _ProgressDots(count: _questions.length, active: _q),
              const SizedBox(height: 12),
              // Prefer bundled art, then emoji illustration.
              ExcludeSemantics(
                child: _artOrEmoji(
                  widget.item,
                  illustrationFor(question.prompt) ?? '❓',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_wrongThisQ && !_hintShown) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _offerHint,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(l10n.quizHint),
                ),
              ],
              if (_feedback != null) ...[
                const SizedBox(height: 8),
                Text(
                  _feedback!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _feedbackGood ? WatotoColors.leaf : WatotoColors.mango,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < question.options.length; i++)
                      if (i != _hintHideIndex)
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Illustrate one-word answers ("Ball" → ⚽)
                                // from the English source label.
                                if (lexiconLookup(
                                      question.options[i].label
                                          .trim()
                                          .toLowerCase(),
                                    )
                                    case final LexEntry e) ...[
                                  ExcludeSemantics(
                                    child: Text(
                                      e.emoji,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(child: Text(loc.optionLabel(_q, i))),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
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
  const _StoryView({super.key, required this.item});
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
      return _Celebration(
        emoji: '📖✨',
        title: l10n.theEnd,
        xp: widget.item.xp,
        nextId: _nextInSubject(ref, widget.item)?.id,
      );
    }
    final pages = widget.item.pages;
    final isLast = _page == pages.length - 1;
    return Scaffold(
      appBar: _bar(context, loc.title),
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
                      _artOrEmoji(
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

class _Celebration extends ConsumerStatefulWidget {
  const _Celebration({
    required this.emoji,
    required this.title,
    required this.xp,
    this.stars = 0,
    this.nextId,
  });
  final String emoji;
  final String title;
  final int xp;
  final int stars;

  /// The next playable item in the same stage+subject, if any — keeps the
  /// homework session going instead of dumping the child back at home.
  final String? nextId;

  @override
  ConsumerState<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends ConsumerState<_Celebration> {
  /// What this completion earned, latched the moment it arrives.
  ///
  /// It cannot simply be read in [initState]: the player marks itself done and
  /// builds this screen *before* the unawaited write that produces the reward
  /// has finished. On a fast in-memory store the write usually wins the race,
  /// which is why tests never saw it — but against real IndexedDB the frame
  /// renders first and the reward reads as null, silently dropping the coins,
  /// stars and badges. So watch the provider and latch the first non-null
  /// value instead of sampling once.
  RewardOutcome? _reward;

  /// Latches [outcome] and consumes it, so leaving cannot carry the reward
  /// into the next celebration.
  void _takeReward(RewardOutcome outcome) {
    _reward = outcome;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Escalate the sound to match the moment: a new level and a rescued
      // streak should not sound identical to finishing a routine activity.
      final sfx = ref.read(soundEffectsProvider);
      if (outcome.levelUp > 0) {
        sfx.levelUp();
      } else if (outcome.streakSavedDays > 0) {
        sfx.streak();
      } else if (outcome.coins > 0) {
        sfx.coin();
      }
      // Badges are revealed here now, so drop the queue that would otherwise
      // re-announce them as a toast on the next visit to the home screen.
      if (outcome.badgeIds.isNotEmpty) {
        ref.read(pendingBadgeToastProvider.notifier).state = [];
      }
      ref.read(pendingRewardProvider.notifier).state = null;
    });
  }

  String get emoji => widget.emoji;
  String get title => widget.title;
  int get xp => widget.xp;
  int get stars => widget.stars;
  String? get nextId => widget.nextId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levelUp = ref.watch(pendingLevelUpProvider);
    final totalXp = ref.watch(xpProvider);
    final level = rewards.levelForXp(totalXp);
    final progress = rewards.levelProgress(totalXp);

    // Latch the outcome whenever the completion write lands — which may be
    // several frames after this screen first appeared.
    final incoming = ref.watch(pendingRewardProvider);
    if (incoming != null && _reward == null) {
      _takeReward(incoming);
    }

    // Everything the completion just earned. Null on the paths that have not
    // been migrated (or in tests that build this view directly), in which case
    // the screen degrades to the plain XP celebration it always was.
    final reward = _reward;
    final earnedStars = stars > 0 ? stars : (reward?.stars ?? 0);
    final coins = reward?.coins ?? 0;
    final badgeIds = reward?.badgeIds ?? const <String>[];
    final streakSaved = reward?.streakSavedDays ?? 0;
    final firstInSubject = reward?.firstInSubject ?? false;
    // Cool-down: the mascot and the big emoji stand down once a child has been
    // celebrated five times in one sitting, unless this one is a milestone.
    final brief = reward?.brief ?? false;
    // Whether anything beyond XP is on screen — drives how much room the
    // mascot is allowed to take.
    final hasExtras = earnedStars > 0 ||
        coins > 0 ||
        streakSaved > 0 ||
        badgeIds.isNotEmpty;

    final headline = levelUp > 0
        ? l10n.levelUp(levelUp)
        : earnedStars >= 3
            ? l10n.perfectRun
            : firstInSubject
                ? l10n.firstTimeHere
                : title;

    return Scaffold(
      body: SafeArea(
        // Scroll-safe at large text sizes.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!brief)
                  MascotWidget(
                    mood: MascotMood.cheer,
                    // The mascot yields room when there are real rewards to
                    // show below it, so the buttons stay reachable on a small
                    // phone without scrolling.
                    size: hasExtras ? 72 : 96,
                    label: levelUp > 0 ? 'Level up!' : 'Great job!',
                  ),
                if (emoji.isNotEmpty && !brief && !hasExtras) ...[
                  const SizedBox(height: 8),
                  Text(emoji, style: const TextStyle(fontSize: 40)),
                ],
                const SizedBox(height: 12),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (earnedStars > 0) ...[
                  const SizedBox(height: 8),
                  _EarnedStars(stars: earnedStars, animate: !brief),
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
                if (coins > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🪙 ${l10n.coinsEarned(coins)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: WatotoColors.deep,
                    ),
                  ),
                ],
                if (streakSaved > 0) ...[
                  const SizedBox(height: 12),
                  _StreakSavedNote(days: streakSaved, l10n: l10n),
                ],
                if (badgeIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _BadgeReveal(badgeIds: badgeIds, l10n: l10n),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.levelLabel(level),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.deep,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: WatotoColors.sun.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation(WatotoColors.mango),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (nextId != null)
                      FilledButton(
                        onPressed: () =>
                            context.pushReplacement('/play/$nextId'),
                        child: Text(l10n.keepGoing),
                      ),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: Text(l10n.done),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "What did we learn?" — the recap that closes a lesson.
///
/// One question at a time, drawn from the lesson's own content. Wrong picks
/// grey out and the child keeps trying, exactly as they do mid-lesson: the
/// recap measures learning, it does not gate the celebration behind a pass
/// mark. Only first-attempt errors are counted.
class _LessonRecapView extends ConsumerStatefulWidget {
  const _LessonRecapView({
    required this.title,
    required this.localized,
    required this.questions,
    required this.onWrong,
    required this.onFinished,
  });

  final String title;

  /// Supplies the translated prompt and options for authored questions.
  final LocalizedItem localized;

  final List<RecapQuestion> questions;
  final VoidCallback onWrong;
  final VoidCallback onFinished;

  @override
  ConsumerState<_LessonRecapView> createState() => _LessonRecapViewState();
}

class _LessonRecapViewState extends ConsumerState<_LessonRecapView> {
  int _index = 0;
  bool _answered = false;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  /// The question as the child sees it: translated when authored, the English
  /// extraction otherwise (which only ever reaches an English-speaking child).
  String _promptFor(int i) {
    final q = widget.questions[i];
    final r = q.recapIndex;
    return r == null ? q.prompt : widget.localized.recapPrompt(r);
  }

  List<String> _optionsFor(int i) {
    final q = widget.questions[i];
    final r = q.recapIndex;
    return r == null ? q.options : widget.localized.recapOptions(r);
  }

  void _speak() {
    if (!mounted) return;
    final lang = ref.read(localeProvider).languageCode;
    // Read the choices out after the question. A child who is still learning
    // to read can hear the options rather than having to decode three written
    // answers under time pressure — the recap is testing what they learned in
    // the lesson, not how fast they read.
    final options = _optionsFor(_index).join('. ');
    ref.read(narrationProvider.notifier).speak(
          '${_promptFor(_index)} $options',
          lang,
          style: SpeakStyle.hint,
        );
  }

  void _onCorrect() {
    if (_answered) return;
    setState(() => _answered = true);
    ref.read(soundEffectsProvider).correct();
    _advance?.cancel();
    _advance = Timer(const Duration(milliseconds: 900), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    _advance?.cancel();
    if (_index >= widget.questions.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() {
      _index++;
      _answered = false;
    });
    _speak();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = widget.questions[_index];
    final total = widget.questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: false,
        actions: const [_NarrationButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.recapTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.recapProgress(_index + 1, total),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WatotoColors.deep.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ProgressDots(count: total, active: _index),
                  const SizedBox(height: 20),
                  Text(
                    _promptFor(_index),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: WatotoColors.deep,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ChoiceStage(
                    key: ValueKey('recap-$_index'),
                    plan: ChoicePlan(
                      [for (final o in _optionsFor(_index)) ChoiceOption(o, o)],
                      q.answerIndex,
                    ),
                    onCompleted: _onCorrect,
                    onWrong: widget.onWrong,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _answered ? _goNext : null,
                    child: Text(
                      _index >= total - 1 ? l10n.done : l10n.next,
                    ),
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

/// The run's 1–3 star rating, popping in one at a time so the count reads as
/// an event rather than a static label.
class _EarnedStars extends StatelessWidget {
  const _EarnedStars({required this.stars, this.animate = true});

  final int stars;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: i < stars
                    ? TweenAnimationBuilder<double>(
                        // Each star lands a beat after the one before it.
                        duration: Duration(
                          milliseconds: animate ? 260 + i * 180 : 1,
                        ),
                        curve: Curves.elasticOut,
                        tween: Tween(begin: animate ? 0 : 1, end: 1),
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: const Text(
                          '⭐',
                          style: TextStyle(fontSize: 40),
                        ),
                      )
                    : const Opacity(
                        opacity: 0.22,
                        child: Text(
                          '⭐',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Your streak survived" — shown when the weekly shield covered a missed day.
/// This used to happen silently, which threw away the one moment where the
/// streak system is genuinely reassuring rather than demanding.
class _StreakSavedNote extends StatelessWidget {
  const _StreakSavedNote({required this.days, required this.l10n});

  final int days;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WatotoColors.sky.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '🛡️ ${l10n.streakSavedTitle}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: WatotoColors.deep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.streakSavedBody(days),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Badges revealed at the moment they are earned, rather than as a toast the
/// next time the child happens to open the home screen.
class _BadgeReveal extends StatelessWidget {
  const _BadgeReveal({required this.badgeIds, required this.l10n});

  final List<String> badgeIds;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final catalog = {for (final b in rewards.allBadges) b.id: b};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WatotoColors.sun.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            l10n.badgeUnlocked,
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: WatotoColors.deep,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final id in badgeIds)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.elasticOut,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        catalog[id]?.emoji ?? '🏅',
                        style: const TextStyle(fontSize: 34),
                      ),
                      Text(
                        badgeLabel(l10n, id),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Next incomplete item after [item] in the same stage+subject, then any
/// incomplete in that subject (keeps the learning session going).
LibraryItem? _nextInSubject(WidgetRef ref, LibraryItem item) {
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
