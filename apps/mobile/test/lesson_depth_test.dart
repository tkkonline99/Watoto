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

/// How deep a lesson has to be before it is teaching rather than gesturing.
///
/// Deliberately a function of the design tier, not one number for the library.
/// The 8-step figure came from the stage-7 pilot — children of 6 and 7, who
/// can follow a worked example and answer a recap. A one-year-old cannot, and
/// holding `parent-led` content to a stage-7 arc would produce lessons no baby
/// can sit through and no parent wants to read aloud. Tiers are defined in the
/// library's `_meta.designTiers`.
///
/// Keep in sync with MIN_STEPS_BY_TIER in content/worklist.js.
const minStepsByTier = <String, int>{
  'parent-led': 4, // ages 0-2: cozy, slow, the parent is the user
  'encourage-effort': 6, // ages 3-5
  'gamify-gently': 8, // ages 6-7
  'grant-autonomy': 8, // ages 8-10
};

int minStepsForTier(String? tier) => minStepsByTier[tier] ?? minSteps;

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

  // ---------------------------------------------------------------------
  // Library-wide. The pilot proved the shape on ten lessons; these hold the
  // other 332 to the part of it that can be checked mechanically.
  // ---------------------------------------------------------------------

  group('whole library', () {
    final lessons = library.values.where((i) => i.type == LibraryType.lesson);

    test('every lesson step declares its mechanic', () {
      final bare = <String>[];
      for (final item in lessons) {
        for (var i = 0; i < item.steps.length; i++) {
          final m = item.steps[i].mechanic?.trim();
          if (m == null || m.isEmpty) bare.add('${item.id} step $i');
        }
      }
      expect(
        bare,
        isEmpty,
        reason: 'these steps make the player guess the mechanic from English '
            'narration, so they stage a plain tap in sw/fr:\n'
            '${bare.take(20).join('\n')}\n'
            'run: dart run tool/bake_mechanics.dart',
      );
    });

    test('the player stages the same mechanic in every language', () {
      final drift = <String>[];
      for (final item in lessons) {
        for (var i = 0; i < item.steps.length; i++) {
          final en = planStep(
            item: item,
            stepIndex: i,
            step: _localized(item, i, overlays['en']!),
          );
          for (final lang in ['sw', 'fr']) {
            final other = planStep(
              item: item,
              stepIndex: i,
              step: _localized(item, i, overlays[lang]!),
            );
            if (other.mechanic != en.mechanic) {
              drift.add('${item.id} step $i: ${en.mechanic.name} in en but '
                  '${other.mechanic.name} in $lang');
            }
          }
        }
      }
      expect(
        drift,
        isEmpty,
        reason: 'a child in this language gets a visibly poorer lesson from '
            'the same JSON:\n${drift.take(20).join('\n')}',
      );
    });

    test('lessons reach the step depth their design tier calls for', () {
      final shallow = <String>[];
      for (final item in lessons) {
        final min = minStepsForTier(item.designTier);
        if (item.steps.length < min) {
          shallow.add('${item.id} (${item.designTier}): '
              '${item.steps.length} steps, needs $min');
        }
      }
      // Depth is being filled in stage by stage, priority order first. This
      // asserts the direction of travel: the count may fall, never rise.
      // Lower it as stages land; see docs/CONTENT_WORKLIST.md.
      // 332 before any of this; 302 after stage 1, 230 after stages 2 and 3,
      // 164 once stages 4 and 5 followed (content/author_stage{1..5}.py).
      const knownShallow = 164;
      expect(
        shallow.length,
        lessThanOrEqualTo(knownShallow),
        reason: 'more shallow lessons than the recorded baseline — a stage '
            'was flattened:\n${shallow.take(20).join('\n')}',
      );
    });
  });
}
