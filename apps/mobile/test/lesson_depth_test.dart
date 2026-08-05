library;

/// Guards content depth: the stage-7 pilot, and then the whole library.
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
///
/// The library-wide groups at the bottom then hold all three item types to a
/// depth their design tier calls for. Lessons had that ratchet from the start;
/// quizzes and stories did not, and it showed — five stages were certified
/// "done" on lesson depth alone while their quizzes sat at one question and
/// every story in the library sat at exactly three pages.
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

/// How many questions a quiz needs before it is assessing rather than gesturing.
///
/// Same shape of reasoning as [minStepsByTier], and the same refusal to use one
/// number for the whole library. A `parent-led` quiz is a grown-up holding up
/// two pictures and asking which is the dog; four of those is a chore. From
/// `gamify-gently` up the child answers alone, and a single two-option question
/// tells you nothing — a coin flip reads as mastery, and the adaptive resolver
/// then moves them on the strength of it.
///
/// Keep in sync with MIN_QUESTIONS_BY_TIER in content/worklist.js.
const minQuestionsByTier = <String, int>{
  'parent-led': 2, // ages 0-2
  'encourage-effort': 3, // ages 3-5
  'gamify-gently': 4, // ages 6-7
  'grant-autonomy': 4, // ages 8-10
};

int minQuestionsForTier(String? tier) => minQuestionsByTier[tier] ?? 4;

/// How many pages a story needs before it is a story.
///
/// Every story in the library shipped at exactly three pages, which is setup
/// and stop: something happens, and it is over. Page count is not a quality
/// measure and this test does not pretend otherwise — but below about five
/// there is no room for a problem to appear, be attempted, and resolve, and
/// that arc is most of what a story is doing for a child this age.
///
/// Keep in sync with MIN_PAGES_BY_TIER in content/worklist.js.
const minPagesByTier = <String, int>{
  'parent-led': 4, // ages 0-2: board-book length, read aloud
  'encourage-effort': 5, // ages 3-5
  'gamify-gently': 6, // ages 6-7
  'grant-autonomy': 6, // ages 8-10
};

