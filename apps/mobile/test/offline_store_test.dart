import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';

const c1 = 'child-1';
const c2 = 'child-2';

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

  test('completion writes per-child progress, xp, and a queued op', () async {
    await store.recordLessonCompleted(
        childId: c1, lessonId: 'L1', scorePct: 100, timeSpentS: 42, xpEarned: 10);

    expect(store.xpFor(c1), 10);
    expect(store.progressFor(c1, 'L1')?['status'], 'completed');
    expect(store.completedLessonCount(c1), 1);
    final ops = store.pendingOps;
    expect(ops, hasLength(1));
    expect(ops.single.opType, 'lesson_progress');
    expect(ops.single.payload['timeSpentS'], 42);
  });

  test('balances are isolated per child', () async {
    await store.recordLessonCompleted(
        childId: c1, lessonId: 'L1', scorePct: 100, timeSpentS: 5, xpEarned: 10);
    await store.recordQuizAttempt(
        childId: c2,
        quizId: 'Q1',
        scorePct: 100,
        passed: true,
        answers: const [],
        durationS: 5,
        xpEarned: 20);

    expect(store.xpFor(c1), 10);
    expect(store.xpFor(c2), 20);
    expect(store.progressFor(c2, 'L1'), isNull);
    expect(store.completedLessonCount(c2), 0);
  });

  test('removeOps dequeues acknowledged ops only', () async {
    await store.recordLessonCompleted(
        childId: c1, lessonId: 'L1', scorePct: 100, timeSpentS: 5, xpEarned: 10);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.recordLessonCompleted(
        childId: c1, lessonId: 'L2', scorePct: 100, timeSpentS: 5, xpEarned: 10);

    await store.removeOps([store.pendingOps.first.clientOpId]);

    expect(store.pendingOps, hasLength(1));
    expect(store.pendingOps.single.payload['lessonId'], 'L2');
  });

  test('account: onboarding, PIN, consent, profiles persist across reopen', () async {
    final child = await store.completeOnboarding(
      consent: const ConsentRecord(
          coreData: true, aiFeatures: true, voiceRecording: false, recordedAt: null),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    await store.recordLessonCompleted(
        childId: child.id, lessonId: 'L1', scorePct: 100, timeSpentS: 5, xpEarned: 10);

    await store.close();
    store = await OfflineStore.open();

    expect(store.onboardingComplete, isTrue);
    expect(store.activeChildId, child.id);
    expect(store.children, hasLength(1));
    expect(store.children.single.nickname, 'Amani');
    expect(store.consent.aiFeatures, isTrue);
    expect(store.xpFor(child.id), 10);
    expect(store.verifyPin('1234'), isTrue);
    expect(store.verifyPin('0000'), isFalse);
  });
}
