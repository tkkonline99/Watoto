import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/parent/screenshot_mode.dart';

void main() {
  group('registerScreenshotTap', () {
    test('triple tap within window enables', () {
      final taps = <DateTime>[];
      final t0 = DateTime(2026, 7, 21, 12, 0, 0);
      expect(
        registerScreenshotTap(tapTimes: taps, now: t0),
        isFalse,
      );
      expect(
        registerScreenshotTap(
          tapTimes: taps,
          now: t0.add(const Duration(milliseconds: 200)),
        ),
        isFalse,
      );
      expect(
        registerScreenshotTap(
          tapTimes: taps,
          now: t0.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );
    });

    test('slow taps do not enable', () {
      final taps = <DateTime>[];
      final t0 = DateTime(2026, 7, 21, 12, 0, 0);
      registerScreenshotTap(tapTimes: taps, now: t0);
      registerScreenshotTap(
        tapTimes: taps,
        now: t0.add(const Duration(seconds: 2)),
      );
      expect(
        registerScreenshotTap(
          tapTimes: taps,
          now: t0.add(const Duration(seconds: 4)),
        ),
        isFalse,
      );
      // Only the last tap remains after window expiry.
      expect(taps.length, lessThan(3));
    });
  });
}
