/// The port the reminder service schedules through.
///
/// Kept behind an interface so the policy is testable without a plugin, and so
/// unsupported platforms (web, tests, desktop without a notifier) degrade to
/// silence rather than throwing — the same guarded pattern the app already uses
/// for TTS and sound effects.
library;

/// A reminder ready to hand to the platform, already localized.
class ScheduledNotice {
  const ScheduledNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });

  final int id;
  final String title;
  final String body;
  final DateTime at;
}

abstract interface class ReminderScheduler {
  /// True when this platform can actually post a notification.
  Future<bool> isSupported();

  /// Asks the OS for permission. Returns false when denied or unavailable.
  Future<bool> requestPermission();

  /// Replaces every previously queued reminder with [notices].
  Future<void> replaceAll(List<ScheduledNotice> notices);

  /// Cancels everything this app has queued.
  Future<void> cancelAll();
}

/// Used on platforms without notification support, and in tests.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<ScheduledNotice> notices) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Records what it was asked to do — lets tests assert on scheduling without
/// a platform channel.
class RecordingReminderScheduler implements ReminderScheduler {
  RecordingReminderScheduler({this.supported = true, this.granted = true});

  final bool supported;
  final bool granted;
  final List<ScheduledNotice> scheduled = [];
  int cancelAllCount = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> replaceAll(List<ScheduledNotice> notices) async {
    cancelAllCount++;
    scheduled
      ..clear()
      ..addAll(notices);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }
}
