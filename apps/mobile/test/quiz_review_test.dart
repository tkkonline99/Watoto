import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/quiz_review.dart';

/// 140 of 166 quizzes in the shipped library ask exactly one question. A quiz
/// that ends after a single tap cannot tell a child who knows the material
/// from one who guessed, and it hands the adaptive engine a single noisy
/// sample. These tests check the top-up against the *real* content file, not
/// fixtures, because the whole claim is about what children actually get.
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
    // If content authoring later fills these in, this fix is redundant and
    // should be reconsidered rather than left to pad quizzes silently.
    final single = quizzes().where((q) => q.questions.length <= 1).length;
    expect(single, greaterThan(100), reason: 'baseline: 140 of 166');
  });

  test('expandable quizzes come back materially longer', () {
    final expandable = quizzes().where(canExpandQuiz).toList();
    expect(expandable, isNotEmpty);

    var improved = 0;
    for (final quiz in expandable) {
      final before = quiz.questions.length;
      final after = play(quiz).length;
      expect(after, greaterThanOrEqualTo(before),
          reason: '${quiz.id} lost questions');
      if (after > before) improved++;
    }
    // Not every subject has authored recaps to draw on; most do.
    expect(
      improved / expandable.length,
      greaterThan(0.6),
      reason: 'only $improved of ${expandable.length} quizzes got deeper',
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
