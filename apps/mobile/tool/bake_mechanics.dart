/// Writes each lesson step's resolved mechanic into the content library.
///
/// `planStep` falls back to English keyword heuristics ("how many", "trace",
/// "rows of") when a step declares no `mechanic`. Those regexes do not match
/// the Swahili or French narration for the same step, so a translated lesson
/// silently collapses to a plain tap and a child gets a poorer lesson than an
/// English one from the same JSON.
///
/// The fix is to run the heuristics once, here, against the English text and
/// record the answer in the schema. `_planFromExplicit` then short-circuits
/// the regexes and every locale stages the mechanic the author intended.
///
///   dart run tool/bake_mechanics.dart            # rewrite the library
///   dart run tool/bake_mechanics.dart --dry-run  # report only
///
/// Deliberately *not* baked:
///  - `multiChoice`, whose options `comprehensionCheck` generates from the
///    English narration and lexicon. Freezing those into the shared library
///    would put English words in front of a Swahili child — worse than the
///    fallback it replaces. Those steps stay bare and are reported instead;
///    they need `prompt` + `choices` authored per locale.
///  - anything already carrying an explicit `mechanic`.
///
/// Only locale-neutral parameters travel with the mechanic (`answer`, `count`,
/// `rows`, `cols` — all numbers). Prompt and choice *text* never does.
library;

import 'dart:convert';
import 'dart:io';

import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';

const _libPath = 'assets/content/watoto_content_library.json';

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final file = File(_libPath);
  if (!file.existsSync()) {
    stderr.writeln('run me from apps/mobile — $_libPath not found');
    exit(1);
  }

  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final content = root['content'] as List<dynamic>;

  var baked = 0;
  var skippedExplicit = 0;
  var skippedMultiChoice = 0;
  final byMechanic = <String, int>{};
  final needsAuthoring = <String>[];

  for (final raw in content) {
    final map = raw as Map<String, dynamic>;
    if (map['type'] != 'lesson') continue;
    final steps = map['steps'] as List<dynamic>?;
    if (steps == null) continue;

    final item = LibraryItem.fromJson(map);

    for (var i = 0; i < steps.length; i++) {
      final stepMap = steps[i] as Map<String, dynamic>;
      final existing = (stepMap['mechanic'] as String?)?.trim();
      if (existing != null && existing.isNotEmpty) {
        skippedExplicit++;
        continue;
      }

      final plan = planStep(
        item: item,
        stepIndex: i,
        step: LessonStep.fromJson(stepMap),
      );

      if (plan.mechanic == StepMechanic.multiChoice) {
        // Locale-unsafe: the options came from English text. Leave it bare.
        skippedMultiChoice++;
        needsAuthoring.add('${map['id']}.steps.$i');
        continue;
      }

      final name = plan.mechanic.name;
      byMechanic[name] = (byMechanic[name] ?? 0) + 1;
      baked++;
      if (dryRun) continue;

      stepMap['mechanic'] = name;
      switch (plan.mechanic) {
        case StepMechanic.numberAnswer:
          if (plan.answer != null) stepMap['answer'] = plan.answer;
        case StepMechanic.count:
          stepMap['count'] = plan.count;
        case StepMechanic.buildArray:
          stepMap['rows'] = plan.rows;
          stepMap['cols'] = plan.cols;
          if (plan.answer != null) stepMap['answer'] = plan.answer;
        // Nothing to bake beyond the name. buildCircuit carries a mode, but
        // `planStep` reads it back off the narration on every play
        // (`_circuitModeFrom`) rather than storing it, so there is no field
        // here to write.
        case StepMechanic.tap:
        case StepMechanic.drag:
        case StepMechanic.celebrate:
        case StepMechanic.codeRun:
        case StepMechanic.explain:
        case StepMechanic.multiChoice:
        case StepMechanic.buildCircuit:
          break;
      }
    }
  }

  if (!dryRun) {
    // Two-space indent + trailing newline matches the file already in git, so
    // the diff is the mechanics and nothing else.
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(root)}\n');
  }

  stdout.writeln(dryRun ? '(dry run — nothing written)' : 'wrote $_libPath');
  stdout.writeln('baked          : $baked');
  stdout.writeln('already explicit: $skippedExplicit');
  stdout.writeln('left bare (multiChoice, needs per-locale authoring): $skippedMultiChoice');
  final names = byMechanic.keys.toList()..sort();
  for (final n in names) {
    stdout.writeln('  $n: ${byMechanic[n]}');
  }
  if (needsAuthoring.isNotEmpty) {
    File('build/steps_needing_choices.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('${needsAuthoring.join('\n')}\n');
    stdout.writeln('listed the bare steps in build/steps_needing_choices.txt');
  }
}
