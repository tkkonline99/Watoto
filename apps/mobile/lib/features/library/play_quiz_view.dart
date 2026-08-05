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
import '../../l10n/gen/app_localizations.dart';
import 'content_i18n.dart';
import 'content_lexicon.dart';
import 'library_models.dart';
import 'play_celebration.dart';
import 'play_shared.dart';
import 'library_repository.dart';
import 'quiz_review.dart';

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ProgressDots(count: _questions.length, active: _q),
              const SizedBox(height: 12),
              // Prefer bundled art, then emoji illustration.
              ExcludeSemantics(
                child: artOrEmoji(
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
