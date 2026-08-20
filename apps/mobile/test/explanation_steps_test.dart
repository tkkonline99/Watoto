/// A step asking for a reason must not be answered with a noun out of its own
/// question.
///
/// `choicePlanFor` answers "which of these things is it" by staging a noun and
/// its look-alikes. A directive asking *why*, *what … actually is*, *where* or
/// *which of these claims* has no such answer, so the scan reached into the
/// question and staged a word from it:
///
///   * "Tap what lifts the water and drives the whole cycle" offered
///     autumn / rain / **water** and scored `water`. The step's own feedback
///     reads "The sun."
///   * "Tap where the big hand goes" offered eye / ear / **hand** — body parts,
///     for a question whose answer is "on the 4".
///   * "Tap why most big cities grew up beside rivers" scored `rivers`.
///
/// A child who knew the answer had no way to express it, and was scored on
/// tapping the subject of the question instead. The planner now refuses these,
/// which drops the step to a plain tap until real options are authored for it.
///
/// Two shapes must survive the refusal, and both are covered below: a quoted
/// spelling target whose own word is a question word ("Tap 'Where'"), and an
/// opposite pair, which genuinely is answered by a word in the question
/// ("Tap what goes down").
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/library_models.dart';

/// Steps the sweep caught scoring a noun lifted out of the question, with the
/// answer each step's feedback actually gives. None may stage a choice until
/// that answer is authored as an option.
const _mustNotStage = {
  ('s08.science.lesson.05', 4): 'The sun',
  ('s08.science.lesson.05', 5): 'water cooled into drops',
  ('s08.math.lesson.06', 6): 'on the 4',
  ('s08.social.lesson.02', 4): 'East',
  ('s08.social.lesson.04', 6): 'water, soil and transport',
  ('s09.science.lesson.02', 3): 'cold',
  ('s09.science.lesson.06', 5): 'a bigger orbit',
  ('s03.emotions.lesson.02', 2): 'a person, not an emotion',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, LibraryItem> byId;

  setUpAll(() async {
    final raw = await rootBundle.loadString(
      'assets/content/watoto_content_library.json',
    );
    final content =
        (jsonDecode(raw) as Map<String, dynamic>)['content'] as List;
    byId = {
      for (final c in content.cast<Map<String, dynamic>>())
        c['id'] as String: LibraryItem.fromJson(c),
    };
  });

  group('the planner refuses a question it cannot answer', () {
    const id = 'test.item';

    test('why / what / where / which directives stage nothing', () {
      for (final narration in [
        'Tap why most big cities grew up beside rivers.',
        'Tap what a cloud actually is.',
        'Tap what lifts the water and drives the whole cycle.',
        'Set the clock to 3:20. Tap where the big hand goes.',
        'Tap which to put in a budget first: the bus fare, or a comic.',
        'Tap what would happen if you moved the polar bear to the desert.',
        'Tap how many commas a list of three things needs.',
      ]) {
        expect(choicePlanFor(id, 0, narration), isNull, reason: narration);
      }
    });

    test('a question wrapped around a quote is still a question', () {
      // The quote must not smuggle the step past the guard.
      expect(
        choicePlanFor(id, 0, "The light is not red. Tap what an 'else' "
            'branch is for.'),
        isNull,
      );
    });
  });

  group('the refusal does not take the shapes that do work', () {
    const id = 'test.item';

    test("a spelling target that is itself a question word still stages", () {
      // "Tap 'Where'" teaches the spelling of the word; the interrogative is
      // inside the quotes, so it is the answer rather than the question.
      final plan = choicePlanFor(
        id,
        0,
        "Questions often start with a question word. Tap 'Where'.",
      );
      expect(plan, isNotNull);
      expect(plan!.options[plan.targetIndex].word, 'where');
    });

    test('an opposite pair answers its own question', () {
      // "what goes down" IS answered by a word in the question, so this one
      // shape survives.
      final plan = choicePlanFor(
        id,
        0,
        'This balloon goes up. Tap what goes down.',
      );
      expect(plan, isNotNull);
      expect(plan!.options[plan.targetIndex].word, 'down');
      expect(plan.options.map((o) => o.word), containsAll(['up', 'down']));
    });

    test('an ordinary directive is untouched', () {
      final plan = choicePlanFor(id, 0, 'Tap the ball.');
      expect(plan, isNotNull);
      expect(plan!.options.length, greaterThanOrEqualTo(2));
    });
  });

  test('no library step scores a noun taken from its own question', () {
    final scored = <String>[];
    _mustNotStage.forEach((where, answer) {
      final (itemId, index) = where;
      final item = byId[itemId];
      if (item == null) {
        scored.add('$itemId: not in the library');
        return;
      }
      final step = item.steps[index];
      // Authored choices are the fix; until then nothing may be staged.
      if (step.choices.isNotEmpty) return;
      final plan = choicePlanFor(itemId, index, step.narration);
      if (plan != null) {
        scored.add('$itemId step$index scores '
            '"${plan.options[plan.targetIndex].word}" for '
            '"${step.narration}" — the answer is $answer');
      }
    });
    expect(scored, isEmpty, reason: scored.join('\n'));
  });
}
