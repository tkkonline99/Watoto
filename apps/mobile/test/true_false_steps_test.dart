/// A step that mentions truth must offer what it actually asks — and must not
/// be answered by word order.
///
/// `choicePlanFor` used to stage a two-card true/false pair whenever the tap
/// directive contained "true" or "false", taking whichever literal came first
/// as the answer. "Tap true or false: 7 is greater than 10." names true first,
/// so the step scored **true**: the child who reasoned correctly and tapped
/// false was marked wrong. The same branch fired on directives that only
/// mention truth — "Tap why that cannot be true", "Tap what happens on a false
/// test" — and handed them two cards that cannot answer a why or a what. The
/// pair was built as `ChoiceOption('true', 'true')`, so word and glyph were
/// identical and the card face was the raw English word, which a Swahili or
/// French child then had to read.
///
/// Three halves, guarded together because any one alone lets the bug back: the
/// planner must refuse, the content must supply real options, and those
/// options must be translated.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';

/// The steps that used to be staged from a truth-value literal, and the answer
/// each must score now. Every one is the step's own feedback.
const _corrected = {
  ('s08.science.lesson.05', 6): 'It is the same water',
  // Step 1 was not the planner's doing: it shipped the authored options
  // ["False", "3"], a choice between an answer and a stray digit.
  ('s09.coding.lesson.05', 1): 'False',
  ('s09.coding.lesson.05', 3): 'True',
  ('s09.coding.lesson.05', 4): 'False',
  ('s09.science.lesson.05', 6): 'Same work, less push',
  ('s10.coding.lesson.04', 5): 'Nothing happens',
  ('s10.coding.lesson.06', 6): 'Check a second source',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, LibraryItem> byId;
  late Map<String, Map<String, dynamic>> overlays;

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
    overlays = {
      for (final lang in ['sw', 'fr'])
        lang: jsonDecode(
          File('assets/i18n/$lang.json').readAsStringSync(),
        ) as Map<String, dynamic>,
    };
  });

  group('the planner refuses to answer a true/false question', () {
    // A bare id/step pair; the seed only fixes distractor order.
    const id = 'test.item';

    test('"true or false" is not an answer key', () {
      // The phrase names true first no matter what the answer is.
      expect(
        choicePlanFor(id, 0, 'Tap true or false: 7 is greater than 10.'),
        isNull,
      );
      expect(
        choicePlanFor(
          id,
          0,
          'Tap whether this is true or false: a spider has eight legs.',
        ),
        isNull,
      );
    });

    test('a directive that only mentions truth is not a true/false question',
        () {
      for (final narration in [
        'Someone said rain is new water. Tap why that cannot be true.',
        'Someone said this is less total work. Tap what is actually true.',
        'A rule has no else branch. Tap what happens on a false test.',
        'Tap the best way to check whether something online is true.',
      ]) {
        expect(choicePlanFor(id, 0, narration), isNull, reason: narration);
      }
    });

    test('an ordinary directive is still staged', () {
      // The refusal is narrow: only directives naming a truth value.
      final plan = choicePlanFor(id, 0, 'Tap the ball.');
      expect(plan, isNotNull);
      expect(plan!.options.length, greaterThanOrEqualTo(2));
    });
  });

  group('the steps that were mis-staged now ask what they mean to', () {
    test('each scores the answer its feedback gives', () {
      final wrong = <String>[];
      _corrected.forEach((where, answer) {
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

    test('every true/false step offers the same two cards', () {
      // The steps that genuinely ask this must still offer both — the fix is
      // to score the right one, not to drop the question. Step 0 was already
      // correct and is included as the pair the others are held to: a child
      // meeting a different second card on each step (once "3") has to work
      // out the interface again every time.
      final item = byId['s09.coding.lesson.05']!;
      for (final index in [0, 1, 3, 4]) {
        final plan = planStep(
          item: item,
          stepIndex: index,
          step: item.steps[index],
        );
        expect(plan.choices, ['True', 'False'], reason: 'step$index');
      }
    });
  });

  test('no answer card is left in English for a Swahili or French child', () {
    // The old pair put the literal "true"/"false" on the card in every
    // locale. Authored choices localize through `steps.N.choices.N`; a
    // missing key falls back to English, which is the bug returning.
    final untranslated = <String>[];
    _corrected.forEach((where, _) {
      final (itemId, index) = where;
      final step = byId[itemId]!.steps[index];
      for (var option = 0; option < step.choices.length; option++) {
        final key = '$itemId.steps.$index.choices.$option';
        final english = step.choices[option];
        for (final lang in ['sw', 'fr']) {
          final text = overlays[lang]![key];
          if (text == null) {
            untranslated.add('$lang: $key is missing');
          } else if (text == english) {
            untranslated.add('$lang: $key is still "$english"');
          }
        }
      }
    });
    expect(untranslated, isEmpty, reason: untranslated.join('\n'));
  });
}
