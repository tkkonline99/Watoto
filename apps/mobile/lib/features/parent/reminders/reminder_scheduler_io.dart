/// Local-notification scheduler for the platforms that have one.
///
/// Every plugin call is guarded: a device without a notifier, a denied
/// permission, or a test harness all degrade to silence rather than throwing —
/// the reminder is a courtesy, never something the app depends on.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// Android notification channel for practice reminders.
const _channelId = 'watoto_reminders';
const _channelName = 'Practice reminders';
const _channelDescription =
    'Optional reminders for grown-ups about practice streaks.';

class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _tzReady = false;

  bool get _platformHasNotifications =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<bool> _ensureInit() async {
    if (!_platformHasNotifications) return false;
    if (_ready) return true;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested explicitly from the Parent Zone toggle, so
          // the child never meets a system prompt out of nowhere.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);
      _ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureTimezones() async {
    if (_tzReady) return;
    try {
      tzdata.initializeTimeZones();
      _tzReady = true;
    } catch (_) {
      // Leave _tzReady false; scheduling will fall back to a no-op.
    }
  }

  @override
  Future<bool> isSupported() => _ensureInit();

  @override
  Future<bool> requestPermission() async {
    if (!await _ensureInit()) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final darwin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await darwin?.requestPermissions(alert: true, sound: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!await _ensureInit()) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  @override
  Future<void> replaceAll(List<ScheduledNotice> notices) async {
    if (!await _ensureInit()) return;
    await _ensureTimezones();
    await cancelAll();
    if (!_tzReady) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    for (final notice in notices) {
      try {
        await _plugin.zonedSchedule(
          id: notice.id,
          title: notice.title,
          body: notice.body,
          scheduledDate: tz.TZDateTime.from(notice.at, tz.local),
          notificationDetails: details,
          // Inexact on purpose: a practice nudge does not warrant the
          // exact-alarm permission, which invites extra store review — a real
          // cost for a Kids-category app.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('reminder ${notice.id} not scheduled: $e');
        }
      }
    }
  }
}

ReminderScheduler createReminderScheduler() => LocalNotificationScheduler();
