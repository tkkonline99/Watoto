import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/gamification/badge_stats_source.dart';

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

  group('liveStreak', () {
    int live(String? last, {bool shield = true}) => liveStreak(
          lastDayKey: last,
          todayKey: '2026-07-01',
          yesterdayKey: '2026-06-30',
          dayBeforeYesterdayKey: '2026-06-29',
          stored: 6,
          shieldAvailable: shield,
        );

    test('a run touched today or yesterday is still its stored length', () {
      expect(live('2026-07-01'), 6);
      expect(live('2026-06-30'), 6);
    });

    test('one missed day is still alive while the shield can cover it', () {
      expect(live('2026-06-29'), 6);
      expect(live('2026-06-29', shield: false), 0);
    });

    test('a run that ended reads 0, not the length it used to be', () {
      expect(live('2026-06-20'), 0);
      expect(live(null), 0);
    });
  });

  group('dayKeyBefore', () {
    test('counts calendar days, so a 23-hour day is still one day', () {
      // The hour after midnight following a spring-forward day, in North
      // America and in Europe. Subtracting 24 hours lands two days back in
      // either zone; the calendar does not.
      expect(dayKeyBefore(DateTime(2026, 3, 9, 0, 30), 1), '2026-03-08');
      expect(dayKeyBefore(DateTime(2026, 3, 30, 0, 30), 1), '2026-03-29');
      expect(dayKeyBefore(DateTime(2026, 3, 30, 0, 30), 2), '2026-03-28');
    });

    test('rolls over months and years, and keeps a UTC time in UTC', () {
      expect(dayKeyBefore(DateTime(2026, 1, 1, 0, 5), 1), '2025-12-31');
      expect(dayKeyBefore(DateTime(2024, 3, 1, 9), 1), '2024-02-29');
      expect(dayKeyBefore(DateTime.utc(2026, 7, 1, 23, 59), 1), '2026-06-30');
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

    test('the run reads 0 once it has lapsed, with nothing written since',
        () async {
      await store.recordLessonCompleted(
        childId: 'c1',
        lessonId: 'L1',
        scorePct: 100,
        timeSpentS: 5,
        xpEarned: 10,
      );
      final t = DateTime.now();
      DateTime daysOn(int n) => DateTime(t.year, t.month, t.day + n, 12);

      expect(store.streakFor('c1', now: daysOn(1)), 1);
      // One missed day: this week's shield would still save it.
      expect(store.streakFor('c1', now: daysOn(2)), 1);
      expect(store.streakFor('c1', now: daysOn(3)), 0);
      expect(store.streakFor('c1', now: daysOn(10)), 0);
    });

    test('a badge stays on the shelf after the run that earned it ends',
        () async {
      await store.recordLessonCompleted(
        childId: 'c1',
        lessonId: 'L1',
        scorePct: 100,
        timeSpentS: 5,
        xpEarned: 10,
      );
      // Awarded on an earlier run; the current one is a single day long.
      await store.markBadgesSeen('c1', ['streak3']);
      expect(store.streakFor('c1'), lessThan(3));

      final held = heldBadgesFor(store, 'c1').map((b) => b.id);
      expect(held, contains('streak3'));
      expect(held, isNot(contains('streak7')));
    });
  });
}
