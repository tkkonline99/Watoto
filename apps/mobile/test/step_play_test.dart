import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';

void main() {
  group('extractNumericAnswer', () {
    test('long division step 1 feedback', () {
      expect(
        extractNumericAnswer('2. Write it above the 8.', 'how many 4s in 8?'),
        2,
      );
    });

    test('prefers leading step answer over final quotient', () {
      // Bug: kids answered 1 for 4÷4 but we used to expect 21 from the end.
      expect(
        extractNumericAnswer(
          '1. So 84 ÷ 4 = 21. You used D-M-S-B!',
          'Step 4 — Divide 4 ÷ 4, then finish.',
        ),
        1,
      );
    });

    test('equation result when no leading N. token', () {
      expect(
        extractNumericAnswer(
          '8 - 8 = 0. Bring down the 4.',
          'Multiply 2 × 4',
        ),
        0,
      );
    });

    test('how many pattern', () {
      expect(
        extractNumericAnswer('', 'how many 4s in 8?'),
        2,
      );
    });

    test('product from = ?', () {
      expect(extractNumericAnswer('24!', '6 × 4 = ?'), 24);
    });
  });

  group('explicit mechanic', () {
    test('buildArray from schema', () {
      final plan = planStep(
        item: const LibraryItem(
          id: 'arr',
          stage: 6,
          ages: '',
          subject: 'Math & Logic',
          type: LibraryType.lesson,
          title: 'Arrays',
          objective: '',
          designTier: '',
          reading: true,
          interaction: 'tap',
        ),
        stepIndex: 0,
        step: const LessonStep(
          narration: 'Build it',
          action: 'go',
          feedback: 'Nice',
          mechanic: 'buildArray',
          rows: 2,
          cols: 3,
        ),
      );
      expect(plan.mechanic, StepMechanic.buildArray);
      expect(plan.rows, 2);
      expect(plan.cols, 3);
      expect(plan.answer, 6);
    });
  });

  group('code plans', () {
    test('name AND age is twoLines, not message chips', () {
      final plan = planStep(
        item: const LibraryItem(
          id: 's10.coding.lesson.01',
          stage: 10,
          ages: '9-10',
          subject: 'Coding',
          type: LibraryType.lesson,
          title: 'Your First Python: print()',
          objective: '',
          designTier: 'A',
          reading: false,
          interaction: 'code-run',
        ),
        stepIndex: 2,
        step: const LessonStep(
          narration:
              'Challenge: print your name AND your age on two lines.',
          action: 'code-run',
          feedback: 'Two print() lines make two lines of output.',
        ),
      );
      expect(plan.codeChallenge, 'twoLines');
      expect(plan.promptHint, contains('name'));
      expect(plan.promptHint, contains('age'));
      expect(plan.messageChoices, isNotEmpty);
    });

    test('print lesson becomes token build + run', () {
      final plan = planStep(
        item: const LibraryItem(
          id: 's10.coding.lesson.01',
          stage: 10,
          ages: '9-10',
          subject: 'Coding',
          type: LibraryType.lesson,
          title: 'Your First Python: print()',
          objective: '',
          designTier: 'A',
          reading: false,
          interaction: 'code-run',
          steps: [
            LessonStep(
              narration: 'Type:  print("Hello, world!")  then press RUN.',
              action: 'code-run',
              feedback: 'Output box shows: Hello, world!',
            ),
          ],
        ),
        stepIndex: 0,
        step: const LessonStep(
          narration: 'Type:  print("Hello, world!")  then press RUN.',
          action: 'code-run',
          feedback: 'Output box shows: Hello, world!',
        ),
      );
      expect(plan.mechanic, StepMechanic.codeRun);
      expect(plan.codeChallenge, 'print');
      expect(plan.outputLine, 'Hello, world!');
      expect(plan.codeTokens, isNotEmpty);
      expect(plan.codeTokens.first, 'print');
    });
  });

  group('planStep', () {
    test('long division uses number answer + workspace', () {
      const item = LibraryItem(
        id: 's10.math.lesson.01',
        stage: 10,
        ages: '9-10',
        subject: 'Math',
        type: LibraryType.lesson,
        title: 'Long Division, Step by Step',
        objective: '',
        designTier: 'A',
        reading: false,
        interaction: 'guided-steps',
        steps: [
          LessonStep(
            narration: 'Solve 84 ÷ 4. Step 1 — Divide: how many 4s in 8?',
            action: 'input',
            feedback: '2. Write it above the 8.',
          ),
        ],
      );
      final plan = planStep(
        item: item,
        stepIndex: 0,
        step: item.steps.first,
      );
      expect(plan.mechanic, StepMechanic.numberAnswer);
      expect(plan.answer, 2);
      expect(plan.workspace, isNotNull);
      expect(plan.workspace!.dividend, 84);
      expect(plan.workspace!.divisor, 4);
      expect(plan.choices, isNotEmpty);
      expect(plan.choices, contains('2'));
    });
  });
}
