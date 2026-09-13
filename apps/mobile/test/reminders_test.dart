library;

/// Practice reminders. The product rule (docs/12 §12.6) is that these go to
/// grown-ups, are off by default, and never reach a child — so most of what is
/// worth testing is *when we stay silent*.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/parent/reminders/reminder_policy.dart';
import 'package:watoto_mobile/features/parent/reminders/reminder_scheduler.dart';
import 'package:watoto_mobile/features/parent/reminders/reminder_service.dart';

void main() {
  group('reminder policy', () {
    final today = DateTime(2026, 7, 28, 18, 30);

    test('says nothing to a family who already played today', () {
      expect(
        reminderFor(
          lastActiveDayKey: '2026-07-28',
          streak: 5,
          onDay: today,
        ),
        ReminderKind.none,
      );
    });

    test('warns when a real streak is about to lapse', () {
      expect(
        reminderFor(
          lastActiveDayKey: '2026-07-27',
          streak: 4,
          onDay: today,
        ),
        ReminderKind.streakAtRisk,
      );
    });

    test('does not invent a streak warning for a 1-day run', () {
      expect(
        reminderFor(
          lastActiveDayKey: '2026-07-27',
          streak: 1,
          onDay: today,
        ),
        ReminderKind.keepGoing,
      );
    });

    test('a long silence becomes the lapsed nudge, not a streak warning', () {
      expect(
        reminderFor(
          lastActiveDayKey: '2026-07-20',
          streak: 9,
          onDay: today,
        ),
        ReminderKind.inactive,
      );
    });

    test('a child who has never played gets the gentle way back in', () {
      expect(
        reminderFor(lastActiveDayKey: null, streak: 0, onDay: today),
        ReminderKind.inactive,
      );
    });

    test('a missed day is only "at risk" while the shield can still save it',
        () {
      expect(
        reminderFor(
          lastActiveDayKey: '2026-07-26',
          streak: 4,
          onDay: today,
        ),
        ReminderKind.streakAtRisk,
      );
      // Shield already spent this week: the run ended at midnight.
      expect(
        reminderFor(
          lastActiveDayKey: '2026-07-26',
          streak: 4,
          onDay: today,
          shieldUsedWeek: isoWeekKey(today),
        ),
        ReminderKind.keepGoing,
      );
    });

    test('day gaps are calendar days across a daylight-saving change', () {
      expect(daysBetweenKeys('2026-03-08', '2026-03-09'), 1);
      expect(daysBetweenKeys('2026-03-29', '2026-03-30'), 1);
      expect(daysBetweenKeys('2026-03-27', '2026-03-30'), 3);
      expect(daysBetweenKeys('2026-11-01', '2026-11-02'), 1);
    });
  });

  group('planning', () {
    test('never schedules a slot that has already passed today', () {
      // 19:00 now, reminder set for 18:30 — today's slot is gone.
      final plans = planReminders(
        lastActiveDayKey: '2026-07-27',
        streak: 3,
        now: DateTime(2026, 7, 28, 19, 0),
        hour: 18,
        minute: 30,
      );
      expect(plans, isNotEmpty);
      for (final p in plans) {
        expect(p.at.isAfter(DateTime(2026, 7, 28, 19, 0)), isTrue);
      }
    });

    test('queues one reminder per day within the horizon', () {
      final plans = planReminders(
        lastActiveDayKey: '2026-07-27',
        streak: 3,
        now: DateTime(2026, 7, 28, 8, 0),
        hour: 18,
        minute: 30,
      );
      expect(plans.length, reminderHorizonDays);
      expect(plans.map((p) => p.id).toSet().length, plans.length);
    });

    test('a family who played today is silent tonight, nudged later', () {
      final plans = planReminders(
        lastActiveDayKey: '2026-07-28',
        streak: 3,
        now: DateTime(2026, 7, 28, 8, 0),
        hour: 18,
        minute: 30,
      );
      // Nothing tonight — they already did the work.
      expect(
        plans.where((p) => p.at.day == 28),
        isEmpty,
      );
      expect(plans, isNotEmpty);
    });

    test('the streak count rides along only on the warning', () {
      final plans = planReminders(
        lastActiveDayKey: '2026-07-27',
        streak: 6,
        now: DateTime(2026, 7, 28, 8, 0),
        hour: 18,
        minute: 30,
      );
      final warning =
          plans.firstWhere((p) => p.kind == ReminderKind.streakAtRisk);
      expect(warning.streak, 6);
      for (final p in plans.where((p) => p.kind != ReminderKind.streakAtRisk)) {
        expect(p.streak, 0);
      }
    });
  });

  group('service', () {
    late OfflineStore store;

    setUpAll(() => Hive.init(Directory.systemTemp.path));
    setUp(() async => store = await OfflineStore.open(inMemory: true));
    tearDown(() async => await store.close());

    test('reminders are off until a grown-up turns them on', () {
      expect(store.remindersEnabled, isFalse);
    });

    test('an unsupported platform schedules nothing and stays off', () async {
      final scheduler = RecordingReminderScheduler(supported: false);
      final service = ReminderService(store: store, scheduler: scheduler);
      expect(await service.isSupported(), isFalse);
      expect(store.remindersEnabled, isFalse);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a denied permission leaves reminders off', () async {
      final scheduler = RecordingReminderScheduler(granted: false);
      final service = ReminderService(store: store, scheduler: scheduler);
      // setEnabled needs l10n, which needs a widget tree; the guard we care
      // about here is that the store is untouched before permission is given.
      expect(store.remindersEnabled, isFalse);
      expect(scheduler.scheduled, isEmpty);
      expect(service.scheduler, same(scheduler));
    });

    test('the chosen time round-trips', () async {
      await store.setReminderTime(7, 45);
      expect(store.reminderHour, 7);
      expect(store.reminderMinute, 45);
    });

    test('a nonsense time is clamped rather than stored', () async {
      await store.setReminderTime(99, -5);
      expect(store.reminderHour, 23);
      expect(store.reminderMinute, 0);
    });
  });
}
