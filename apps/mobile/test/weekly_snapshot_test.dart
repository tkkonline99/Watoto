import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/parent/weekly_snapshot.dart';

void main() {
  late OfflineStore store;
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('watoto_week_');
    Hive.init(dir.path);
    store = await OfflineStore.open();
  });

  tearDown(() async {
    await store.close();
    await Hive.deleteFromDisk();
  });

  test('startOfWeek is Monday local', () {
    final wed = DateTime(2026, 7, 15); // Wednesday
    final mon = startOfWeek(wed);
    expect(mon.weekday, DateTime.monday);
    expect(mon.year, 2026);
    expect(mon.month, 7);
    expect(mon.day, 13);
  });

  test('empty week is zero across kinds', () async {
    final child = await store.completeOnboarding(
      consent: const ConsentRecord(
        coreData: true,
        aiFeatures: false,
        voiceRecording: false,
        recordedAt: null,
      ),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: DateTime.now().year - 4,
    );
    final snap = weeklySnapshotFor(store, child.id);
    expect(snap.activities, 0);
    expect(snap.lessonsThisWeek, 0);
    expect(snap.storiesThisWeek, 0);
    expect(snap.quizzesThisWeek, 0);
    expect(snap.activeDays, 0);
  });

  test('counts lessons stories quizzes in the current week', () async {
    final child = await store.completeOnboarding(
      consent: const ConsentRecord(
        coreData: true,
        aiFeatures: false,
        voiceRecording: false,
        recordedAt: null,
      ),
      pin: '1234',
      nickname: 'Zuri',
      avatarKey: 'lion',
      birthYear: DateTime.now().year - 4,
    );
    await store.recordLessonCompleted(
      childId: child.id,
      lessonId: 'l1',
      scorePct: 100,
      timeSpentS: 60,
      xpEarned: 10,
    );
    await store.recordStoryRead(
      childId: child.id,
      storyId: 's1',
      xpEarned: 5,
    );
    await store.recordQuizAttempt(
      childId: child.id,
      quizId: 'q1',
      scorePct: 80,
      passed: true,
      answers: const [],
      durationS: 90,
      xpEarned: 15,
      stars: 2,
    );

    final snap = weeklySnapshotFor(store, child.id);
    expect(snap.lessonsThisWeek, greaterThanOrEqualTo(1));
    expect(snap.storiesThisWeek, greaterThanOrEqualTo(1));
    expect(snap.quizzesThisWeek, greaterThanOrEqualTo(1));
    expect(snap.activities, greaterThanOrEqualTo(3));
    expect(snap.starsEarned, greaterThanOrEqualTo(2));
    expect(snap.activeDays, greaterThanOrEqualTo(1));
  });
}
