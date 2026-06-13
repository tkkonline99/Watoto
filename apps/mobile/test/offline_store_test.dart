import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';

void main() {
  late OfflineStore store;

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('watoto_hive_');
    Hive.init(dir.path);
    store = await OfflineStore.open();
  });

  tearDown(() async {
    await store.close();
    await Hive.deleteFromDisk();
  });

  test('completion writes progress, xp, and a queued op', () async {
    await store.recordLessonCompleted(
        lessonId: 'L1', scorePct: 100, timeSpentS: 42, xpEarned: 10);

    expect(store.xp, 10);
    expect(store.progressFor('L1')?['status'], 'completed');
    final ops = store.pendingOps;
    expect(ops, hasLength(1));
    expect(ops.single.opType, 'lesson_progress');
    expect(ops.single.payload['timeSpentS'], 42);
  });

  test('xp accumulates and ops drain oldest-first', () async {
    await store.recordLessonCompleted(
        lessonId: 'L1', scorePct: 80, timeSpentS: 10, xpEarned: 10);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.recordLessonCompleted(
        lessonId: 'L2', scorePct: 90, timeSpentS: 20, xpEarned: 15);

    expect(store.xp, 25);
    expect(store.pendingOps.map((o) => o.payload['lessonId']), ['L1', 'L2']);
  });

  test('removeOps dequeues acknowledged ops only', () async {
    await store.recordLessonCompleted(
        lessonId: 'L1', scorePct: 100, timeSpentS: 5, xpEarned: 10);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.recordLessonCompleted(
        lessonId: 'L2', scorePct: 100, timeSpentS: 5, xpEarned: 10);

    await store.removeOps([store.pendingOps.first.clientOpId]);

    expect(store.pendingOps, hasLength(1));
    expect(store.pendingOps.single.payload['lessonId'], 'L2');
  });

  test('balances and queue survive close + reopen (persistence)', () async {
    await store.recordLessonCompleted(
        lessonId: 'L1', scorePct: 100, timeSpentS: 5, xpEarned: 10);

    await store.close();
    store = await OfflineStore.open();

    expect(store.xp, 10);
    expect(store.pendingOps, hasLength(1));
  });
}
