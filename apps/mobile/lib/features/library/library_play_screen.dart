import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/stages/question_scaffold.dart';
import '../../core/widgets/stages/stage_scenes.dart';
import '../../core/widgets/watoto_status_views.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/entitlements.dart';
import '../gamification/reward_outcome.dart';
import 'circuit_figures.dart';
import 'content_lexicon.dart';
import 'library_models.dart';
import 'lesson_recap.dart';
import 'library_repository.dart';
import 'step_motion.dart';
import 'step_play.dart';
import 'play_celebration.dart';
import 'play_shared.dart';
import 'play_quiz_view.dart';
import 'play_recap_view.dart';
import 'play_stages.dart';
import 'play_story_view.dart';
import 'step_visuals.dart';
import 'visual_stage.dart';
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
      error: (e, _) => Scaffold(
        body: SafeArea(
          child: WatotoLoadError(
            onRetry: () => ref.invalidate(libraryProvider),
          ),
        ),
      ),
      data: (repo) {
        final item = repo.byId[id];
        if (item == null) {
          return const WatotoNotFoundScreen();
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
          LibraryType.quiz => QuizView(key: key, item: item),
          LibraryType.story => StoryView(key: key, item: item),
        };
      },
    );
  }
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
  SpeechBeat? _autoAdvance; // pending "move on once the feedback is heard"

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

  /// One answer option: its localized [label], plus whatever picture the
  /// step's figure id names. Unknown ids fall through to a plain word option
  /// rather than breaking the lesson.
  ChoiceOption _option(String label, String figureId) {
    if (figureId.isEmpty) return ChoiceOption(label, label);
    final circuit = circuitFigureFor(figureId);
    if (circuit != null) return ChoiceOption(label, label, figure: circuit);
    return ChoiceOption(label, label, hero: illustrationFor(figureId));
  }

  /// Speaks the current step's narration (the caption), if narration is on.
  Future<void> _speakStep() async {
    if (widget.item.steps.isEmpty) return;
    final lang = ref.read(localeProvider).languageCode;
    // Waited for, not sampled: on a cold start this is the screen that starts
    // the locale bundle loading, and speaking from the snapshot a frame later
    // read the English text out in the child's own voice.
    final loc = await awaitLocalizedItem(ref, widget.item);
    if (!mounted) return;
    unawaited(ref.read(narrationProvider.notifier).speak(
          loc.stepNarration(_step),
          lang,
          style: SpeakStyle.lesson,
        ));
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
    final step = _step;
    final feedbackSpoken = () async {
      final loc = await awaitLocalizedItem(ref, widget.item);
      if (!mounted) return;
      await ref.read(narrationProvider.notifier).speak(
            loc.stepFeedback(step),
            lang,
            style: SpeakStyle.cheer,
          );
    }();
    // Auto-advance once the feedback has been heard, and never sooner than a
    // beat, so the loop stays snappy without cutting the voice off. User can
    // still tap Next/Done immediately — button is enabled as soon as
    // [_interacted] is true. Held in a field so a manual Next cancels it: a
    // stale beat would otherwise fire on the *following* step and skip (or
    // complete) it early.
    _autoAdvance?.cancel();
    _autoAdvance = SpeechBeat(
      speech: feedbackSpoken,
      minimum: const Duration(milliseconds: 1400),
      onDone: () {
        if (!mounted || !_interacted) return;
        // Only auto-advance if we're still on the same completed step.
        _next();
      },
    );
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
    final loc = localizedItem(ref, widget.item);
    if (_inRecap) {
      return LessonRecapView(
        title: loc.title,
        localized: loc,
        questions: _recap,
        onWrong: () => _recapWrong++,
        onFinished: _finishLesson,
      );
    }
    if (_done) {
      return Celebration(
        emoji: '🎉',
        title: l10n.greatJob,
        xp: widget.item.xp,
        nextId: nextInSubject(ref, widget.item)?.id,
      );
    }
    final steps = widget.item.steps;
    if (steps.isEmpty) {
      return Scaffold(
        appBar: playAppBar(context, loc.title),
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
      // Options are drawn when the step names a picture for each one: a
      // circuit diagram where the answer *is* a circuit, otherwise a lexicon
      // emoji for answers that are a concrete thing. The caption stays the
      // localized text; only the artwork comes from the figure id, which is
      // why the id is language-neutral.
      StepMechanic.multiChoice when plan.choices.length > 1 => ChoicePlan(
          [
            for (final (i, c) in loc.stepChoices(_step).indexed)
              _option(c, i < plan.figures.length ? plan.figures[i] : ''),
          ],
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
    final emoji = stepIllustration(
      item: widget.item,
      narration: narrationEn,
      visual: widget.item.steps[_step].visual,
    );
    // The narration is now the skeleton's prompt (part 4) rather than a
    // caption floated above or below the stage, so there is one of it by
    // construction and no need to choose a side.
    final interaction = SmartInteractionStage(
      key: ValueKey('step-$_step'),
      plan: plan,
      prompt: stepPrompt,
      emoji: emoji,
      choice: choice,
      done: _interacted,
      onCompleted: _onInteracted,
      onTapSound: () => ref.read(soundEffectsProvider).tap(),
      onWrong: () {
        setState(() {
          _combo = 0;
          _mistakes++;
        });
        // A distinct, gentle "not that one" — the plain tap sound gave a
        // wrong pick no feedback at all.
        ref.read(soundEffectsProvider).retry();
      },
    );

    // Part 3 of the skeleton.
    //
    // The stage must never repeat what the response zone already shows. Two
    // ways that happens, and both looked wrong on a real screen:
    //
    //  - a staged choice puts the pictures in the options, so reserving 300dp
    //    above them rendered a blank white box — the exact hole §26.2 exists
    //    to remove, and worse than the old collapsed layout;
    //  - a tap stage renders the step's glyph as its own target, so a token
    //    visual above it showed the same bubbles twice, one dead and one
    //    alive. That rule predates this change; the port dropped it.
    //
    // In both cases the stage collapses rather than reserving empty space. A
    // slot or a scene still shows, because that is different art from
    // whatever the response is doing.
    // Localized: the alt is announced to a screen reader and, on the 1,512
    // parts whose art is still a brief, printed inside the striped
    // placeholder. Authored in English, it was doing both in every language.
    final visual = loc.stepVisual(_step);
    final stageRepeatsResponse = choice != null ||
        (stageShowsEmoji(plan.mechanic) && visual is TokenVisual);

    final Widget stageContent;
    if (stageOwnsCanvas(plan.mechanic)) {
      stageContent = interaction;
    } else if (plan.workspace != null) {
      stageContent = DivisionWorkspace(
        workspace: plan.workspace!,
        filledDigit: _shownAnswer ?? (_interacted ? plan.answer : null),
      );
    } else if (stageRepeatsResponse) {
      stageContent = const SizedBox.shrink();
    } else {
      // The stage art is decorative: its meaning is carried by the visual's
      // alt, which _Stage announces, and by the prompt underneath. Without
      // this the reader walks into the glyph and reads its Unicode name —
      // the same fault SubjectIsland shipped with.
      stageContent = ExcludeSemantics(
        child: BreathingArt(
          restartKey: _step,
          child: VisualStage(
            visual: visual,
            fallbackEmoji: emoji,
            data: SceneData(
              count: step.count,
              rows: step.rows,
              cols: step.cols,
              // Narration *and* prompt, because author_visuals.py picks the
              // scene from both. Three "make ten" steps teach in the narration
              // and keep the sum in the prompt ("10 − 2 = ?"); with narration
              // alone the number sentence had nothing to read and fell back to
              // a glyph on exactly the steps it was chosen for.
              text: step.sceneText,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: playAppBar(context, loc.title),
      body: QuestionScaffold(
        stage: widget.item.stage,
        textHeavy: widget.item.reading,
        progress: QuestionProgress(
          index: _step,
          total: steps.length,
          streak: _combo > 1 ? _combo : null,
        ),
        stageVisual: stageContent,
        // A collapsed stage sizes to nothing rather than holding 300dp of
        // white; a canvas-owning workspace sizes to whatever it needs.
        stageFitsContent:
            stageOwnsCanvas(plan.mechanic) || stageRepeatsResponse,
        distributeSlack: !stageOwnsCanvas(plan.mechanic),
        // The narration is the question on these bands, and it speaks once.
        // Offer it back rather than making the child finish a step they did
        // not hear.
        promptAudio: ReplayNarrationButton(onReplay: _speakStep),
        // The alt is the screen-reader label (§26.6). Stages that own the
        // canvas are interactive and announce themselves, so labelling them
        // as an image would talk over their own semantics.
        stageSemanticLabel: stageOwnsCanvas(plan.mechanic) || stageRepeatsResponse
            ? null
            : visual?.alt,
        prompt: loc.stepNarration(_step),
        response: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!stageOwnsCanvas(plan.mechanic)) interaction,
            if (_interacted) ...[
              const SizedBox(height: 16),
              // Feedback appears after the child acts, so it has to announce
              // itself — a reader that only speaks on focus change would never
              // reach it. §26.6: correct is leaf, never red and never a cross.
              Semantics(
                liveRegion: true,
                child: Text(
                  loc.stepFeedback(_step),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: WatotoColors.leaf,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _interacted ? _next : null,
                child: Text(isLast ? l10n.done : l10n.next),
              ),
            ),
          ],
        ),
        assist: _Assist(
          item: widget.item,
          hint: stepPrompt != null &&
                  !_interacted &&
                  !stageShowsPrompt(plan.mechanic)
              ? stepPrompt
              : null,
          // §26.5. `real-world` is the authored action for a step that happens
          // away from the screen — 103 of them — so the chip is driven by the
          // content rather than guessed from the wording.
          grownUpNeeded: step.action == 'real-world',
        ),
      ),
    );
  }
}

/// Part 6 — what to do next, never a scold (§26.2). Carries the planner's
/// hint when the stage does not print it itself, and the co-play tip for the
/// bands where a grown-up is the primary user.
class _Assist extends StatelessWidget {
  const _Assist({required this.item, this.hint, this.grownUpNeeded = false});

  final LibraryItem item;
  final String? hint;

  /// The step happens away from the screen, so a grown-up has to be there.
  final bool grownUpNeeded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (grownUpNeeded) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: WatotoColors.mango.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.grownUpNeeded,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: WatotoColors.deep,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (hint case final h?) Text(h, textAlign: TextAlign.center),
        CoPlayTip(item: item),
      ],
    );
  }
}

// -------------------------------------------------- interaction mechanics


/// Long-division style workspace — digits the child enters appear *above*
/// the dividend so "write it above the 8" is real, not empty advice.

/// Kid coding mini-game: build / choose → big RUN → animated terminal output.
/// Designed so every code-run step is a clear win loop, never a vague button.


/// A staged multiple-choice question: the narration names an object and the
/// child picks it from look-alike distractors. Wrong picks shrink and grey
/// out (with a gentle haptic) so the child can keep trying; the right pick
/// pops and advances the step.
/// Exposition, demonstration or celebration: there is nothing to find, so the
/// child gets the picture and a plain "Got it!" button. No invented puzzle.

// ------------------------------------------------------------------- quiz


// ------------------------------------------------------------------ story


// ------------------------------------------------------------- shared bits


/// "What did we learn?" — the recap that closes a lesson.
///
/// One question at a time, drawn from the lesson's own content. Wrong picks
/// grey out and the child keeps trying, exactly as they do mid-lesson: the
/// recap measures learning, it does not gate the celebration behind a pass
/// mark. Only first-attempt errors are counted.

/// The run's 1–3 star rating, popping in one at a time so the count reads as
/// an event rather than a static label.

