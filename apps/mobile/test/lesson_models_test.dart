import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_models.dart';

const sampleJson = '''
{
  "id": "5d3f1a2b-9c4e-4f6a-8b7d-1e2f3a4b5c6d",
  "schema": "watoto.lesson/1.0",
  "titleKey": "lessonCountingTitle",
  "blocks": [
    { "type": "concept", "textKey": "lessonCountingTitle", "emoji": "🥭" },
    { "type": "tap_to_count", "items": 3 },
    { "type": "check", "promptKey": "checkAnswerPrompt",
      "options": [
        { "text": "2", "correct": false },
        { "text": "3", "correct": true }
      ] }
  ],
  "completion": { "rewards": { "xp": 10, "stars": 1 }, "skills": ["counting.1-10"] }
}
''';

void main() {
  test('parses a watoto.lesson/1.0 body', () {
    final lesson =
        LessonBody.fromJson(jsonDecode(sampleJson) as Map<String, dynamic>);

    expect(lesson.id, '5d3f1a2b-9c4e-4f6a-8b7d-1e2f3a4b5c6d');
    expect(lesson.schema, 'watoto.lesson/1.0');
    expect(lesson.blocks, hasLength(3));
    expect(lesson.blocks[0], isA<ConceptBlock>());
    expect(lesson.blocks[1], isA<TapToCountBlock>());
    expect((lesson.blocks[1] as TapToCountBlock).items, 3);

    final check = lesson.blocks[2] as CheckBlock;
    expect(check.options.where((o) => o.correct), hasLength(1));

    expect(lesson.completion.xp, 10);
    expect(lesson.completion.skills, contains('counting.1-10'));
  });

  test('rejects unknown block types', () {
    expect(
      () => LessonBlock.fromJson(const {'type': 'mystery'}),
      throwsFormatException,
    );
  });
}
