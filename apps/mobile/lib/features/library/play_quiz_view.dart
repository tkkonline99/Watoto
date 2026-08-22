/// The quiz runner: one question at a time, scored, with stars at the end.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/stages/question_scaffold.dart';
import '../../core/widgets/stages/stage_scenes.dart';
import '../../l10n/gen/app_localizations.dart';
import 'content_i18n.dart';
import 'content_lexicon.dart';
import 'library_models.dart';
import 'option_photos.dart';
import 'play_celebration.dart';
import 'play_shared.dart';
import 'play_stages.dart';
import 'quiz_review.dart';
import 'visual_stage.dart';

class QuizView extends ConsumerStatefulWidget {
  const QuizView({super.key, required this.item});
  final LibraryItem item;
  @override
  ConsumerState<QuizView> createState() => QuizViewState();
}

class QuizViewState extends ConsumerState<QuizView> {
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
  /// Resolved once per run: rebuilding it mid-quiz could change the question
  /// under a child's finger. This used to top short quizzes up with borrowed
  /// recap questions; every quiz is now authored to its tier's depth, so it
  /// only localizes what the quiz already asks (see quiz_review.dart).
  List<LibQuestion>? _questionsCache;

  List<LibQuestion> get _questions {
    return _questionsCache ??= localizedQuizQuestions(
      quiz: widget.item,
      i18n: ref.read(contentI18nProvider).asData?.value,
      lang: ref.read(localeProvider).languageCode,
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

  /// The number a counting scene should draw, taken from the correct answer.
  ///
  /// For "How many balls?" the answer *is* the count, so this is the only
  /// honest source — the prompt never states it. Null when the answer is not
  /// a bare number, which is most questions; the scene then keeps whatever
  /// the content declared.
  /// Read from the English source rather than the localized copy: a French
  /// build shows "deux", which parses as nothing, and the scene would fall
  /// back to a default count that is simply wrong.
  int? _countFromAnswer(int index) {
    final source = widget.item.questions;
    if (index < 0 || index >= source.length) return null;
    final q = source[index];
    if (q.answer < 0 || q.answer >= q.options.length) return null;
    final n = int.tryParse(q.options[q.answer].label.trim());
    return (n != null && n > 0 && n <= 20) ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = localizedItem(ref, widget.item);
    if (_done) {
      return Celebration(
        emoji: '🎉',
        title: _stars >= 3 ? l10n.quizPerfect : l10n.greatJob,
        xp: widget.item.xp,
        stars: _stars,
        nextId: nextInSubject(ref, widget.item)?.id,
      );
    }
    final question = _questions[_q];
    return Scaffold(
      appBar: playAppBar(context, loc.title),
      body: QuestionScaffold(
        stage: widget.item.stage,
        // A quiz a child reads is text-heavy by definition: the prompt and
        // four full-width answers need the room more than the picture does.
        textHeavy: widget.item.reading,
        progress: QuestionProgress(
          index: _q,
          total: _questions.length,
          asCount: true,
        ),
        stageVisual: ExcludeSemantics(
          child: VisualStage(
            visual: question.visual,
            fallbackEmoji: illustrationFor(question.prompt) ?? '❓',
            data: SceneData(
              // A counting scene has to draw the number the question is
              // about. Without this it drew its default of five for "How
              // many balls?" while the answers were 1, 2 and 3 — a child who
              // counted the picture was being told the wrong thing, which is
              // the same fault as the tin of food wearing a different hat.
              count: _countFromAnswer(_q),
              text: question.prompt,
            ),
          ),
        ),
        stageSemanticLabel: question.visual?.alt,
        prompt: question.prompt,
        promptAudio: ReplayNarrationButton(onReplay: _speakPrompt),
        response: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < question.options.length; i++)
              if (i != _hintHideIndex)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  // Same card as a lesson's answers (play_stages.dart), so the
                  // quiz half of an activity does not look like a different
                  // app from the lesson half. Smaller disc: a quiz offers up
                  // to four answers under a 300dp stage.
                  child: Semantics(
                    button: true,
                    label: loc.optionLabel(_q, i),
                    child: InkWell(
                      onTap: () => _pick(i),
                      borderRadius: BorderRadius.circular(22),
                      // Excluded inside the InkWell, never on the Semantics
                      // above it — the short form drops the tap action and
                      // leaves a button a reader cannot activate.
                      child: ExcludeSemantics(
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 64),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: answerCardDecoration(),
                          child: Row(
                            children: [
                              // Illustrate one-word answers ("Ball" → ⚽)
                              // from the English source label.
                              if (question.options[i].label
                                      .trim()
                                      .toLowerCase()
                                  case final word
                                      when lexiconLookup(word) != null) ...[
                                AnswerPictureDisc(
                                  glyph: lexiconLookup(word)!.emoji,
                                  photoAsset: optionPhotoAsset(word),
                                  size: 44,
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Text(
                                  loc.optionLabel(_q, i),
                                  style: answerLabelStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
        assist: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_feedback != null)
              // Announced rather than merely shown: it appears in response to
              // a tap, so a reader that only speaks on focus never reaches it.
              // §26.6 — retry is berry, never red and never a cross.
              Semantics(
                liveRegion: true,
                child: Text(
                  _feedback!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        _feedbackGood ? WatotoColors.leaf : WatotoColors.berry,
                  ),
                ),
              ),
            if (_wrongThisQ && !_hintShown)
              TextButton.icon(
                onPressed: _offerHint,
                icon: const Icon(Icons.lightbulb_outline),
                label: Text(l10n.quizHint),
              ),
          ],
        ),
      ),
    );
  }
}
