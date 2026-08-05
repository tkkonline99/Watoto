import 'dart:io';

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

  // The rendered VO pack is 184 MB, is not committed, and is not in the default
  // asset bundle (see the note in pubspec.yaml). So the invariant worth guarding
  // is not "the mp3 is bundled" — it is "the script still knows to render it,
  // and if a build DOES bundle the pack, the file is not a zero-byte stub".
  const voSample = 's01.cause.lesson.01.steps.0.narration';

  test('VO manifest still covers the stage-1 sample', () {
    // The manifest lives in the monorepo, not in this package. CI checks the
    // whole repo out so it is reachable; the local build workspace copies only
    // apps/mobile, so it is not. Skip when the whole content/ tree is out of
    // reach — but if content/ IS there, a missing manifest is a real failure,
    // not an excuse to pass.
    final contentDir = Directory('../../content');
    if (!contentDir.existsSync()) {
      markTestSkipped(
        'content/ is out of reach — testing apps/mobile on its own',
      );
      return;
    }
    final manifest = File(
      '../../content/production/audio/audio_manifest.csv',
    );
    expect(
      manifest.existsSync(),
      isTrue,
      reason: 'audio_manifest.csv is the source of truth for what is spoken',
    );
    expect(manifest.readAsStringSync(), contains(voSample));
  });

  test('a rendered VO file, when present, is real audio', () async {
    final onDisk = File('assets/audio/en/$voSample.mp3');
    if (!onDisk.existsSync()) {
      markTestSkipped(
        'VO pack not rendered here — run tool/export_tts_vo.py to build it',
      );
      return;
    }
    expect(onDisk.lengthSync(), greaterThan(100));
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

  /// The sound effects have to match in both directions, and neither half held.
  ///
  /// `assets/audio/sfx/` is bundled wholesale, so a file that lands in it ships
  /// to every device whether or not anything calls it. Three did: `page.wav`,
  /// which meant all 594 story pages turned in silence, and two audition takes
  /// (`level_up.wav`, `soft_wrong.wav`) that generate_sfx.py renders for
  /// choosing between and that were never meant to ship.
  ///
  /// A missing file is the louder failure and a stray one is the quieter, but
  /// both are cheap to check, so this checks both.
  group('sound effects', () {
    final source = File('lib/core/audio/sound_effects.dart').readAsStringSync();
    final played = RegExp(r"audio/sfx/([a-z_]+)\.wav")
        .allMatches(source)
        .map((m) => '${m.group(1)}.wav')
        .toSet();
    final onDisk = Directory('assets/audio/sfx')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.wav'))
        .toSet();

    test('every sound the app plays is on disk', () {
      expect(played, isNotEmpty);
      expect(
        played.difference(onDisk),
        isEmpty,
        reason: 'sound_effects.dart plays a file that is not in the bundle',
      );
    });

    test('every sound in the bundle is played by something', () {
      expect(
        onDisk.difference(played),
        isEmpty,
        reason: 'these ship to every device and nothing calls them — either '
            'wire them up or delete them',
      );
    });
  });
}
