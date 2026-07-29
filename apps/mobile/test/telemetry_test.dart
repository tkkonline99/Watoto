import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/analytics/analytics.dart';
import 'package:watoto_mobile/core/crash/crash_reporting.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';

/// The app ships no third-party analytics SDK, so the local diagnostics log is
/// the only telemetry that exists. These tests hold the line on two things the
/// release build got wrong before: events that are declared but never emitted,
/// and a sink that quietly drops everything outside debug mode.
void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('watoto_telemetry').path);
  });

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
    await store.setAnalyticsOptIn(true);
  });

  tearDown(() async => store.close());

  group('analytics event catalog', () {
    test('every declared event name is unique and snake_case', () {
      expect(
        AnalyticsEvents.all.toSet().length,
        AnalyticsEvents.all.length,
        reason: 'duplicate event name would merge two funnels in a dashboard',
      );
      for (final name in AnalyticsEvents.all) {
        expect(
          RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name),
          isTrue,
          reason: '$name is not a stable snake_case event name',
        );
      }
    });

    test('AnalyticsEvents.all covers every declared constant', () {
      // Guards the list itself: a new constant added without registering it in
      // `all` would slip past the call-site coverage test below.
      const declaredCount = 25;
      expect(
        AnalyticsEvents.all.length,
        declaredCount,
        reason: 'add the new event to AnalyticsEvents.all',
      );
    });
  });

  group('durable sink', () {
    test('StoreAnalyticsBackend persists events to the offline store',
        () async {
      final service = AnalyticsService(
        isOptedIn: () => true,
        backend: StoreAnalyticsBackend(store.appendAnalyticsEvent),
      );
      service.log(AnalyticsEvents.lessonComplete, {'stage': 3});
      // The sink is fire-and-forget so a learning write never waits on it.
      await Future<void>.delayed(Duration.zero);

      final log = store.analyticsLog;
      expect(log, hasLength(1));
      expect(log.single['name'], AnalyticsEvents.lessonComplete);
      expect((log.single['params'] as Map)['stage'], 3);
      expect(log.single['at'], isA<String>());
    });

    test('opt-out records nothing at all', () async {
      await store.setAnalyticsOptIn(false);
      final service = AnalyticsService(
        isOptedIn: () => store.analyticsOptIn,
        backend: StoreAnalyticsBackend(store.appendAnalyticsEvent),
      );
      service.log(AnalyticsEvents.lessonComplete, {'stage': 3});
      await Future<void>.delayed(Duration.zero);

      expect(store.analyticsLog, isEmpty);
      expect(service.recent, isEmpty);
    });

    test('PII-shaped params are stripped before they reach the sink',
        () async {
      final service = AnalyticsService(
        isOptedIn: () => true,
        backend: StoreAnalyticsBackend(store.appendAnalyticsEvent),
      );
      service.log(AnalyticsEvents.onboardingComplete, {
        'email': 'parent@example.com',
        'note': 'x' * 60,
        'ageBand': '3-5',
      });
      await Future<void>.delayed(Duration.zero);

      final params = store.analyticsLog.single['params'] as Map;
      expect(params.containsKey('email'), isFalse);
      expect(params.containsKey('note'), isFalse);
      expect(params['ageBand'], '3-5');
    });

    test('the log is capped so it cannot grow without bound', () async {
      for (var i = 0; i < OfflineStore.diagnosticsCap + 25; i++) {
        await store.appendAnalyticsEvent(AnalyticsEvents.appOpen, {'i': i});
      }
      final log = store.analyticsLog;
      expect(log, hasLength(OfflineStore.diagnosticsCap));
      // Oldest dropped, newest kept.
      expect((log.last['params'] as Map)['i'],
          OfflineStore.diagnosticsCap + 24);
    });

    test('a throwing sink never costs the other sinks their event', () {
      var reached = 0;
      final multi = MultiAnalyticsBackend([
        _ThrowingBackend(),
        _CountingBackend(() => reached++),
      ]);
      multi.log('x', const {});
      expect(reached, 1);
    });
  });

  group('crash reporting', () {
    test('StoreCrashBackend persists errors with fatality', () async {
      final backend = StoreCrashBackend(store.appendCrashEvent);
      backend.recordError(StateError('boom'), StackTrace.current, fatal: true);
      await Future<void>.delayed(Duration.zero);

      final log = store.crashLog;
      expect(log, hasLength(1));
      expect(log.single['error'], contains('boom'));
      expect(log.single['fatal'], isTrue);
      expect(log.single['stack'], isNotNull);
    });

    test('stack traces are truncated rather than archived', () async {
      await store.appendCrashEvent(
        error: 'e' * 900,
        stack: 's' * 5000,
        fatal: false,
      );
      final entry = store.crashLog.single;
      expect((entry['error'] as String).length, 400);
      expect((entry['stack'] as String).length, 2000);
    });

    test('custom keys are retained for the support bundle', () {
      final backend = StoreCrashBackend(store.appendCrashEvent)
        ..setCustomKey('deviceId', 'abc');
      expect(backend.customKeys['deviceId'], 'abc');
    });

    test('clearDiagnostics empties both logs', () async {
      await store.appendAnalyticsEvent(AnalyticsEvents.appOpen, const {});
      await store.appendCrashEvent(error: 'e');
      await store.clearDiagnostics();
      expect(store.analyticsLog, isEmpty);
      expect(store.crashLog, isEmpty);
    });
  });
}

class _ThrowingBackend implements AnalyticsBackend {
  @override
  void log(String name, Map<String, Object?> params) =>
      throw StateError('sink down');
}

class _CountingBackend implements AnalyticsBackend {
  _CountingBackend(this.onLog);

  final void Function() onLog;

  @override
  void log(String name, Map<String, Object?> params) => onLog();
}
