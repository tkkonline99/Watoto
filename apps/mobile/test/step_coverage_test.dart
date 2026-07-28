library;

/// Corpus-wide guarantees for what a child actually sees on a lesson step.
///
/// These run over every lesson step in `watoto_content_library.json`, so new
/// content cannot quietly ship a step that shows a meaningless picture or
/// promises a gesture the player does not stage.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_art.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';
import 'package:watoto_mobile/features/library/step_visuals.dart';

List<LibraryItem> _lessons() {
  final raw =
      File('assets/content/watoto_content_library.json').readAsStringSync();
  final content =
      (jsonDecode(raw) as Map<String, dynamic>)['content'] as List<dynamic>;
  return [
    for (final e in content)
      if ((e as Map<String, dynamic>)['type'] == 'lesson')
        LibraryItem.fromJson(e),
  ];
}

void main() {
  final lessons = _lessons();

  test('the corpus is actually loaded', () {
    expect(lessons, isNotEmpty);
    expect(
      lessons.fold<int>(0, (n, i) => n + i.steps.length),
      greaterThan(700),
      reason: 'sanity: the library should cover ~747 lesson steps',
    );
  });

  test('every step shows a real illustration', () {
    final bad = <String>[];
    for (final item in lessons) {
      for (final step in item.steps) {
        final art = stepIllustration(item: item, narration: step.narration);
        // '⭐' used to be the shrug — "no idea what this step is about". It is
        // still legitimate when the step really is about a star, which is
        // exactly when the lexicon picks it from the narration.
        final deliberateStar = illustrationFor(step.narration) == '⭐';
        if (art.trim().isEmpty || (art == '⭐' && !deliberateStar)) {
          bad.add('${item.id}: "${step.narration}" -> "$art"');
        }
      }
    }
    expect(bad, isEmpty, reason: 'steps with no meaningful picture:\n'
        '${bad.take(20).join('\n')}');
  });

  test('every subject in the library has its own illustration', () {
    final unmapped = <String>{
      for (final item in lessons)
        if (!subjectEmojis.containsKey(item.subject)) item.subject,
    };
    expect(
      unmapped,
      isEmpty,
      reason: 'add these to subjectEmojis in step_visuals.dart: $unmapped',
    );
  });

  test('no step promises a gesture the player does not stage', () {
    // Narration verbs that commit to something other than a plain tap.
    final promises = <String, RegExp>{
      'swipe': RegExp(r'\bswipe\b', caseSensitive: false),
      'slide': RegExp(r'\bslide\b', caseSensitive: false),
      'draw': RegExp(r'\b(draw|paint)\b', caseSensitive: false),
      'shake': RegExp(r'\bshake\b', caseSensitive: false),
      'wave': RegExp(r'\bwave\b', caseSensitive: false),
      'breathe': RegExp(r'\b(breathe|blow)\b', caseSensitive: false),
      'clap': RegExp(r'\b(clap|stomp|dance)\b', caseSensitive: false),
      'sing': RegExp(r'\b(sing|hum)\b', caseSensitive: false),
    };

    final bad = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        final plan = planStep(item: item, stepIndex: i, step: step);
        if (plan.mechanic != StepMechanic.tap) continue;
        // A staged multiple choice is a real question, not a bare tap.
        if (choicePlanFor(item.id, i, step.narration) != null) continue;

        for (final entry in promises.entries) {
          if (entry.value.hasMatch(step.narration)) {
            bad.add('${item.id} step$i promises ${entry.key}: '
                '"${step.narration}"');
            break;
          }
        }
      }
    }
    expect(bad, isEmpty, reason: 'gesture/mechanic mismatches:\n'
        '${bad.take(20).join('\n')}');
  });

  test('no step shows an anonymous prompt', () {
    // A prompt must name what to do. "Tap the picture", "Tap to play", "Tap
    // when you are ready" teach a child to poke at random — they are the thing
    // this guard exists to keep out, in any wording.
    final anonymous = RegExp(
      r'tap\s+(the\s+)?'
      r'(picture|screen|image|it|here|thing|them|they|one|each|all)\s*!?$'
      r'|tap\s+to\s+play'
      r'|tap\s+when\s+you'
      r'|tap\s+anywhere'
      r'|^tap!?$',
      caseSensitive: false,
    );

    final bad = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        final plan = planStep(item: item, stepIndex: i, step: step);
        final hint = plan.promptHint;
        final match = hint == null ? null : anonymous.firstMatch(hint);
        if (match == null) continue;

        // One legitimate exception: the word IS the lesson's subject, which
        // this content marks by SHOUTING it ("The SCREEN is where we see and
        // tap. Tap the screen."). Then naming it is the right prompt.
        final target = match.group(2);
        if (target != null &&
            RegExp('\\b${target.toUpperCase()}\\b').hasMatch(step.narration)) {
          continue;
        }
        bad.add('${item.id} step$i: "$hint" <- "${step.narration}"');
      }
    }
    expect(bad, isEmpty, reason: 'anonymous prompts:\n${bad.take(20).join('\n')}');
  });

  test('a tap step is only staged when the narration asks for a tap', () {
    // Otherwise the step is exposition and belongs on the explain stage. This
    // is deliberately a weaker rule than the planner's (which also requires
    // the verb to be imperative): the guard should catch a step staged as a
    // tap when its sentence contains no action at all.
    final directive = RegExp(
      r'\b(tap|touch|press|find|point to|pick|choose|show me'
      r'|pop|mix|pour|push|pull|roll|ring|knock|squeeze|stack|build|match'
      r'|sort|read|open|close|feed|wash|catch|put|place|move)\b',
      caseSensitive: false,
    );
    final bad = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        final plan = planStep(item: item, stepIndex: i, step: step);
        if (plan.mechanic != StepMechanic.tap) continue;
        if (!directive.hasMatch(step.narration)) {
          bad.add('${item.id} step$i: "${step.narration}"');
        }
      }
    }
    expect(bad, isEmpty, reason: 'taps with nothing to tap:\n'
        '${bad.take(20).join('\n')}');
  });

  test('every comprehension check is answerable and well formed', () {
    final bad = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final plan = planStep(item: item, stepIndex: i, step: item.steps[i]);
        if (plan.mechanic != StepMechanic.multiChoice) continue;
        final o = plan.choices;
        final where = '${item.id} step$i $o';
        if (o.length < 2) bad.add('$where: needs at least two options');
        if (plan.choiceIndex < 0 || plan.choiceIndex >= o.length) {
          bad.add('$where: answer index ${plan.choiceIndex} out of range');
          continue;
        }
        final lower = o.map((e) => e.toLowerCase()).toList();
        if (lower.toSet().length != o.length) bad.add('$where: duplicate options');
        if (o.any((e) => e.trim().isEmpty)) bad.add('$where: blank option');
        if (o.any((e) => e.length > 22)) bad.add('$where: option too long');
      }
    }
    expect(bad, isEmpty, reason: bad.take(20).join('\n'));
  });

  test('the worked-example step that shipped a dead "Got it!" now asks a '
      'question', () {
    // Regression: s10.math.lesson.02 step 0 showed a picture and a passive
    // continue button, so nobody could tell whether the child understood.
    final item = lessons.firstWhere((i) => i.id == 's10.math.lesson.02');
    final plan = planStep(item: item, stepIndex: 0, step: item.steps[0]);
    expect(plan.mechanic, StepMechanic.multiChoice);
    expect(plan.choices.length, greaterThanOrEqualTo(2));
    expect(plan.choices[plan.choiceIndex], '80 and 12');
  });

  test('every lesson step past the parent-led stage asks the child something',
      () {
    // A passive continue button tells nobody whether the child understood, so
    // steps the planner cannot make checkable carry authored `choices` in
    // watoto_content_library.json instead.
    //
    // Stage 1 is the deliberate exception: those lessons are parent-led and
    // the child is pre-verbal (0–1). A grown-up reads the line and does the
    // action with the baby; offering "Under the cloth / All gone" would be a
    // question to the parent, not a check on the child.
    final passive = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final plan = planStep(item: item, stepIndex: i, step: item.steps[i]);
        if (plan.mechanic == StepMechanic.explain && item.stage > 1) {
          passive.add('${item.id} (stage ${item.stage}) step$i: '
              '"${item.steps[i].narration}"');
        }
      }
    }
    expect(passive, isEmpty, reason: 'steps with nothing to answer:\n'
        '${passive.take(20).join('\n')}');
  });

  test('the answer is not always in the same slot', () {
    // Children learn "it is always the first one" astonishingly fast.
    final positions = <int, int>{};
    var total = 0;
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final plan = planStep(item: item, stepIndex: i, step: item.steps[i]);
        if (plan.mechanic != StepMechanic.multiChoice) continue;
        positions[plan.choiceIndex] = (positions[plan.choiceIndex] ?? 0) + 1;
        total++;
      }
    }
    expect(total, greaterThan(50));
    for (final entry in positions.entries) {
      expect(
        entry.value / total,
        lessThan(0.7),
        reason: 'slot ${entry.key} holds the answer ${entry.value}/$total times',
      );
    }
  });

  test('no option is a fragment chopped out of its sentence', () {
    // A length cap once matched a prefix instead of failing, shipping
    // "the message behind th" as an answer.
    final bad = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        final source = '${step.narration} ${step.feedback}';
        for (final option in step.choices) {
          final at = source.indexOf(option);
          if (at < 0) continue;
          final after = at + option.length;
          if (after < source.length && RegExp(r'[A-Za-z]').hasMatch(source[after])) {
            bad.add('${item.id} step$i: "$option" cuts a word in "$source"');
          }
        }
      }
    }
    expect(bad, isEmpty, reason: bad.take(20).join('\n'));
  });

  test('a staged word choice asks for a word that is actually in the step', () {
    // "Tap to say 'I'm sorry.'" once staged the letter "i" — the apostrophe
    // inside "I'm" closed the quote — and its mutations reached children as
    // the buttons "ie" / "o" / "i". Single letters and digits are legitimate
    // (alphabet and number lessons), so the test is not about length: the
    // answer has to be a word the narration actually contains.
    final bad = <String>[];
    for (final item in lessons) {
      for (var i = 0; i < item.steps.length; i++) {
        final step = item.steps[i];
        final plan = choicePlanFor(item.id, i, step.narration);
        if (plan == null) continue;
        final answer = plan.options[plan.targetIndex].emoji;
        // Emoji targets illustrate a named object and never appear literally.
        // Keycaps like "7️⃣" start with an ASCII digit, so the whole string
        // has to be plain text — not just its first character.
        if (!RegExp(r"^[A-Za-z0-9 '-]+$").hasMatch(answer)) continue;
        final present = RegExp(
          '(^|[^A-Za-z0-9])${RegExp.escape(answer)}([^A-Za-z0-9]|\$)',
          caseSensitive: false,
        ).hasMatch(step.narration);
        if (!present) {
          bad.add('${item.id} step$i: staged "$answer" but the step says '
              '"${step.narration}"');
        }
      }
    }
    expect(bad, isEmpty, reason: 'invented answers:\n${bad.take(20).join('\n')}');
  });

  test('bundled artwork is only used for the ages it depicts', () {
    // The starter pack is baby art; it must never illustrate an older stage.
    final bad = <String>[];
    for (final item in lessons) {
      final art = artAssetForItem(item);
      if (art != null && item.stage > 3) {
        bad.add('${item.id} (stage ${item.stage}, "${item.title}") -> $art');
      }
    }
    expect(bad, isEmpty, reason: 'baby art on older activities:\n'
        '${bad.take(20).join('\n')}');
  });
}