int minPagesForTier(String? tier) => minPagesByTier[tier] ?? 6;

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
      // 164 once stages 4 and 5 followed, 134 with stage 6, 108 with stage 7
      // (content/author_stage{1..7}.py).
      const knownShallow = 108;
      expect(
        shallow.length,
        lessThanOrEqualTo(knownShallow),
        reason: 'more shallow lessons than the recorded baseline — a stage '
            'was flattened:\n${shallow.take(20).join('\n')}',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Quizzes and stories. The lesson ratchet above ran alone for five stages
  // and, because "stage N is done" was measured by it, five stages were
  // called done while their quizzes stayed at one question and every story
  // in the library stayed at three pages. Lessons are a third of the item
  // types; a ratchet that only guards them certifies a third of the work.
  // ---------------------------------------------------------------------

  group('quiz depth', () {
    final quizzes = library.values.where((i) => i.type == LibraryType.quiz);

    test('quizzes reach the question count their design tier calls for', () {
      final shallow = <String>[];
      for (final item in quizzes) {
        final min = minQuestionsForTier(item.designTier);
        if (item.questions.length < min) {
          shallow.add('${item.id} (${item.designTier}): '
              '${item.questions.length} questions, needs $min');
        }
      }
      // Same ratchet rule as the lessons: may fall, never rise.
      // 172 of 199 when this test was written — including every stage the
      // lesson ratchet had already certified as done. 157 of 204 after
      // stage 6, 139 of 210 after stage 7, 129 once stage 1 took its own ten
      // shipped quizzes from one question to two (content/author_stage1.py),
      // 105 after stage 4 and 85 after stage 5 — every shipping stage now
      // carries its authored question count, and the rest is stages 8-10.
      const knownShallow = 85;
      expect(
        shallow.length,
        lessThanOrEqualTo(knownShallow),
        reason: 'more shallow quizzes than the recorded baseline:\n'
            '${shallow.take(20).join('\n')}',
      );
    });

    test('every question offers at least two distinct, non-empty options', () {
      final bad = <String>[];
      for (final item in quizzes) {
        for (var i = 0; i < item.questions.length; i++) {
          final q = item.questions[i];
          final labels = q.options.map((o) => o.label.trim()).toList();
          if (labels.length < 2) {
            bad.add('${item.id} q$i has ${labels.length} option(s)');
          } else if (labels.toSet().length != labels.length) {
            bad.add('${item.id} q$i repeats an option — two answers look '
                'equally right');
          } else if (labels.any((l) => l.isEmpty)) {
            bad.add('${item.id} q$i has a blank option');
          }
          if (q.answer < 0 || q.answer >= labels.length) {
            bad.add('${item.id} q$i marks an answer that does not exist');
          }
        }
      }
      expect(bad, isEmpty, reason: bad.take(20).join('\n'));
    });

    test('sw and fr get their own questions, not the English ones', () {
      final untranslated = <String>[];
      for (final item in quizzes) {
        for (var i = 0; i < item.questions.length; i++) {
          final key = '${item.id}.questions.$i.prompt';
          for (final lang in ['sw', 'fr']) {
            final got = overlays[lang]![key];
            if (got == null || got == item.questions[i].prompt) {
              untranslated.add('$key ($lang)');
            }
          }
        }
      }
      // Ratchet, not a clean bill: the backlog is real and shrinking.
      const knownUntranslated = 0;
      expect(
        untranslated.length,
        lessThanOrEqualTo(knownUntranslated),
        reason: 'these questions would show English to a sw/fr child:\n'
            '${untranslated.take(20).join('\n')}',
      );
    });
  });

  group('story depth', () {
    final stories = library.values.where((i) => i.type == LibraryType.story);

    test('stories reach the page count their design tier calls for', () {
      final shallow = <String>[];
      for (final item in stories) {
        final min = minPagesForTier(item.designTier);
        if (item.pages.length < min) {
          shallow.add('${item.id} (${item.designTier}): '
              '${item.pages.length} pages, needs $min');
        }
      }
      // 85 of 85 when this test was written — the whole story library was
      // exactly three pages long, in every stage, including the done ones.
      // 80 of 90 after stage 6, 74 of 96 after stage 7, 64 once stage 1's ten
      // stories each grew the fourth page (content/author_stage1.py), 52 after
      // stage 4 and 42 after stage 5. What is left is stages 2, 3 and 8-10.
      const knownShallow = 42;
      expect(
        shallow.length,
        lessThanOrEqualTo(knownShallow),
        reason: 'more shallow stories than the recorded baseline:\n'
            '${shallow.take(20).join('\n')}',
      );
    });

    test('every page carries narration', () {
      final blank = <String>[];
      for (final item in stories) {
        for (var i = 0; i < item.pages.length; i++) {
          if (item.pages[i].narration.trim().isEmpty) {
            blank.add('${item.id} page $i');
          }
        }
      }
      expect(blank, isEmpty, reason: blank.join('\n'));
    });

    test('sw and fr get their own pages, not the English ones', () {
      final untranslated = <String>[];
      for (final item in stories) {
        for (var i = 0; i < item.pages.length; i++) {
          final key = '${item.id}.pages.$i.narration';
          for (final lang in ['sw', 'fr']) {
            final got = overlays[lang]![key];
            if (got == null || got == item.pages[i].narration) {
              untranslated.add('$key ($lang)');
            }
          }
        }
      }
      const knownUntranslated = 0;
      expect(
        untranslated.length,
        lessThanOrEqualTo(knownUntranslated),
        reason: 'these pages would show English to a sw/fr child:\n'
            '${untranslated.take(20).join('\n')}',
      );
    });
  });
}
