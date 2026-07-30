import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/gamification/session_stretch.dart';

void main() {
  group('shouldOfferStretch', () {
    test('not before threshold', () {
      expect(
        shouldOfferStretch(
          screenTimeUsedSecondsToday: 5 * 60,
          lastStretchAtEpochS: null,
          nowEpochS: 1_000_000,
        ),
        isFalse,
      );
    });

    test('offers after threshold with no prior stretch', () {
      expect(
        shouldOfferStretch(
          screenTimeUsedSecondsToday: stretchAfterSeconds,
          lastStretchAtEpochS: null,
          nowEpochS: 1_000_000,
        ),
        isTrue,
      );
    });

    test('respects cooldown after a recent stretch', () {
      const now = 1_000_000;
      expect(
        shouldOfferStretch(
          screenTimeUsedSecondsToday: stretchAfterSeconds + 100,
          lastStretchAtEpochS: now - 60,
          nowEpochS: now,
        ),
        isFalse,
      );
      expect(
        shouldOfferStretch(
          screenTimeUsedSecondsToday: stretchAfterSeconds + 100,
          lastStretchAtEpochS: now - stretchCooldownDownSeconds - 1,
          nowEpochS: now,
        ),
        isTrue,
      );
    });
  });
}
