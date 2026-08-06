/// The four questions after the circuit builder must be answerable.
///
/// Steps 3–6 of s10.science.lesson.01 each ask something real — what happens
/// when the loop is cut, which material closes a gap, what is missing, why a
/// switch goes *in* the wire — and every one was a bare `tap` on the item's
/// emoji. The child tapped a picture of a battery to "answer" a question about
/// a bulb, and could not get it wrong.
///
/// This works against the shipped library rather than a fixture: the point is
/// that *those* steps ask *those* questions, which a synthetic item could not
/// show.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/circuit_figures.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/play_stages.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/step_play.dart';

const _lessonId = 's10.science.lesson.01';

/// The steps that ask, and how many options each offers.
const _questions = {3: 2, 4: 3, 5: 3, 6: 2};

Future<LibraryItem> _loadLesson() async {
  final raw = await rootBundle.loadString(
    'assets/content/watoto_content_library.json',
  );
  final content = (jsonDecode(raw) as Map<String, dynamic>)['content'] as List;
  final json = content.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == _lessonId,
      );
  return LibraryItem.fromJson(json);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LibraryItem lesson;

  setUpAll(() async {
    lesson = await _loadLesson();
  });

  test('each follow-up step stages a real choice with a drawn option', () {
    for (final entry in _questions.entries) {
      final index = entry.key;
      final step = lesson.steps[index];
      final plan = planStep(item: lesson, stepIndex: index, step: step);
      final where = '$_lessonId step $index';

      expect(plan.mechanic, StepMechanic.multiChoice, reason: where);
      expect(plan.choices.length, entry.value, reason: where);
      expect(
        plan.figures.length,
        plan.choices.length,
        reason: '$where: every option needs its own picture',
      );
      expect(
        plan.choiceIndex,
        inInclusiveRange(0, plan.choices.length - 1),
        reason: where,
      );
      for (final id in plan.figures) {
        expect(
          circuitFigureFor(id),
          isNotNull,
          reason: '$where: "$id" is not a figure anything can draw',
        );
      }
    }
  });

  test('the answers are the ones the feedback gives', () {
    // The correct option has to agree with the step's own feedback, or the
    // lesson marks a child wrong for believing what it just told them.
    const expected = {
      3: 'The bulb goes out.',
      4: 'Metal',
      5: 'The battery',
      6: 'It can break the loop.',
    };
    for (final entry in expected.entries) {
      final step = lesson.steps[entry.key];
      final plan = planStep(
        item: lesson,
        stepIndex: entry.key,
        step: step,
      );
      expect(
        plan.choices[plan.choiceIndex],
        entry.value,
        reason: '$_lessonId step ${entry.key} marks the wrong option correct',
      );
    }
  });

  testWidgets('a drawn option renders its diagram and its caption',
      (tester) async {
    final plan = ChoicePlan(
      const [
        ChoiceOption('The bulb stays lit.', 'The bulb stays lit.',
            figure: CircuitFigure.loopLit),
        ChoiceOption('The bulb goes out.', 'The bulb goes out.',
            figure: CircuitFigure.loopCut),
      ],
      1,
    );
    var completed = 0;
    var wrong = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: ChoiceStage(
              plan: plan,
              onCompleted: () => completed++,
              onWrong: () => wrong++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircuitFigureView), findsNWidgets(2));
    expect(find.text('The bulb stays lit.'), findsOneWidget);
    expect(find.text('The bulb goes out.'), findsOneWidget);

    // The lit loop is the wrong answer here, and picking it must say so
    // rather than advance.
    await tester.tap(find.text('The bulb stays lit.'));
    await tester.pumpAndSettle();
    expect(completed, 0);
    expect(wrong, 1);

    await tester.tap(find.text('The bulb goes out.'));
    await tester.pumpAndSettle();
    expect(completed, 1);
  });
}
