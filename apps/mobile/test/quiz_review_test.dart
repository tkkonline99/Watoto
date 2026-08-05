import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/quiz_review.dart';

/// What is left of the quiz top-up's test suite.
///
/// This file used to check a borrowing mechanism: when a quiz was too thin to
/// assess anything, `quiz_review.dart` filled it out with authored recap
/// questions from lessons in the same subject. Most of these tests existed to
/// keep that borrowing honest — same stage and subject only, no duplicated
/// prompts, deterministic order, translated in every language.
///
/// The borrowing is gone, because authoring finished. Every quiz in the
/// library now carries the question count its design tier calls for, so the
/// top-up returned early for all 228 of them and was deleted rather than left
/// dormant. The tests that exercised it went with it.
///
/// What remains is the part that was never about borrowing: a quiz's own
/// questions have to be answerable, and they have to arrive in the child's
/// language. Plus one test holding the finished state, so that a quiz falling
/// back below its tier fails here rather than quietly playing thin.
void main() {
  late List<LibraryItem> library;

  setUpAll(() {
    final raw = File('assets/content/watoto_content_library.json')
        .readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    library = [
      for (final item in json['content'] as List)
        LibraryItem.fromJson((item as Map).cast<String, dynamic>()),
    ];
  });

  List<LibQuestion> play(LibraryItem quiz, {String lang = 'en'}) =>
      localizedQuizQuestions(quiz: quiz, i18n: null, lang: lang);

  List<LibraryItem> quizzes() =>
      library.where((i) => i.type == LibraryType.quiz).toList();

  test('no quiz in the library is below its tier depth', () {
    // The state the whole content effort was aiming at, held here so it cannot
    // be lost quietly. `lesson_depth_test.dart` guards the same line from the
    // content side; this guards it from the side that plays it, and is the
    // reason the top-up could be deleted at all.
    final thin = quizzes()
        .where((q) => q.questions.length < targetQuestionsFor(q))
        .map((q) => '${q.id} (${q.designTier}): ${q.questions.length} of '
            '${targetQuestionsFor(q)}')
        .toList();
    expect(
      thin,
      isEmpty,
      reason: 'a quiz fell below its tier depth. There is no top-up to cover '
          'for it any more — author the questions:\n${thin.join('\n')}',
    );
  });

  test('a quiz plays exactly the questions it was authored with', () {
    for (final quiz in quizzes()) {
      expect(
        play(quiz).length,
        quiz.questions.length,
        reason: '${quiz.id} played a different number of questions than it '
            'declares',
      );
    }
  });

  test('every played question is answerable', () {
    for (final quiz in quizzes()) {
      for (final q in play(quiz)) {
        expect(q.options.length, greaterThanOrEqualTo(2),
            reason: '${quiz.id}: "${q.prompt}" has no real choice');
        expect(q.answer, inInclusiveRange(0, q.options.length - 1),
            reason: '${quiz.id}: "${q.prompt}" answer index is out of range');
        expect(q.prompt.trim(), isNotEmpty, reason: quiz.id);
        for (final o in q.options) {
          expect(o.label.trim(), isNotEmpty, reason: quiz.id);
        }
      }
    }
  });

  test('a quiz never asks the same thing twice', () {
    for (final quiz in quizzes()) {
      final prompts =
          play(quiz).map((q) => q.prompt.toLowerCase().trim()).toList();
      expect(prompts.toSet().length, prompts.length,
          reason: '${quiz.id} repeats a question');
    }
  });

  test('the same quiz plays the same way twice', () {
    for (final quiz in quizzes().take(40)) {
      final a = play(quiz).map((q) => q.prompt).toList();
      final b = play(quiz).map((q) => q.prompt).toList();
      expect(a, b, reason: '${quiz.id} is not deterministic');
    }
  });

  test('Swahili and French sessions still get a full round', () {
    for (final lang in ['sw', 'fr']) {
      for (final quiz in quizzes().take(40)) {
        expect(
          play(quiz, lang: lang).length,
          play(quiz).length,
          reason: '${quiz.id} plays a different number of questions in $lang',
        );
      }
    }
  });
}
