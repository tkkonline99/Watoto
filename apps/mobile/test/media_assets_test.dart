import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke-check that critical art + VO assets are in the asset bundle.
/// Full library size is large; we sample hero slots across all stages plus
/// one VO path so a missing-asset regression fails CI fast.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// One known-good hero PNG per stage (AI or procedural; paths must exist).
  const heroSamples = <String>[
    'assets/images/img/s01/ball.png',
    'assets/images/img/s02/duck.png',
    'assets/images/img/s03/apple.png',
    'assets/images/img/s04/rainbow.png',
    'assets/images/img/s05/robot_start.png',
    'assets/images/img/s06/flag.png',
    'assets/images/img/s07/globe.png',
    'assets/images/img/s08/water_cycle.png',
    'assets/images/img/s09/solar_system.png',
    'assets/images/img/s10/world_map.png',
  ];

  test('hero art samples load for stages 1–10', () async {
    for (final path in heroSamples) {
      final data = await rootBundle.load(path);
      expect(
        data.lengthInBytes,
        greaterThan(100),
        reason: 'missing or empty: $path',
      );
    }
  });

  test('bundled VO sample exists', () async {
    final vo = await rootBundle.load(
      'assets/audio/en/s01.cause.lesson.01.steps.0.narration.mp3',
    );
    expect(vo.lengthInBytes, greaterThan(100));
  });

  test('stage 10 dense heroes exist', () async {
    const extra = [
      'assets/images/img/s10/online_safety.png',
      'assets/images/img/s10/bake_sale.png',
      'assets/images/img/s10/robot_success.png',
      'assets/images/img/s10/fraction_bars.png',
    ];
    for (final path in extra) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(100), reason: path);
    }
  });
}
