/// Every stage-10 science question must be answerable, and answerable
/// correctly.
///
/// An audit of the six lessons found two faults. Fourteen steps asked a real
/// question as a bare `tap`, so the player showed the item's emoji and
/// "answering" meant touching it — nothing could be got wrong. Three were
/// worse: `choicePlanFor` stages look-alike objects for a directive like "Tap
/// the drum", which is right for naming a thing and wrong for asking why
/// something happens, so it read the nouns out of the sentence and marked
/// them correct. "Tap what a rolling ball's motion energy becomes" scored the
/// ball; the answer is heat.
///
/// This runs against the shipped library, because the point is that *those*
/// lessons ask answerable questions — a fixture could not show it.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/circuit_figures.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';

/// Mechanics that legitimately have no options: an explanation, a celebration,
/// a number pad, a drag, or the circuit board.
const _optionless = {
  StepMechanic.explain,
  StepMechanic.celebrate,
  StepMechanic.numberAnswer,
  StepMechanic.drag,
  StepMechanic.buildCircuit,
  StepMechanic.count,
  StepMechanic.codeRun,
  StepMechanic.buildArray,
};

/// The three that used to score the wrong option, and what they must score
/// now. Each is the answer the step's own feedback gives.
const _corrected = {
  ('s10.science.lesson.02', 5): 'Its orbit is bigger.',
  ('s10.science.lesson.03', 5): 'Heat',
  ('s10.science.lesson.05', 5): 'Into the air.',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<LibraryItem> lessons;

  setUpAll(() async {
    final raw = await rootBundle.loadString(
      'assets/content/watoto_content_library.json',
    );
    final content =
        (jsonDecode(raw) as Map<String, dynamic>)['content'] as List;
    lessons = content
        .cast<Map<String, dynamic>>()
        .where((c) =>
            (c['id'] as String).startsWith('s10.science.') &&
            c['type'] == 'lesson')
        .map(LibraryItem.fromJson)
        .toList();
  });

  test('the six lessons are all present', () {
    expect(lessons.length, 6);
  });

  test('no step asks a question with nothing to answer it', () {
    final dead = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        final plan = planStep(item: item, stepIndex: i, step: step);
        if (_optionless.contains(plan.mechanic)) continue;
        final staged = plan.mechanic == StepMechanic.tap
            ? choicePlanFor(item.id, i, step.narration)?.options.length ?? 0
            : plan.choices.length;
        if (staged < 2) {
          dead.add('${item.id} step $i (${plan.mechanic.name}): '
              '"${step.narration}"');
        }
      }
    }
    expect(dead, isEmpty, reason: 'these cannot be got wrong:\n'
        '${dead.join('\n')}');
  });

  test('the three that scored the wrong option now score the right one', () {
    for (final entry in _corrected.entries) {
      final item = lessons.firstWhere((l) => l.id == entry.key.$1);
      final index = entry.key.$2;
      final plan =
          planStep(item: item, stepIndex: index, step: item.steps[index]);
      expect(
        plan.mechanic,
        StepMechanic.multiChoice,
        reason: '${item.id} step $index fell back to the lexicon again',
      );
      expect(
        plan.choices[plan.choiceIndex],
        entry.value,
        reason: '${item.id} step $index marks the wrong option correct',
      );
    }
  });

  test('every option picture resolves to something drawable', () {
    final bad = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final figures = item.steps[i].figures;
        if (figures.isEmpty) continue;
        final where = '${item.id} step $i';
        if (figures.length != item.steps[i].choices.length) {
          bad.add('$where: ${figures.length} pictures for '
              '${item.steps[i].choices.length} options');
          continue;
        }
        for (final id in figures) {
          if (id.isEmpty) continue;
          if (circuitFigureFor(id) == null && illustrationFor(id) == null) {
            bad.add('$where: "$id" draws nothing');
          }
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('a step either pictures every option or none of them', () {
    // A row where one card has a picture and the next has only words reads as
    // a bug, and gives the pictured option unearned weight.
    final mixed = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final figures = item.steps[i].figures;
        if (figures.isEmpty) continue;
        final drawn = figures.where((f) => f.isNotEmpty).length;
        if (drawn != 0 && drawn != figures.length) {
          mixed.add('${item.id} step $i: $drawn of ${figures.length}');
        }
      }
    }
    expect(mixed, isEmpty, reason: mixed.join('\n'));
  });
}
