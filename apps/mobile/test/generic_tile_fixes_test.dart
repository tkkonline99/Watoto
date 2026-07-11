import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';

void main() {
  test('user-reported generic-tile steps now stage choices', () {
    // "Things We Wear" — Tap the coat.
    final coat = choicePlanFor('s02.vocab.lesson', 0, 'Tap the coat.');
    expect(coat, isNotNull);
    expect(coat!.options[coat.targetIndex].emoji, '🧥');
    expect(coat.options.length, 3);

    // "Describing Words" — This soup is HOT. Tap the steam.
    final steam = choicePlanFor(
      's03.vocab.lesson',
      0,
      'This soup is HOT. Tap the steam.',
    );
    expect(steam, isNotNull);
    expect(steam!.options[steam.targetIndex].emoji, '♨️');

    // Pronoun directive resolves from the step: The rabbit is FAST. Tap it.
    final rabbit = choicePlanFor('x', 0, 'The rabbit is FAST. Tap it.');
    expect(rabbit, isNotNull);
    expect(rabbit!.options[rabbit.targetIndex].emoji, '🐰');

    // Opposites: This cube is BIG. Tap the SMALL one.
    final small = choicePlanFor('x', 1, 'This cube is BIG. Tap the SMALL one.');
    expect(small, isNotNull);
    expect(small!.options[small.targetIndex].emoji, '🐭');

    // Punctuation: Tap a comma.
    final comma = choicePlanFor('x', 2, 'Commas separate items. Tap a comma.');
    expect(comma, isNotNull);
    expect(comma!.options[comma.targetIndex].emoji, ',');

    // Numbers beyond ten: Ten and 3 more is 13. Tap 13.
    final n13 = choicePlanFor('x', 3, 'Ten and 3 more is 13. Tap 13.');
    expect(n13, isNotNull);
    expect(n13!.options[n13.targetIndex].emoji, '13');
    expect(n13.options.map((o) => o.emoji), contains('3'));

    // Case letters: Tap the little a.
    final littleA = choicePlanFor('x', 4, 'Tap the little a.');
    expect(littleA, isNotNull);
    expect(littleA!.options[littleA.targetIndex].emoji, 'a');
    expect(littleA.options.map((o) => o.emoji), contains('A'));
  });
}
