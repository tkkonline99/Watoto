import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/data/cloud/cloud_sync.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';

/// Progress lives only on the device in this build, so a reinstall or a lost
/// phone used to erase everything a child had done. The export existed but
/// carried the *readable* summary, which no code could restore from — these
/// tests pin the round trip that actually brings a family back.
void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('watoto_backup').path);
  });

  Future<OfflineStore> seeded({String nickname = 'Amani'}) async {
    final store = await OfflineStore.open(inMemory: true);
    await store.completeOnboarding(
      consent: ConsentRecord(
        coreData: true,
        aiFeatures: false,
        voiceRecording: false,
        recordedAt: DateTime.utc(2026, 1, 1),
      ),
      pin: '1234',
      nickname: nickname,
      avatarKey: 'lion',
      birthYear: 2020,
    );
    final childId = store.activeChildId!;
    await store.recordLessonCompleted(
      childId: childId,
      lessonId: 's02.animals.lesson.01',
      scorePct: 100,
      timeSpentS: 90,
      xpEarned: 20,
    );
    await store.recordStoryRead(
      childId: childId,
      storyId: 's02.animals.story.01',
      xpEarned: 10,
    );
    return store;
  }

  test('a backup restores profiles and progress onto a fresh device',
      () async {
    final source = await seeded();
    final bundle = source.exportBackupBundle();
    final childId = source.activeChildId!;
    final xpBefore = source.xpFor(childId);
    final lessonsBefore = source.completedLessonCount(childId);
    expect(lessonsBefore, 1);
    await source.close();

    // A brand new device: nothing on it at all.
    final fresh = await OfflineStore.open(inMemory: true);
    expect(fresh.children, isEmpty);

    final result = await fresh.restoreBackupBundle(bundle);
    expect(result.childrenRestored, 1);
    expect(result.progressRestored, greaterThan(0));
    expect(fresh.children.single.nickname, 'Amani');
    expect(fresh.completedLessonCount(childId), lessonsBefore);
    expect(fresh.completedStoryCount(childId), 1);
    expect(fresh.xpFor(childId), xpBefore);
    await fresh.close();
  });

  test('secrets never travel in a backup file', () async {
    final store = await seeded();
    final bundle = store.exportBackupBundle();
    final account = (bundle['account'] as Map).cast<String, dynamic>();

    // A backup lands in Downloads or a chat thread; a PIN hash must not.
    for (final secret in [
      'pinHash',
      'pinSalt',
      'accountHash',
      'accountSalt',
      'pwResetHash',
      'deviceId',
    ]) {
      expect(
        account.containsKey(secret),
        isFalse,
        reason: '$secret must not be exported',
      );
    }
    expect(store.hasPin, isTrue, reason: 'the live PIN is untouched');
    await store.close();
  });

  test('restoring never subtracts from what is already on the device',
      () async {
    final source = await seeded();
    final childId = source.activeChildId!;
    final staleBundle = source.exportBackupBundle();
    final staleXp = source.xpFor(childId);

    // The child keeps learning after the backup was taken.
    await source.recordLessonCompleted(
      childId: childId,
      lessonId: 's02.colors.lesson.01',
      scorePct: 100,
      timeSpentS: 60,
      xpEarned: 20,
    );
    final newerXp = source.xpFor(childId);
    expect(newerXp, greaterThan(staleXp));

    // Restoring the older backup must not roll the child backwards.
    await source.restoreBackupBundle(staleBundle);
    expect(source.xpFor(childId), newerXp);
    expect(source.completedLessonCount(childId), 2);
    await source.close();
  });

  test('a foreign or corrupt file is rejected, not silently ignored',
      () async {
    final store = await OfflineStore.open(inMemory: true);
    expect(
      () => store.restoreBackupBundle({'format': 'something-else'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => restoreFamilyBackup(store, 'not json at all'),
      throwsA(isA<FormatException>()),
    );
    await store.close();
  });

  test('a backup from a newer app version is refused with a reason', () async {
    final store = await OfflineStore.open(inMemory: true);
    expect(
      () => store.restoreBackupBundle({
        'format': 'watoto.backup',
        'version': OfflineStore.backupFormatVersion + 1,
      }),
      throwsA(isA<FormatException>()),
    );
    await store.close();
  });

  test('restoreFamilyBackup accepts the exported envelope and the raw bundle',
      () async {
    final source = await seeded(nickname: 'Zuri');
    final envelope = buildFamilyBackup(source).toJsonString();
    await source.close();

    final a = await OfflineStore.open(inMemory: true);
    expect((await restoreFamilyBackup(a, envelope)).childrenRestored, 1);
    expect(a.children.single.nickname, 'Zuri');
    await a.close();

    // The export writes "<backup>\n---\n<readable json>" to the clipboard;
    // a parent pasting the whole thing must still work.
    final b = await OfflineStore.open(inMemory: true);
    expect(
      (await restoreFamilyBackup(b, '$envelope\n---\n{"human":"readable"}'))
          .childrenRestored,
      1,
    );
    await b.close();
  });

  test('buildFamilyBackup carries the restorable bundle, not the summary',
      () async {
    // Regression guard: this used to wrap exportFamilyData(), producing a file
    // named "backup" that no restore path could read.
    final store = await seeded();
    final payload = buildFamilyBackup(store).payload;
    expect(payload['format'], 'watoto.backup');
    expect(payload['progress'], isA<Map<String, dynamic>>());
    expect((payload['progress'] as Map), isNotEmpty);
    await store.close();
  });
}
