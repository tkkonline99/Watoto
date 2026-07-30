library;

/// Guards the stage-7 depth pilot (content/deepen_stage7.py).
///
/// The library is wide and shallow: 342 lessons share about 750 steps, most of
/// them a single tap. Ten stage-7 lessons were rewritten into 8–10 step teaching
/// arcs as a pilot. These tests keep that pilot from being flattened again by a
/// content regeneration, and — more importantly — check the two things that
/// silently break a deepened lesson:
///
///  1. the player must stage the mechanic the author intended, and
///  2. it must do so in Swahili and French, not only in English.
///
/// (2) is the subtle one. `planStep` falls back to reading the step text when a
/// step declares no mechanic, and those heuristics are English keyword matches
/// ("how many", "trace", "rows of"). A translated lesson misses them and every
/// step collapses to a plain tap, so a Swahili child gets a visibly poorer
/// lesson than an English one from the same JSON.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';

/// The pilot set. Keep in sync with LESSONS in content/deepen_stage7.py.
const deepenedIds = <String>[
  's07.math.lesson.02',
  's07.math.lesson.03',
  's07.math.lesson.04',
  's07.math.lesson.06',
  's07.reading.lesson.01',
  's07.reading.lesson.03',
  's07.reading.lesson.06',
  's07.writing.lesson.03',
  's07.science.lesson.02',
  's07.health.lesson.02',
];

const minSteps = 8;
const langs = ['en', 'sw', 'fr'];

Map<String, LibraryItem> _library() {
  final raw =
      File('assets/content/watoto_content_library.json').readAsStringSync();
  final content =
      (jsonDecode(raw) as Map<String, dynamic>)['content'] as List<dynamic>;
  return {
    for (final e in content)
      (e as Map<String, dynamic>)['id'] as String: LibraryItem.fromJson(e),
  };
}

Map<String, Map<String, String>> _overlays() {
  final out = <String, Map<String, String>>{};
  for (final lang in langs) {
    final raw = File('assets/i18n/$lang.json').readAsStringSync();
    out[lang] = (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, '$v'));
  }
  return out;
}

/// Rebuilds a step as the given language actually delivers it: overlay text
/// where present, English from the library where not. This is what the child
/// in that language plays.
LessonStep _localized(
  LibraryItem item,
  int i,
  Map<String, String> overlay,
) {
  final step = item.steps[i];
  String t(String suffix, String fallback) =>
      overlay['${item.id}.steps.$i.$suffix'] ?? fallback;
  return LessonStep(
    narration: t('narration', step.narration),
    action: step.action,
    feedback: t('feedback', step.feedback),
    mechanic: step.mechanic,
    prompt: step.prompt == null ? null : t('prompt', step.prompt!),
    answer: step.answer,
    choices: [
      for (var o = 0; o < step.choices.length; o++)
        t('choices.$o', step.choices[o]),
    ],
    choiceIndex: step.choiceIndex,
    count: step.count,
    rows: step.rows,
    cols: step.cols,
  );
}

void main() {
  final library = _library();
  final overlays = _overlays();

  test('the pilot lessons are all present', () {
    for (final id in deepenedIds) {
      expect(library[id], isNotNull, reason: '$id vanished from the library');
    }
  });

  test('each pilot lesson is at least $minSteps steps deep', () {
    for (final id in deepenedIds) {
      expect(
        library[id]!.steps.length,
        greaterThanOrEqualTo(minSteps),
        reason: '$id was flattened — re-run content/deepen_stage7.py',
      );
    }
  });

  test('every pilot step declares its mechanic explicitly', () {
    for (final id in deepenedIds) {
      final steps = library[id]!.steps;
      for (var i = 0; i < steps.length; i++) {
        expect(
          steps[i].mechanic,
          isNotNull,
          reason: '$id step $i has no mechanic, so the player must guess from '
              'English text and will guess wrong in sw/fr',
        );
      }
    }
  });

  test('the player stages the authored mechanic, in every language', () {
    for (final id in deepenedIds) {
      final item = library[id]!;
      for (var i = 0; i < item.steps.length; i++) {
        final want = item.steps[i].mechanic;
        for (final lang in langs) {
          final plan = planStep(
            item: item,
            stepIndex: i,
            step: _localized(item, i, overlays[lang]!),
          );
          expect(
            plan.mechanic.name,
            want,
            reason: '$id step $i plays as ${plan.mechanic.name} in $lang '
                'but was authored as $want',
          );
        }
      }
    }
  });

  test('a step that asks a question offers real options in every language', () {
    for (final id in deepenedIds) {
      final item = library[id]!;
      for (var i = 0; i < item.steps.length; i++) {
        if (item.steps[i].mechanic != 'multiChoice') continue;
        for (final lang in langs) {
          final step = _localized(item, i, overlays[lang]!);
          expect(step.choices.length, greaterThanOrEqualTo(2),
              reason: '$id step $i in $lang');
          expect(
            step.choices.toSet().length,
            step.choices.length,
            reason: '$id step $i in $lang has a duplicated option, so two '
                'answers look equally right',
          );
          for (final c in step.choices) {
            expect(c.trim(), isNotEmpty, reason: '$id step $i in $lang');
          }
          expect(step.choiceIndex, isNotNull, reason: '$id step $i');
          expect(step.choiceIndex! < step.choices.length, isTrue,
              reason: '$id step $i marks an answer that does not exist');
        }
      }
    }
  });

  test('sw and fr are translated, not silently falling back to English', () {
    for (final id in deepenedIds) {
      final item = library[id]!;
      for (var i = 0; i < item.steps.length; i++) {
        for (final lang in ['sw', 'fr']) {
          final key = '$id.steps.$i.narration';
          expect(
            overlays[lang]!.containsKey(key),
            isTrue,
            reason: 'missing $key — that step would show English to a '
                '$lang-speaking child',
          );
          expect(
            overlays[lang]![key],
            isNot(item.steps[i].narration),
            reason: '$key is identical to the English line',
          );
        }
      }
    }
  });

  test('numeric answers are answerable', () {
    for (final id in deepenedIds) {
      final item = library[id]!;
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        if (step.mechanic != 'numberAnswer') continue;
        expect(step.answer, isNotNull,
            reason: '$id step $i asks for a number with no answer recorded');
        expect(step.answer, greaterThanOrEqualTo(0), reason: '$id step $i');
      }
    }
  });
}
