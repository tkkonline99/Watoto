/// A step that asks a question must offer an answer to it.
///
/// The sweep that found the mis-scored steps also found 125 that ask a real
/// question and were *already* plain taps: "Tap why the Nile mattered more
/// than anything else in Egypt" showed a picture and a continue button. They
/// were never mis-scored, so nothing failed — they were simply a gap nobody
/// had counted. 119 now carry authored options
/// (content/ask_comprehension_steps.py); the remaining six have no right
/// answer and are meant not to.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';

/// The only question-shaped taps allowed to offer nothing: three invite the
/// child to answer for themselves, three send them off the screen to do
/// something. Turning any of them into a quiz would be worse than leaving it.
const _noRightAnswer = {
  ('s01.lang.lesson.05', 2), // "Point with me. Tap what you see."
  ('s03.emotions.lesson.01', 3), // "...the face that matches how you feel"
  ('s04.semotional.lesson.04', 4), // "Tap how it felt."
  ('s06.tech.lesson.02', 6), // "Sort your own toys ... tap when done."
  ('s06.tech.lesson.04', 5), // "Make your own pattern ... tap when done."
  ('s07.health.lesson.06', 2), // "Tap the road when it is clear."
};

/// One per authoring batch, checked against the step's own feedback. The full
/// set is specified in content/ask_comprehension_steps.py; these are the
/// canaries that catch a bad re-run.
const _spotChecks = {
  ('s08.social.lesson.01', 4): 'It left rich soil',
  ('s08.science.lesson.06', 4): 'Push apart',
  ('s08.social.lesson.05', 4): 'A consumer',
  ('s09.science.lesson.05', 4): 'Far from the pivot',
  ('s09.reading.lesson.01', 3): 'A simile',
  ('s09.math.lesson.02', 5): 'The parts are unequal',
  ('s10.social.lesson.03', 5): 'It rises',
  ('s10.reading.lesson.02', 5): 'Good luck',
  ('s10.social.lesson.02', 4): 'The legislative',
};

final _directive = RegExp(
  r'\b(?:tap|touch|find|point to|pick|press|choose)\b([^.!?]*)',
  caseSensitive: false,
);
final _asks = RegExp(r'\b(?:why|what|which|how|where|when|whether)\b',
    caseSensitive: false);
final _quoted = RegExp(r"'[^']*'");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<LibraryItem> items;

  setUpAll(() async {
    final raw = await rootBundle.loadString(
      'assets/content/watoto_content_library.json',
    );
    final content =
        (jsonDecode(raw) as Map<String, dynamic>)['content'] as List;
    items = content
        .cast<Map<String, dynamic>>()
        .map(LibraryItem.fromJson)
        .toList();
  });

  test('every question-shaped tap offers an answer, or is one of the six', () {
    // A ratchet, not a sample: if a new lesson adds a question with nothing
    // to answer, this names it. It must never grow.
    final unanswerable = <String>[];
    for (final item in items) {
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        if (step.choices.isNotEmpty) continue;
        final plan = planStep(item: item, stepIndex: i, step: step);
        if (plan.mechanic != StepMechanic.tap) continue;
        final clause = _directive.firstMatch(step.narration)?.group(1);
        if (clause == null) continue;
        if (!_asks.hasMatch(clause.toLowerCase().replaceAll(_quoted, ' '))) {
          continue;
        }
        // An opposite pair answers its own question without authored
        // options — "Tap what goes down" stages down against up — and the
        // planner is still allowed to do that.
        if (choicePlanFor(item.id, i, step.narration) != null) continue;
        if (_noRightAnswer.contains((item.id, i))) continue;
        unanswerable.add('${item.id} step$i: "${step.narration}"');
      }
    }
    expect(unanswerable, isEmpty,
        reason: 'questions with nothing to answer:\n'
            '${unanswerable.take(20).join('\n')}');
  });

  test('the six with no right answer still have none', () {
    // The other direction: nobody should "fix" these by bolting a quiz on.
    final quizzed = <String>[];
    for (final (itemId, index) in _noRightAnswer) {
      final item = items.firstWhere((i) => i.id == itemId);
      if (item.steps[index].choices.isNotEmpty) {
        quizzed.add('$itemId step$index now has options, but the step has no '
            'right answer');
      }
    }
    expect(quizzed, isEmpty, reason: quizzed.join('\n'));
  });

  test('the authored answers still match their feedback', () {
    final wrong = <String>[];
    _spotChecks.forEach((where, answer) {
      final (itemId, index) = where;
      final item = items.firstWhere((i) => i.id == itemId);
      final plan = planStep(
        item: item,
        stepIndex: index,
        step: item.steps[index],
      );
      if (plan.mechanic != StepMechanic.multiChoice) {
        wrong.add('$itemId step$index: ${plan.mechanic.name}');
        return;
      }
      final scored = plan.choices[plan.choiceIndex];
      if (scored != answer) {
        wrong.add('$itemId step$index: scores "$scored", expected "$answer"');
      }
    });
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });
}
