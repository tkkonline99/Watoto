import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/desktop_migration_io.dart';

/// Guards the shim that recovers Hive data stranded when the desktop
/// app-support directory changed (see desktop_migration_io.dart).
///
/// The boxes here are **real Hive boxes**, not files of a chosen length. Two
/// earlier versions of this shim were guarded by size-based fixtures, and both
/// passed while being wrong about live data: a byte count cannot distinguish a
/// family that is in use from one that merely has a lot of bytes. These tests
/// therefore state the rule the shim now follows — a profile that finished
/// onboarding is never overwritten, whatever its size — and the one that
/// matters most is `never touches a profile that is in use`.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('watoto_mig'));

  tearDown(() async {
    await Hive.close();
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Writes a genuine `account` box at [dir], onboarded or not.
  Future<void> writeProfile(
    Directory dir, {
    required bool onboarded,
    String child = 'Amani',
  }) async {
    dir.createSync(recursive: true);
    Hive.init(dir.path);
    final box = await Hive.openBox<String>('account');
    await box.put('child:$child', '{"nickname":"$child"}');
    await box.put('activeChildId', child);
    if (onboarded) await box.put('onboardingComplete', 'true');
    await box.close();
  }

  /// A non-account box, so "the boxes travel together" can be checked.
  Future<void> writeProgress(Directory dir, String value) async {
    dir.createSync(recursive: true);
    Hive.init(dir.path);
    final box = await Hive.openBox<String>('progress');
    await box.put('done', value);
    await box.close();
  }

  Future<String?> readAccount(Directory dir, String key) async {
    Hive.init(dir.path);
    final box = await Hive.openBox<String>('account');
    final v = box.get(key);
    await box.close();
    return v;
  }

  /// `%APPDATA%\{company}\{product}` — the shape the shim searches.
  Directory at(String company, String product) =>
      Directory('${root.path}/$company/$product');

  group('leaves a profile that is in use alone', () {
    test('even when a legacy folder holds far more data', () async {
      final current = at('Watoto', 'Watoto');
      await writeProfile(current, onboarded: true, child: 'Nathan');
      final legacy = at('app.watoto', 'Watoto');
      await writeProfile(legacy, onboarded: true, child: 'Old');
      await writeProgress(legacy, 'x' * 4000);

      await migrateLegacyDesktopData(current.path);

      // The exact failure that destroyed a real family: the live profile had
      // no progress recorded, the abandoned one had plenty, and size lost.
      expect(await readAccount(current, 'activeChildId'), 'Nathan');
      expect(File('${current.path}/account.hive.bak').existsSync(), isFalse);
    });

    test('and refuses to act when the current box cannot be read', () async {
      final current = at('Watoto', 'Watoto')..createSync(recursive: true);
      File('${current.path}/account.hive')
          .writeAsBytesSync(List.filled(900, 0xEE)); // not a Hive box
      final legacy = at('app.watoto', 'Watoto');
      await writeProfile(legacy, onboarded: true, child: 'Old');

      await migrateLegacyDesktopData(current.path);

      // Unreadable is not the same as absent. Guessing here is what caused the
      // damage, so an unknown profile is assumed to be in use.
      expect(File('${current.path}/account.hive').lengthSync(), 900);
      expect(File('${current.path}/account.hive.bak').existsSync(), isFalse);
    });
  });

  group('adopts a stranded family', () {
    test('from a renamed company folder, which is not a sibling', () async {
      final current = at('Watoto', 'Watoto')..createSync(recursive: true);
      final legacy = at('app.watoto', 'Watoto');
      await writeProfile(legacy, onboarded: true, child: 'Nathan');
      await writeProgress(legacy, 'lesson-1');

      await migrateLegacyDesktopData(current.path);

      expect(await readAccount(current, 'activeChildId'), 'Nathan');
      // The boxes travel together — progress keyed to a child who is not in
      // this account would be worse than no migration at all.
      Hive.init(current.path);
      final progress = await Hive.openBox<String>('progress');
      expect(progress.get('done'), 'lesson-1');
      await progress.close();
    });

    test('from a renamed product folder, the original case', () async {
      final current = at('app.watoto', 'Watoto')..createSync(recursive: true);
      final legacy = at('app.watoto', 'watoto_mobile');
      await writeProfile(legacy, onboarded: true, child: 'Nathan');

      await migrateLegacyDesktopData(current.path);

      expect(await readAccount(current, 'activeChildId'), 'Nathan');
    });

    test('when the current folder has a box but never finished onboarding',
        () async {
      // The app writes an account box as soon as it starts, so "has a box" and
      // "has a family" are different questions.
      final current = at('Watoto', 'Watoto');
      await writeProfile(current, onboarded: false, child: 'partial');
      final legacy = at('app.watoto', 'Watoto');
      await writeProfile(legacy, onboarded: true, child: 'Nathan');

      await migrateLegacyDesktopData(current.path);

      expect(await readAccount(current, 'activeChildId'), 'Nathan');
      expect(File('${current.path}/account.hive.bak').existsSync(), isTrue);
    });

    test('preferring the most recently used of several', () async {
      final current = at('Watoto', 'Watoto')..createSync(recursive: true);
      final older = at('app.watoto', 'watoto_mobile');
      await writeProfile(older, onboarded: true, child: 'Older');
      final newer = at('app.watoto', 'Watoto');
      await writeProfile(newer, onboarded: true, child: 'Newer');
      File('${older.path}/account.hive')
          .setLastModifiedSync(DateTime.now().subtract(const Duration(days: 30)));

      await migrateLegacyDesktopData(current.path);

      expect(await readAccount(current, 'activeChildId'), 'Newer');
    });
  });

  group('never adopts', () {
    test('a folder whose family never finished onboarding', () async {
      final current = at('Watoto', 'Watoto')..createSync(recursive: true);
      final legacy = at('app.watoto', 'Watoto');
      await writeProfile(legacy, onboarded: false, child: 'partial');

      await migrateLegacyDesktopData(current.path);

      expect(File('${current.path}/account.hive').existsSync(), isFalse);
    });

    test('another vendor\'s folder', () async {
      final current = at('Watoto', 'Watoto')..createSync(recursive: true);
      final stranger = at('SomeOtherApp', 'Watoto');
      await writeProfile(stranger, onboarded: true, child: 'NotOurs');

      await migrateLegacyDesktopData(current.path);

      expect(File('${current.path}/account.hive').existsSync(), isFalse);
    });

    test('anything at all when there is nothing to adopt', () async {
      final current = at('Watoto', 'Watoto')..createSync(recursive: true);
      await migrateLegacyDesktopData(current.path);
      expect(File('${current.path}/account.hive').existsSync(), isFalse);
    });
  });

  test('leaves the folder it inspects byte-identical', () async {
    final current = at('Watoto', 'Watoto');
    await writeProfile(current, onboarded: true, child: 'Nathan');
    final legacy = at('app.watoto', 'Watoto');
    await writeProfile(legacy, onboarded: true, child: 'Old');

    final before = File('${legacy.path}/account.hive').readAsBytesSync();
    final filesBefore = legacy.listSync().map((e) => e.path).toSet();

    await migrateLegacyDesktopData(current.path);

    expect(File('${legacy.path}/account.hive').readAsBytesSync(), before);
    // Opening a Hive box in place would drop a .lock beside it. Someone else's
    // profile must come out untouched, which is why the probe works on a copy.
    expect(legacy.listSync().map((e) => e.path).toSet(), filesBefore);
  });

  test('running twice does not undo the first run', () async {
    final current = at('Watoto', 'Watoto')..createSync(recursive: true);
    final legacy = at('app.watoto', 'Watoto');
    await writeProfile(legacy, onboarded: true, child: 'Nathan');

    await migrateLegacyDesktopData(current.path);
    // Whatever the child does next must survive the following launch.
    Hive.init(current.path);
    final box = await Hive.openBox<String>('account');
    await box.put('activeChildId', 'NathanAfterPlaying');
    await box.close();
    await migrateLegacyDesktopData(current.path);

    expect(await readAccount(current, 'activeChildId'), 'NathanAfterPlaying');
  });
}
