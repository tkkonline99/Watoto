import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sound_effects.dart';
import '../../core/l10n/content_key_resolver.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'quiz_models.dart';
import 'quiz_repository.dart';

class QuizRunnerScreen extends ConsumerStatefulWidget {
  const QuizRunnerScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<QuizRunnerScreen> createState() => _QuizRunnerScreenState();
}

class _QuizRunnerScreenState extends ConsumerState<QuizRunnerScreen> {
  final List<int> _selected = [];
  int? _justPicked;
  QuizGrade? _grade;
  Stopwatch _elapsed = Stopwatch()..start();

  void _pick(QuizBody quiz, int optionIndex) {
    if (_justPicked != null || _grade != null) return;
    setState(() => _justPicked = optionIndex);
    // Neutral pop only — quizzes are assessments, so no per-question
    // right/wrong audio cue (mirrors the visual acknowledgement below).
    ref.read(soundEffectsProvider).tap();
    // Brief visual acknowledgement, then advance — quizzes are assessments,
    // so there is no retry within a question (docs/11 §11.5).
    Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _selected.add(optionIndex);
        _justPicked = null;
        if (_selected.length == quiz.questions.length) {
          _finish(quiz);
        }
      });
    });
  }

  void _finish(QuizBody quiz) {
    _elapsed.stop();
    final grade = quiz.grade(_selected);
    _grade = grade;
    if (grade.passed) ref.read(soundEffectsProvider).celebrate();
    unawaited(
      ref
          .read(learningServiceProvider)
          .completeQuiz(
            quiz,
            selected: List.of(_selected),
            grade: grade,
            durationS: _elapsed.elapsed.inSeconds,
          ),
    );
  }

  void _retry() {
    setState(() {
      _selected.clear();
      _grade = null;
      _justPicked = null;
      _elapsed = Stopwatch()..start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quizAsync = ref.watch(quizProvider(widget.slug));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
        title: quizAsync.maybeWhen(
          data: (quiz) => Text(
            resolveContentKey(l10n, quiz.titleKey),
            style: const TextStyle(
              color: WatotoColors.deep,
              fontWeight: FontWeight.w800,
            ),
          ),
          orElse: () => null,
        ),
      ),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (quiz) {
          final grade = _grade;
          if (grade != null) {
            return _QuizResultView(
              grade: grade,
              onRetry: _retry,
              onDone: () => context.go('/'),
            );
          }
          final question = quiz.questions[_selected.length];
          return _QuestionView(
            key: ValueKey(_selected.length),
            question: question,
            index: _selected.length,
            total: quiz.questions.length,
            justPicked: _justPicked,
            onPick: (i) => _pick(quiz, i),
          );
        },
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.justPicked,
    required this.onPick,
  });

  final QuizQuestion question;
  final int index;
  final int total;
  final int? justPicked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${index + 1} / $total',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WatotoColors.sky,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            resolveContentKey(l10n, question.promptKey),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < question.count; i++)
                Text(question.emoji, style: const TextStyle(fontSize: 56)),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var i = 0; i < question.options.length; i++)
                SizedBox(
                  width: 88,
                  height: 88,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: justPicked == i
                          ? WatotoColors.mango
                          : WatotoColors.sky,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () => onPick(i),
                    child: Text(question.options[i].text),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizResultView extends StatelessWidget {
  const _QuizResultView({
    required this.grade,
    required this.onRetry,
    required this.onDone,
  });

  final QuizGrade grade;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            grade.passed ? '🎉' : '🌱',
            style: const TextStyle(fontSize: 96),
          ),
          const SizedBox(height: 16),
          Text(
            grade.passed ? l10n.greatJob : l10n.tryAgain,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.quizScore(grade.correct, grade.total),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (grade.passed) ...[
            const SizedBox(height: 8),
            Text('⭐' * grade.stars, style: const TextStyle(fontSize: 36)),
            Text(
              l10n.xpEarned(grade.xp),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: WatotoColors.mango,
              ),
            ),
          ],
          const SizedBox(height: 40),
          Wrap(
            spacing: 16,
            children: [
              if (!grade.passed)
                FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
              FilledButton(
                style: grade.passed
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: WatotoColors.deep,
                      ),
                onPressed: onDone,
                child: Text(l10n.done),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
