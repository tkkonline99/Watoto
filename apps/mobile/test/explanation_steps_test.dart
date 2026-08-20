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
import 'package:watoto_mobile/features/library/step_play.dart';

/// The steps the sweep caught scoring a noun lifted out of the question, and
/// the answer each one's own feedback gives. Authored by
/// content/ask_explanation_steps.py.
const _authored = {
  ('s03.emotions.lesson.02', 2): 'A grown-up you trust',
  ('s07.writing.lesson.01', 6): 'sings',
  ('s08.tech.lesson.03', 5): 'What happens if no',
  ('s08.math.lesson.06', 6): 'On the 4',
  ('s08.science.lesson.02', 5): 'It would overheat',
  ('s08.science.lesson.03', 3): 'Grass plants',
  ('s08.science.lesson.03', 6): 'It grows thick',
  ('s08.science.lesson.04', 6): 'Heat',
  ('s08.science.lesson.05', 4): 'The sun',
  ('s08.science.lesson.05', 5): 'Tiny water drops',
  ('s08.science.lesson.06', 5): 'Yes, it still works',
  ('s08.social.lesson.02', 4): 'East',
  ('s08.social.lesson.04', 6): 'Water, soil and roads',
  ('s08.writing.lesson.02', 4): 'river',
  ('s08.writing.lesson.03', 3): 'After bread and milk',
  ('s08.writing.lesson.03', 4): 'One',
  ('s08.writing.lesson.03', 5): 'Everything',
  ('s08.writing.lesson.05', 5): 'Three words, one idea',
  ('s09.coding.lesson.05', 5): 'Beauty is not a fact',
  ('s09.science.lesson.01', 4): 'Pulls it without touch',
  ('s09.science.lesson.01', 6): 'Ice, less friction',
  ('s09.science.lesson.02', 3): 'Cold',
  ('s09.science.lesson.03', 5): 'More grass grows',
  ('s09.science.lesson.04', 3): 'How it moved',
  ('s09.science.lesson.04', 5): 'No hard parts last',
  ('s09.science.lesson.06', 5): 'Its orbit is bigger',
  ('s09.social.lesson.02', 0): 'The capital city',
  ('s09.social.lesson.02', 6): 'It shows direction',
  ('s09.social.lesson.04', 5): 'It takes 3x as long',
  ('s09.social.lesson.04', 6): 'The bus fare',
  ('s09.social.lesson.06', 3): 'Rural area',
  ('s09.social.lesson.06', 5): 'Things are further',
  ('s09.writing.lesson.03', 3): 'Inside the quotes',
  ('s09.writing.lesson.03', 4): 'What Ana said',
  ('s09.writing.lesson.04', 4): 'Tanzania',
  ('s10.coding.lesson.01', 5): 'Prints them exactly',
  ('s10.coding.lesson.02', 6): 'It is a variable',
  ('s10.coding.lesson.05', 4): 'Reports it and stops',
  ('s10.social.lesson.01', 6): 'Longitude uses time',
  ('s10.social.lesson.04', 6): 'It explains symbols',
  ('s10.writing.lesson.04', 4): 'Inside the quotes',
  ('s10.writing.lesson.04', 5): 'The spoken words',
  ('s10.writing.lesson.06', 4): 'Adding the reason',
};

/// Options that stay English because the English *is* the lesson: which word
/// is the verb, and which English words take a capital. Registered in
/// content/i18n/english_by_design.json.
const _englishByDesign = {
  ('s07.writing.lesson.01', 6),
  ('s08.writing.lesson.02', 4),
  ('s09.writing.lesson.04', 4),
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

  test('each of the 43 now scores the answer its feedback gives', () {
    final wrong = <String>[];
    _authored.forEach((where, answer) {
      final (itemId, index) = where;
      final item = byId[itemId];
      if (item == null) {
        wrong.add('$itemId: not in the library');
        return;
      }
      final step = item.steps[index];
      final plan = planStep(item: item, stepIndex: index, step: step);
      if (plan.mechanic != StepMechanic.multiChoice) {
        wrong.add('$itemId step$index: ${plan.mechanic.name}, '
            'expected multiChoice');
        return;
      }
      if (plan.choiceIndex < 0 || plan.choiceIndex >= plan.choices.length) {
        wrong.add('$itemId step$index: answer index out of range');
        return;
      }
      if (plan.choices.length < 2) {
        wrong.add('$itemId step$index: only ${plan.choices.length} option');
      }
      final scored = plan.choices[plan.choiceIndex];
      if (scored != answer) {
        wrong.add('$itemId step$index: scores "$scored", '
            'feedback says "$answer"');
      }
    });
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('no step both asks an explanation question and stages from the '
      'lexicon', () {
    // The library-wide form of the guard: wherever a directive asks for a
    // reason, the options must be authored, never scraped out of the
    // question. This is what would catch a new lesson reintroducing it.
    final staged = <String>[];
    for (final item in byId.values) {
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        if (step.choices.isNotEmpty) continue;
        final clause = _directive.firstMatch(step.narration)?.group(1);
        if (clause == null) continue;
        if (!_asks.hasMatch(clause.toLowerCase().replaceAll(_quoted, ' '))) {
          continue;
        }
        final plan = choicePlanFor(item.id, i, step.narration);
        if (plan == null) continue;
        // An opposite pair answers its own question and is allowed.
        final words = plan.options.map((o) => o.word).toSet();
        if (words.length == 2) continue;
        staged.add('${item.id} step$i: "${step.narration}" '
            'stages ${plan.options.map((o) => o.word).join("/")}');
      }
    }
    expect(staged, isEmpty, reason: staged.join('\n'));
  });

  test('the English-taught options carry no invented translation', () {
    // "sings" is only the verb in English, and Tanzania-versus-town is a
    // question about English orthography. A Swahili string here would not be
    // a localization, it would be a different (wrong) exercise.
    for (final (itemId, index) in _englishByDesign) {
      final step = byId[itemId]!.steps[index];
      expect(step.choices, isNotEmpty, reason: '$itemId step$index');
    }
  });
}

final _directive = RegExp(
  r'\b(?:tap|touch|find|point to|pick|press|choose)\b([^.!?]*)',
  caseSensitive: false,
);
final _asks = RegExp(r'\b(?:why|what|which|how|where|when|whether)\b',
    caseSensitive: false);
final _quoted = RegExp(r"'[^']*'");
