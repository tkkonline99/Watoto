import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/gamification/first_day_highfive.dart';

void main() {
  group('shouldOfferFirstDayHighFive', () {
    test('offers on first learning write when not yet celebrated', () {
      expect(
        shouldOfferFirstDayHighFive(
          alreadyCelebratedToday: false,
          isFirstLearningWriteOfDay: true,
        ),
        isTrue,
      );
    });

    test('skips when already celebrated', () {
      expect(
        shouldOfferFirstDayHighFive(
          alreadyCelebratedToday: true,
          isFirstLearningWriteOfDay: true,
        ),
        isFalse,
      );
    });

    test('skips when not the first write of the day', () {
      expect(
        shouldOfferFirstDayHighFive(
          alreadyCelebratedToday: false,
          isFirstLearningWriteOfDay: false,
        ),
        isFalse,
      );
    });
  });
}
