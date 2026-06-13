import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/quiz/quiz_models.dart';

const sampleQuizJson = '''
{
  "id": "8c1d2e3f-4a5b-4c6d-8e7f-9a0b1c2d3e4f",
  "schema": "watoto.quiz/1.0",
  "titleKey": "quizCountingTitle",
  "passPct": 70,
  "xpByStars": [10, 15, 20],
  "questions": [
    { "id": "q1", "promptKey": "quizHowMany", "emoji": "☀️", "count": 1,
      "options": [ {"text":"1","correct":true}, {"text":"2","correct":false} ] },
    { "id": "q2", "promptKey": "quizHowMany", "emoji": "🐘", "count": 2,
      "options": [ {"text":"1","correct":false}, {"text":"2","correct":true} ] },
    { "id": "q3", "promptKey": "quizHowMany", "emoji": "🥭", "count": 3,
      "options": [ {"text":"2","correct":false}, {"text":"3","correct":true} ] }
  ]
}
''';

QuizBody parse() =>
    QuizBody.fromJson(jsonDecode(sampleQuizJson) as Map<String, dynamic>);

void main() {
  test('parses a watoto.quiz/1.0 body', () {
    final quiz = parse();
    expect(quiz.id, '8c1d2e3f-4a5b-4c6d-8e7f-9a0b1c2d3e4f');
    expect(quiz.passPct, 70);
    expect(quiz.questions, hasLength(3));
    expect(quiz.questions[1].count, 2);
    expect(quiz.questions[2].options.last.correct, isTrue);
  });

  test('perfect attempt: 100%, 3 stars, top xp', () {
    final grade = parse().grade([0, 1, 1]);
    expect(grade.correct, 3);
    expect(grade.scorePct, 100);
    expect(grade.passed, isTrue);
    expect(grade.stars, 3);
    expect(grade.xp, 20);
  });

  test('2 of 3 (67%) fails a 70% gate — no stars, no xp', () {
    final grade = parse().grade([0, 1, 0]);
    expect(grade.scorePct, 67);
    expect(grade.passed, isFalse);
    expect(grade.stars, 0);
    expect(grade.xp, 0);
  });

  test('out-of-range picks never count', () {
    final grade = parse().grade([5, -1, 0]);
    expect(grade.correct, 0);
  });
}
