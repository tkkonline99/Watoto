import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';

void main() {
  group('nextStreak', () {
    test('same day keeps the count', () {
      expect(
        nextStreak(
          lastDayKey: '2026-07-01',
          todayKey: '2026-07-01',
          yesterdayKey: '2026-06-30',
          current: 4,
        ),
        4,
      );
    });

    test('a consecutive day increments', () {
      expect(
        nextStreak(
          lastDayKey: '2026-06-30',
          todayKey: '2026-07-01',
          yesterdayKey: '2026-06-30',
          current: 4,
        ),
        5,
      );
    });

    test('a gap resets to 1', () {
      expect(
        nextStreak(
          lastDayKey: '2026-06-28',
          todayKey: '2026-07-01',
          yesterdayKey: '2026-06-30',
          current: 4,
        ),
        1,
      );
    });

    test('the first ever day is 1', () {
      expect(
        nextStreak(
          lastDayKey: null,
          todayKey: '2026-07-01',
          yesterdayKey: '2026-06-30',
          current: 0,
        ),
        1,
      );
    });

    test('weekly shield saves a one-day miss', () {
      final tick = nextStreakTick(
        lastDayKey: '2026-06-29', // day before yesterday
        todayKey: '2026-07-01',
        yesterdayKey: '2026-06-30',
        dayBeforeYesterdayKey: '2026-06-29',
        current: 4,
        shieldAvailable: true,
      );
      expect(tick.streak, 5);
      expect(tick.usedShield, isTrue);
    });

    test('without shield a one-day miss resets', () {
      final tick = nextStreakTick(
        lastDayKey: '2026-06-29',
        todayKey: '2026-07-01',
        yesterdayKey: '2026-06-30',
        dayBeforeYesterdayKey: '2026-06-29',
        current: 4,
        shieldAvailable: false,
      );
      expect(tick.streak, 1);
      expect(tick.usedShield, isFalse);
    });
  });

  group('store streak', () {
    late OfflineStore store;

    setUp(() async {
      final dir = Directory.systemTemp.createTempSync('watoto_streak_');
      Hive.init(dir.path);
      store = await OfflineStore.open();
    });

    tearDown(() async {
      await store.close();
      await Hive.deleteFromDisk();
    });

    test(
      'a completion starts the streak; same-day repeats do not double it',
      () async {
        expect(store.streakFor('c1'), 0);
        await store.recordLessonCompleted(
          childId: 'c1',
          lessonId: 'L1',
          scorePct: 100,
          timeSpentS: 5,
          xpEarned: 10,
        );
        expect(store.streakFor('c1'), 1);
        await store.recordStoryRead(childId: 'c1', storyId: 'S1', xpEarned: 8);
        expect(store.streakFor('c1'), 1);
      },
    );
  });
}
