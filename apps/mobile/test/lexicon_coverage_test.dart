import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/library_models.dart';

/// Locks the lexicon's real coverage over the shipped content library so it
/// can only go up: how many lesson steps stage a multiple choice, and how
/// many get a content-derived illustration at all. If a content drop or a
/// lexicon edit drops these below the floor, this fails and prints the shape
/// of the regression.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'choice and illustration coverage stay above the measured floor',
    () async {
      final raw = await rootBundle.loadString(
        'assets/content/watoto_content_library.json',
      );
      final items = ((jsonDecode(raw) as Map)['content'] as List)
          .map((c) => LibraryItem.fromJson(c as Map<String, dynamic>))
          .toList();

      var steps = 0;
      var choice = 0;
      var illustrated = 0;
      for (final item in items) {
        for (var i = 0; i < item.steps.length; i++) {
          steps++;
          final narration = item.steps[i].narration;
          if (choicePlanFor(item.id, i, narration) != null) {
            choice++;
            illustrated++;
          } else if (illustrationFor(narration) != null) {
            illustrated++;
          }
        }
      }

      // ignore: avoid_print
      print(
        'lexicon coverage: $choice/$steps steps stage a choice, '
        '$illustrated/$steps illustrated '
        '(${(100 * illustrated / steps).round()}%)',
      );

      expect(steps, greaterThan(700));
      // Floors measured on the v0.13 library (choice 186, illustrated 76%);
      // set slightly below so routine content edits don't flake.
      expect(choice, greaterThanOrEqualTo(180));
      expect(illustrated / steps, greaterThanOrEqualTo(0.72));
    },
  );

  test('every choice plan is well-formed and deterministic', () async {
    final raw = await rootBundle.loadString(
      'assets/content/watoto_content_library.json',
    );
    final items = ((jsonDecode(raw) as Map)['content'] as List)
        .map((c) => LibraryItem.fromJson(c as Map<String, dynamic>))
        .toList();

    for (final item in items) {
      for (var i = 0; i < item.steps.length; i++) {
        final plan = choicePlanFor(item.id, i, item.steps[i].narration);
        if (plan == null) continue;
        expect(plan.options, hasLength(3), reason: '${item.id} step $i');
        expect(plan.targetIndex, inInclusiveRange(0, 2));
        // Options must be visually distinct or the choice is unanswerable.
        final emoji = plan.options.map((o) => o.emoji).toSet();
        expect(emoji, hasLength(3), reason: '${item.id} step $i: $emoji');
        // Same step, same plan — stable across replays.
        final again = choicePlanFor(item.id, i, item.steps[i].narration)!;
        expect(again.targetIndex, plan.targetIndex);
        expect(
          [for (final o in again.options) o.emoji],
          [for (final o in plan.options) o.emoji],
        );
      }
    }
  });
}
