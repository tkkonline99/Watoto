import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/config/publish_config.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/quiz_review.dart';

/// A quiz that ends after a single tap cannot tell a child who knows the
/// material from one who guessed, and it hands the adaptive engine a single
/// noisy sample. The runtime top-up in `quiz_review.dart` borrows same-subject
/// recap questions to cover for that. These tests check it against the *real*
/// content file, not fixtures, because the whole claim is about what children
/// actually get.
///
/// The top-up was written when 140 of 166 quizzes asked one question. Authoring
/// has since taken stages 6 and 7 to four real questions each, and this file is
/// meant to notice when that work makes the top-up unnecessary rather than let
/// it keep padding quietly.
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
      localizedQuizQuestions(
        quiz: quiz,
        library: library,
        i18n: null,
        lang: lang,
        correctFeedback: 'Yes!',
        retryFeedback: 'Try again',
      );

  List<LibraryItem> quizzes() =>
      library.where((i) => i.type == LibraryType.quiz).toList();

  test('the library really is as thin as this fix assumes', () {
    // A tripwire, and it is meant to trip. When it does, the fix is NOT to
    // lower the number. It is to decide whether the top-up should still run
    // at all — a borrowed recap question is weaker than an authored one, and
    // it only earns its place while most quizzes have nothing else to offer.
    //
    // It counted every quiz in the library until stage 1 went to depth, and
    // that reading was wrong in a way worth recording. `canExpandQuiz` skips
    // `parent-led` outright, so the 31 thin quizzes in that band were never
    // candidates for the top-up at all. Stage 1 took the raw figure from 109
    // to 99 by fixing ten of them — it moved the tripwire without changing a
    // single quiz the mechanism touches. A tripwire measuring a population
    // its subject ignores will keep firing for reasons that have nothing to
    // do with the question it was asked to watch.
    //
    // So it now counts what the top-up can actually reach: expandable quizzes
    // in the stages that ship. 29 of 88, all of them stage 4 and stage 5, and
    // both are next in `_buildPlan.priorityOrder`. When those two land this
    // goes to roughly zero and the top-up should be deleted rather than
    // re-thresholded — at that point every shipping quiz carries its own
    // authored questions and borrowing is pure loss.
    final thin = quizzes()
        .where((q) => canExpandQuiz(q) && q.stage <= maxPublishedStage)
        .where((q) => q.questions.length <= 1)
        .length;
    expect(thin, greaterThan(20),
        reason: 'the top-up may have outlived its purpose — read the comment');
  });

  test('no quiz ever comes back shorter than it was authored', () {
    for (final quiz in quizzes()) {
      expect(play(quiz).length, greaterThanOrEqualTo(quiz.questions.length),
          reason: '${quiz.id} lost questions');
    }
  });

  test('short quizzes come back materially longer', () {
    // The denominator is quizzes that are *allowed* to expand and actually
    // need to. `canExpandQuiz` alone is a policy predicate — it says nothing
    // about length, so an authored four-question quiz passes it and then
    // correctly returns unchanged. Counting those as failures-to-improve made
    // this ratio fall every time a stage was authored properly, which is
    // backwards: the top-up doing nothing to a complete quiz is the point.
    final short = quizzes()
        .where(canExpandQuiz)
        .where((q) => q.questions.length < targetQuizQuestions)
        .toList();
    expect(short, isNotEmpty);

    var improved = 0;
    for (final quiz in short) {
      if (play(quiz).length > quiz.questions.length) improved++;
    }
    // Not every subject has authored recaps to draw on; most do.
    expect(
      improved / short.length,
      greaterThan(0.6),
      reason: 'only $improved of ${short.length} short quizzes got deeper',
    );
  });

  test('no quiz is stretched past the attention budget', () {
    for (final quiz in quizzes()) {
      expect(
        play(quiz).length,
        lessThanOrEqualTo(targetQuizQuestions),
        reason: '${quiz.id} is too long for this age band',
      );
    }
  });

  test('the youngest band is left exactly as authored', () {
    final parentLed =
        quizzes().where((q) => q.designTier == 'parent-led').toList();
    expect(parentLed, isNotEmpty);
    for (final quiz in parentLed) {
      expect(
        play(quiz).length,
        quiz.questions.length,
        reason: '${quiz.id} is a shared parent-and-child moment, not a round',
      );
    }
  });

  test('borrowed questions only ever come from the same stage and subject',
      () {
    // A Stage 7 fractions question inside a Stage 3 counting quiz is a wall.
    for (final quiz in quizzes().where(canExpandQuiz)) {
      final borrowed = play(quiz).skip(quiz.questions.length);
      if (borrowed.isEmpty) continue;

      final sameCell = library.where((i) =>
          i.type == LibraryType.lesson &&
          i.stage == quiz.stage &&
          i.subject == quiz.subject);
      final allowed = {
        for (final lesson in sameCell)
          for (final r in lesson.recap)
            if (r.isValid) r.prompt.trim(),
      };
      for (final q in borrowed) {
        expect(allowed, contains(q.prompt),
            reason: '${quiz.id} borrowed from outside its subject');
      }
    }
  });

  test('every played question is answerable', () {
    for (final quiz in quizzes()) {
      for (final q in play(quiz)) {
        expect(q.options.length, greaterThanOrEqualTo(2),
            reason: '${quiz.id}: "${q.prompt}" has no real choice');
        expect(q.answer, inInclusiveRange(0, q.options.length - 1),
            reason: '${quiz.id}: "${q.prompt}" answer index is out of range');
        expect(q.prompt.trim(), isNotEmpty);
        for (final o in q.options) {
          expect(o.label.trim(), isNotEmpty);
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
    // Children replay activities; a quiz that reshuffles itself would also
    // make the adaptive difficulty signal meaningless.
    for (final quiz in quizzes().take(40)) {
      expect(
        play(quiz).map((q) => q.prompt).toList(),
        play(quiz).map((q) => q.prompt).toList(),
      );
    }
  });

  test('quizzes in one subject do not all borrow the same lesson', () {
    // Three quizzes sharing a stage+subject should draw on different lessons,
    // or the second and third feel like reruns of the first.
    final bySubject = <String, List<LibraryItem>>{};
    for (final q in quizzes().where(canExpandQuiz)) {
      bySubject.putIfAbsent('${q.stage}|${q.subject}', () => []).add(q);
    }
    var checked = 0;
    for (final group in bySubject.values.where((g) => g.length >= 2)) {
      final firstBorrowed = [
        for (final quiz in group)
          play(quiz).skip(quiz.questions.length).map((q) => q.prompt).firstOrNull
      ].whereType<String>().toList();
      if (firstBorrowed.length < 2) continue;
      checked++;
      expect(firstBorrowed.toSet().length, greaterThan(1),
          reason: 'every quiz in a subject opened with the same review');
    }
    expect(checked, greaterThan(5), reason: 'not enough groups exercised');
  });

  test('Swahili and French sessions still get a full round', () {
    // Borrowed questions resolve through their *source lesson* i18n keys; get
    // that wrong and a Swahili child sees English review questions. With no
    // bundle loaded both fall back to the embedded English, so this checks the
    // shape holds rather than the wording.
    for (final lang in ['sw', 'fr']) {
      final expandable = quizzes().where(canExpandQuiz).take(30);
      for (final quiz in expandable) {
        expect(play(quiz, lang: lang).length, play(quiz).length,
            reason: '${quiz.id} is shorter in $lang');
      }
    }
  });
}
