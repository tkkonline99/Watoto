import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/analytics/analytics.dart';

/// Source-level guard against the failure this suite was written for: the
/// build declared 20 event names and emitted only 4. Constants that nothing
/// ever logs are worse than no constants — they read like coverage on a
/// dashboard spec while the funnel is actually empty.
///
/// Deliberately a source scan rather than a runtime check: exercising every
/// emit path (purchase, screen-time lock, PIN reset) through widgets would be
/// slower and flakier than reading the call sites.
void main() {
  test('every declared analytics event has at least one call site', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'run from apps/mobile');

    final sources = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // The declaration file mentions every name by definition.
        .where((f) => !f.path.replaceAll(r'\', '/').endsWith(
              'core/analytics/analytics.dart',
            ))
        .map((f) => f.readAsStringSync())
        .join('\n');

    // Constants are referenced as `AnalyticsEvents.lessonComplete`, so match
    // on the Dart identifier rather than the wire string.
    final identifiers = {
      AnalyticsEvents.onboardingComplete: 'onboardingComplete',
      AnalyticsEvents.lessonComplete: 'lessonComplete',
      AnalyticsEvents.quizComplete: 'quizComplete',
      AnalyticsEvents.storyComplete: 'storyComplete',
      AnalyticsEvents.dailyChallengeComplete: 'dailyChallengeComplete',
      AnalyticsEvents.paywallView: 'paywallView',
      AnalyticsEvents.purchaseAttempt: 'purchaseAttempt',
      AnalyticsEvents.purchaseSuccess: 'purchaseSuccess',
      AnalyticsEvents.parentUnlock: 'parentUnlock',
      AnalyticsEvents.screenTimeLimitHit: 'screenTimeLimitHit',
      AnalyticsEvents.syncFlush: 'syncFlush',
      AnalyticsEvents.exportData: 'exportData',
      AnalyticsEvents.playNowTap: 'playNowTap',
      AnalyticsEvents.nicknameChange: 'nicknameChange',
      AnalyticsEvents.passwordResetRequest: 'passwordResetRequest',
      AnalyticsEvents.pinReset: 'pinReset',
      AnalyticsEvents.questComplete: 'questComplete',
      AnalyticsEvents.badgeUnlock: 'badgeUnlock',
      AnalyticsEvents.levelUp: 'levelUp',
      AnalyticsEvents.appOpen: 'appOpen',
      AnalyticsEvents.activityStart: 'activityStart',
      AnalyticsEvents.activityAbandon: 'activityAbandon',
      AnalyticsEvents.backupExport: 'backupExport',
      AnalyticsEvents.backupRestore: 'backupRestore',
      AnalyticsEvents.narrationUnavailable: 'narrationUnavailable',
    };

    // Every event in the catalog must appear in the map above, or the map
    // silently stops covering new events.
    expect(
      identifiers.length,
      AnalyticsEvents.all.length,
      reason: 'add the new event to this test map too',
    );

    final missing = <String>[];
    for (final entry in identifiers.entries) {
      if (!sources.contains('AnalyticsEvents.${entry.value}')) {
        missing.add(entry.key);
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'declared but never emitted — either log them or delete them: '
          '${missing.join(", ")}',
    );
  });

  test('release builds get a durable analytics sink, not null', () {
    // Regression guard: the provider previously passed
    // `backend: kDebugMode ? DebugAnalyticsBackend() : null`, so a release
    // build recorded nothing anywhere.
    final source =
        File('lib/core/analytics/analytics.dart').readAsStringSync();
    expect(source.contains('StoreAnalyticsBackend('), isTrue);
    expect(
      RegExp(r'backend:\s*kDebugMode\s*\?').hasMatch(source),
      isFalse,
      reason: 'the sink must not be debug-only',
    );
  });

  test('async errors are hooked, not just framework errors', () {
    final source = File('lib/core/crash/crash_reporting.dart').readAsStringSync();
    expect(source.contains('FlutterError.onError'), isTrue);
    expect(
      source.contains('PlatformDispatcher.instance.onError'),
      isTrue,
      reason: 'uncaught async errors vanished without this hook',
    );
  });
}
