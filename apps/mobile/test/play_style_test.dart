import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/play_style.dart';

void main() {
  group('age bands', () {
    test('toddler stages are 1-2', () {
      expect(isToddlerStage(1), isTrue);
      expect(isToddlerStage(2), isTrue);
      expect(isToddlerStage(3), isFalse);
      expect(isToddlerStage(10), isFalse);
    });

    test('toddler targets are larger', () {
      expect(playTargetSize(stage: 1), greaterThan(playTargetSize(stage: 5)));
      expect(playEmojiSize(stage: 2), greaterThan(playEmojiSize(stage: 7)));
      expect(playChoiceMinSize(stage: 1), greaterThan(playChoiceMinSize(stage: 8)));
      expect(playArtSize(stage: 2), greaterThan(playArtSize(stage: 4)));
      expect(playCaptionSize(stage: 1), greaterThan(playCaptionSize(stage: 6)));
    });
  });

  group('co-play tips', () {
    test('prefers parentNote when present', () {
      final tip = coPlayTipFor(
        stage: 1,
        subject: 'Sensory Exploration',
        parentNote: 'Hold baby close and smile.',
        lang: 'en',
      );
      expect(tip, 'Hold baby close and smile.');
    });

    test('empty for older stages without note', () {
      final tip = coPlayTipFor(
        stage: 6,
        subject: 'Math',
        parentNote: null,
        lang: 'en',
      );
      expect(tip, isEmpty);
    });

    test('falls back to localized toddler tip', () {
      final en = coPlayTipFor(
        stage: 1,
        subject: 'Early Language',
        parentNote: null,
        lang: 'en',
      );
      final fr = coPlayTipFor(
        stage: 1,
        subject: 'Early Language',
        parentNote: null,
        lang: 'fr',
      );
      final sw = coPlayTipFor(
        stage: 1,
        subject: 'Early Language',
        parentNote: null,
        lang: 'sw',
      );
      expect(en, isNotEmpty);
      expect(fr, isNotEmpty);
      expect(sw, isNotEmpty);
      expect(en, isNot(equals(fr)));
    });
  });
}
