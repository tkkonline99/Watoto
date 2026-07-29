import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_visuals.dart';

/// The content library declares 372 unique image refs and ships 14 of them, so
/// almost every activity is illustrated by the emoji ladder in step_visuals
/// rather than by drawn art. That makes the ladder's *specificity* the real
/// measure of how illustrated this app is.
///
/// Before the pattern rules, 58 steps fell all the way through to their
/// subject's stock picture — every written sum ("6 + 3 = 9"), every rounding
/// step, and most of the reading-comprehension vocabulary, because the
/// word-list rules could not express "a digit, a plus sign, a digit".
void main() {
  late List<LibraryItem> library;

  setUpAll(() {
    final json = jsonDecode(
      File('assets/content/watoto_content_library.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    library = [
      for (final i in json['content'] as List)
        LibraryItem.fromJson((i as Map).cast<String, dynamic>()),
    ];
  });

  Map<IllustrationTier, int> tally() {
    final counts = {for (final t in IllustrationTier.values) t: 0};
    for (final item in library) {
      for (final step in item.steps) {
        final d =
            stepIllustrationDetail(item: item, narration: step.narration);
        counts[d.tier] = counts[d.tier]! + 1;
      }
    }
    return counts;
  }

  test('almost every step gets a picture about that step', () {
    final counts = tally();
    final total = counts.values.reduce((a, b) => a + b);
    final specific = counts[IllustrationTier.lexicon]! +
        counts[IllustrationTier.topic]!;
    expect(
      specific / total,
      greaterThan(0.95),
      reason: 'specific art fell to ${(100 * specific / total).round()}%',
    );
  });

  test('the generic subject fallback stays rare', () {
    final counts = tally();
    expect(
      counts[IllustrationTier.subject],
      lessThanOrEqualTo(12),
      reason: 'was 58 before the pattern rules; do not let it drift back',
    );
  });

  test('written arithmetic is illustrated as arithmetic', () {
    // The case that motivated the pattern rules: sums are written with
    // symbols, and no word-list rule can see them.
    const item = LibraryItem(
      id: 't',
      stage: 5,
      ages: '6-7',
      subject: 'Math',
      type: LibraryType.lesson,
      title: 'Adding',
      objective: '',
      designTier: 'encourage-effort',
      reading: true,
      interaction: 'tap',
    );
    String art(String n) => stepIllustration(item: item, narration: n);

    expect(art('6 + 3 = 9.'), '➕');
    expect(art('15 - 6. Count back from 15.'), '➖');
    expect(art('3 and 2 make 5, too.'), '➕');
    expect(art('Count by 5s: 5, 10, 15... tap each.'), '🔢');
    expect(art('Round 47 to the nearest 10.'), '🎯');
    expect(art('Tap the ones.'), '🧮');
    expect(art('0.7 means 7 tenths.'), '🍕');
  });

  test('a hyphen between words is never subtraction', () {
    const item = LibraryItem(
      id: 't',
      stage: 1,
      ages: '0-1',
      subject: 'Early Language',
      type: LibraryType.lesson,
      title: 'First Words',
      objective: '',
      designTier: 'parent-led',
      reading: false,
      interaction: 'tap',
    );
    // "bye-bye" and "ma-ma" must not read as maths, which is why this rule
    // is a pattern over digits rather than a substring match on '-'.
    expect(
      stepIllustration(item: item, narration: 'Wave bye-bye!'),
      isNot('➖'),
    );
    expect(
      stepIllustration(item: item, narration: "Tap again for 'ma-ma'."),
      isNot('➖'),
    );
  });

  test('every step resolves to a real picture, never a placeholder', () {
    for (final item in library) {
      for (final step in item.steps) {
        final d =
            stepIllustrationDetail(item: item, narration: step.narration);
        expect(d.emoji.trim(), isNotEmpty,
            reason: '${item.id} has a blank step');
        // ⭐ is a fine picture when the step is about stars ("make more
        // stars!"). What must never come back is ⭐ as a *fallback* — that was
        // the old meaningless catch-all this ladder replaced.
        if (d.tier == IllustrationTier.subject) {
          expect(d.emoji, isNot('⭐'),
              reason: '${item.id} fell to the old catch-all');
        }
      }
    }
  });

  test('the tier ladder and the plain accessor never disagree', () {
    for (final item in library.take(120)) {
      for (final step in item.steps) {
        expect(
          stepIllustration(item: item, narration: step.narration),
          stepIllustrationDetail(item: item, narration: step.narration).emoji,
        );
      }
    }
  });
}
