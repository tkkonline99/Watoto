/// Web build of the scheduler seam: there is no local-notification path here,
/// so reminders are simply unavailable and the Parent Zone says so.
library;

import 'reminder_scheduler.dart';

ReminderScheduler createReminderScheduler() => const NoopReminderScheduler();
