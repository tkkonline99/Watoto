/// Turns the reminder policy into scheduled notices.
///
/// The whole feature is parent-facing and opt-in (docs/12 §12.6). Nothing is
/// scheduled until a grown-up enables it in the Parent Zone, and disabling it
/// cancels everything already queued.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_providers.dart';
import '../../../core/offline/offline_store.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'reminder_policy.dart';
import 'reminder_scheduler.dart';
import 'reminder_scheduler_stub.dart'
    if (dart.library.io) 'reminder_scheduler_io.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => createReminderScheduler(),
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(
    store: ref.watch(offlineStoreProvider),
    scheduler: ref.watch(reminderSchedulerProvider),
  ),
);

/// Bumped whenever reminder settings change so the Parent Zone rebuilds.
final reminderTickProvider = StateProvider<int>((ref) => 0);

/// Localized copy for one reminder. Addressed to the grown-up, about the
/// child — never addressed to the child.
class ReminderCopy {
  const ReminderCopy(this.title, this.body);
  final String title;
  final String body;

  static ReminderCopy forKind(
    AppLocalizations l10n,
    ReminderKind kind, {
    required String childName,
    required int streak,
  }) =>
      switch (kind) {
        ReminderKind.streakAtRisk => ReminderCopy(
            l10n.reminderStreakTitle(childName),
            l10n.reminderStreakBody(streak),
          ),
        ReminderKind.inactive => ReminderCopy(
            l10n.reminderInactiveTitle(childName),
            l10n.reminderInactiveBody,
          ),
        ReminderKind.keepGoing => ReminderCopy(
            l10n.reminderKeepGoingTitle(childName),
            l10n.reminderKeepGoingBody,
          ),
        ReminderKind.none => ReminderCopy(
            l10n.reminderKeepGoingTitle(childName),
            l10n.reminderKeepGoingBody,
          ),
      };
}

class ReminderService {
  ReminderService({required this.store, required this.scheduler});

  final OfflineStore store;
  final ReminderScheduler scheduler;

  Future<bool> isSupported() => scheduler.isSupported();

  /// Turns reminders on (asking the OS for permission) or off.
  /// Returns the state actually achieved — enabling fails silently to `false`
  /// when the platform or the user declines.
  Future<bool> setEnabled(
    bool on, {
    required AppLocalizations l10n,
    DateTime? now,
  }) async {
    if (!on) {
      await store.setRemindersEnabled(false);
      await scheduler.cancelAll();
      return false;
    }
    if (!await scheduler.isSupported()) return false;
    if (!await scheduler.requestPermission()) return false;
    await store.setRemindersEnabled(true);
    await refresh(l10n: l10n, now: now);
    return true;
  }

  Future<void> setTime(
    int hour,
    int minute, {
    required AppLocalizations l10n,
    DateTime? now,
  }) async {
    await store.setReminderTime(hour, minute);
    await refresh(l10n: l10n, now: now);
  }

  /// Re-queues the next few reminders from current progress.
  ///
  /// Local notifications cannot recompute their text when they fire, so the
  /// queue is rebuilt every time the app is opened or an activity completes.
  /// A family who plays today therefore never receives the warning that was
  /// sitting in the queue for them.
  Future<void> refresh({
    required AppLocalizations l10n,
    DateTime? now,
  }) async {
    if (!store.remindersEnabled) {
      await scheduler.cancelAll();
      return;
    }
    if (!await scheduler.isSupported()) return;

    final childId = store.activeChildId;
    if (childId == null) {
      await scheduler.cancelAll();
      return;
    }
    final child = store.childById(childId);
    final when = now ?? DateTime.now();

    final planned = planReminders(
      lastActiveDayKey: store.lastActiveDayKey(childId),
      streak: store.streakFor(childId, now: when),
      shieldUsedWeek: store.streakShieldWeek(childId),
      now: when,
      hour: store.reminderHour,
      minute: store.reminderMinute,
    );

    final notices = [
      for (final p in planned)
        () {
          final copy = ReminderCopy.forKind(
            l10n,
            p.kind,
            childName: child?.nickname ?? '',
            streak: p.streak,
          );
          return ScheduledNotice(
            id: p.id,
            title: copy.title,
            body: copy.body,
            at: p.at,
          );
        }(),
    ];

    await scheduler.replaceAll(notices);
  }
}
