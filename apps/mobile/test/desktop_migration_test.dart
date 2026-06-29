import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/offline/desktop_migration_io.dart';

/// Guards the one-time shim that recovers Hive data orphaned when the desktop
/// app-support directory changed (see desktop_migration_io.dart).
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('watoto_mig'));
  tearDown(() => root.deleteSync(recursive: true));

  File writeBox(Directory dir, String name, int size, [int fill = 1]) =>
      File('${dir.path}${Platform.pathSeparator}$name')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(size, fill));

  test('copies hive boxes from a legacy sibling into a fresh support dir',
      () async {
    final legacy = Directory('${root.path}/watoto_mobile')..createSync();
    writeBox(legacy, 'account.hive', 600);
    writeBox(legacy, 'progress.hive', 50);
    writeBox(legacy, 'account.lock', 0); // lock files must not be copied
    final current = Directory('${root.path}/Watoto')..createSync();

    await migrateLegacyDesktopData(current.path);

    expect(File('${current.path}/account.hive').lengthSync(), 600);
    expect(File('${current.path}/progress.hive').existsSync(), isTrue);
    expect(File('${current.path}/account.lock').existsSync(), isFalse);
  });

  test('leaves an already-onboarded support dir untouched', () async {
    final legacy = Directory('${root.path}/old')..createSync();
    writeBox(legacy, 'account.hive', 600, 1);
    final current = Directory('${root.path}/Watoto')..createSync();
    writeBox(current, 'account.hive', 400, 9); // already has a family (>256 B)

    await migrateLegacyDesktopData(current.path);

    final acc = File('${current.path}/account.hive');
    expect(acc.lengthSync(), 400);
    expect(acc.readAsBytesSync().first, 9); // not overwritten by the legacy box
  });

  test('treats a locale-only account box (≤256 B) as fresh and migrates',
      () async {
    final legacy = Directory('${root.path}/old')..createSync();
    writeBox(legacy, 'account.hive', 600);
    final current = Directory('${root.path}/Watoto')..createSync();
    writeBox(current, 'account.hive', 80, 7); // ~locale-only, not onboarded

    await migrateLegacyDesktopData(current.path);

    expect(File('${current.path}/account.hive').lengthSync(), 600);
  });

  test('is a no-op when there is no legacy data', () async {
    final current = Directory('${root.path}/Watoto')..createSync();
    await migrateLegacyDesktopData(current.path);
    expect(File('${current.path}/account.hive').existsSync(), isFalse);
  });
}
