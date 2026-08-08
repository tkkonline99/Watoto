/// A step about a fraction, a time or a decimal must offer *that*, not the
/// first digit inside it.
///
/// `choicePlanFor` falls back to "tap the number N" when a directive names no
/// lexicon noun, pulling N out with `\b(\d{1,3})\b`. `\b` treats `/`, `:` and
/// `.` as word boundaries, so the scan read the numerator of a fraction and
/// staged a question about it: "Tap the fraction equal to 1/2: 3/6, 2/5, or
/// 4/9" showed keycaps 8/2/1 and scored the child on tapping **1**, while the
/// three fractions it actually offers went unstaged. The same fallback also
/// invented distractors by counting up, which turned "Tap the equator (0
/// degrees)" into a choice between 0, 1 and 2.
///
/// Two halves, guarded here together because either alone lets the bug back:
/// the planner must refuse to stage these, and the content must supply real
/// options.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';

/// The steps that used to stage a digit chopped out of a compound number (or,
/// for the last two, the subject of the question rather than its answer), and
/// the answer each must score now. Every one is the step's own feedback.
const _corrected = {
  ('s10.math.lesson.03', 6): '3/6',
  ('s10.math.lesson.05', 4): '0.6',
  ('s10.math.lesson.05', 6): '1/4',
  ('s08.math.lesson.06', 0): '2:15',
  ('s09.math.lesson.03', 0): '1/2',
  ('s09.math.lesson.03', 4): '3/4',
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

  group('the planner refuses to invent a number question', () {
    // A bare id/step pair; the seed only fixes distractor order.
    const id = 'test.item';

    test('a digit inside a fraction is not a tappable number', () {
      expect(choicePlanFor(id, 0, 'Tap the fraction equal to 1/2.'), isNull);
    });

    test('a digit inside a time is not a tappable number', () {
      expect(choicePlanFor(id, 0, "It's 2:15. Tap 2:15."), isNull);
    });

    test('a digit inside a decimal is not a tappable number', () {
      expect(choicePlanFor(id, 0, 'Tap the larger number: 0.6 or 0.59.'),
          isNull);
    });

    test('a lone number with nothing to contrast it is not a question', () {
      // "Tap the equator (0 degrees)" — the distractors used to be 1 and 2,
      // counted up from the answer, which is not a geography question.
      expect(choicePlanFor(id, 0, 'Tap the equator (0 degrees).'), isNull);
    });

    test('a number the step really names is still staged', () {
      // The fallback is not being switched off — only stopped from guessing.
      final plan = choicePlanFor(id, 0, 'Ten and 3 more is 13. Tap 13.');
      expect(plan, isNotNull);
      expect(plan!.options[plan.targetIndex].word, 'number 13');
      expect(plan.options.length, greaterThanOrEqualTo(2));
    });

    test('"Tap the number 3" still stages keycaps', () {
      final plan = choicePlanFor(id, 0, 'Tap the number 3.');
      expect(plan, isNotNull);
      expect(plan!.options[plan.targetIndex].emoji, '3️⃣');
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
        final scored = plan.choices[plan.choiceIndex];
        if (scored != answer) {
          wrong.add('$itemId step$index: scores "$scored", '
              'feedback says "$answer"');
        }
        // The options have to be the thing asked about, not a digit out of it.
        if (plan.choices.length < 2) {
          wrong.add('$itemId step$index: only ${plan.choices.length} option');
        }
      });
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });

    test('every offered option appears in the step, so none is invented', () {
      // A distractor a child has never seen teaches nothing. Each option must
      // be a number the narration or feedback works with, or a same-shaped
      // near miss of the answer (same denominator, same hour).
      final unexplained = <String>[];
      _corrected.forEach((where, answer) {
        final (itemId, index) = where;
        final item = byId[itemId]!;
        final step = item.steps[index];
        final source = '${step.narration} ${step.feedback}';
        for (final option in step.choices) {
          if (source.contains(option)) continue;
          // Same family as the answer: shares a denominator, or an hour.
          final parts = option.split(RegExp(r'[/:.]'));
          final answerParts = answer.split(RegExp(r'[/:.]'));
          if (parts.length == answerParts.length &&
              parts.length > 1 &&
              (parts.last == answerParts.last ||
                  parts.first == answerParts.first)) {
            continue;
          }
          unexplained.add('$itemId step$index: "$option" is not in the step '
              'and is not a near miss of "$answer"');
        }
      });
      expect(unexplained, isEmpty, reason: unexplained.join('\n'));
    });
  });
}
