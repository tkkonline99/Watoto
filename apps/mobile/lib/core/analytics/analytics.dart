/// Privacy-preserving analytics seam.
///
/// No advertising IDs, no free-text child content, no third-party trackers by
/// default. Events are coarse funnels (onboarding, lesson complete, paywall)
/// suitable for COPPA / GDPR-K. When Firebase Analytics is wired, swap the
/// backend behind [AnalyticsService] without changing call sites.
///
/// Analytics only emit when the parent has opted in (see OfflineStore).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/offline_providers.dart';
import '../offline/offline_store.dart';

/// Named product events (stable strings for dashboards).
abstract final class AnalyticsEvents {
  static const onboardingComplete = 'onboarding_complete';
  static const lessonComplete = 'lesson_complete';
  static const quizComplete = 'quiz_complete';
  static const storyComplete = 'story_complete';
  static const dailyChallengeComplete = 'daily_challenge_complete';
  static const paywallView = 'paywall_view';
  static const purchaseAttempt = 'purchase_attempt';
  static const purchaseSuccess = 'purchase_success';
  static const parentUnlock = 'parent_unlock';
  static const screenTimeLimitHit = 'screen_time_limit_hit';
  static const syncFlush = 'sync_flush';
  static const exportData = 'export_data';
  static const playNowTap = 'play_now_tap';
  static const nicknameChange = 'nickname_change';
  static const passwordResetRequest = 'password_reset_request';
  static const pinReset = 'pin_reset';
  static const questComplete = 'quest_complete';
  static const badgeUnlock = 'badge_unlock';
  static const levelUp = 'level_up';
  static const appOpen = 'app_open';
  static const activityStart = 'activity_start';
  static const activityAbandon = 'activity_abandon';
  static const backupExport = 'backup_export';
  static const backupRestore = 'backup_restore';
  static const narrationUnavailable = 'narration_unavailable';

  /// Every event this build can emit. Used by the coverage test that keeps
  /// declared events and real call sites from drifting apart again.
  static const all = <String>[
    onboardingComplete,
    lessonComplete,
    quizComplete,
    storyComplete,
    dailyChallengeComplete,
    paywallView,
    purchaseAttempt,
    purchaseSuccess,
    parentUnlock,
    screenTimeLimitHit,
    syncFlush,
    exportData,
    playNowTap,
    nicknameChange,
    passwordResetRequest,
    pinReset,
    questComplete,
    badgeUnlock,
    levelUp,
    appOpen,
    activityStart,
    activityAbandon,
    backupExport,
    backupRestore,
    narrationUnavailable,
  ];
}

/// Coarse, non-PII parameters only (stage ints, content type names, booleans).
class AnalyticsService {
  AnalyticsService({required this.isOptedIn, this.backend});

  final bool Function() isOptedIn;
  final AnalyticsBackend? backend;

  final List<({String name, Map<String, Object?> params, DateTime at})> _log =
      [];

  /// Recent events (debug / parent "what we record" preview). Cap 50.
  List<({String name, Map<String, Object?> params, DateTime at})> get recent =>
      List.unmodifiable(_log);

  void log(String name, [Map<String, Object?> params = const {}]) {
    if (!isOptedIn()) return;
    // Strip anything that looks like free text / email / long ids.
    final safe = <String, Object?>{};
    for (final e in params.entries) {
      final v = e.value;
      if (v is String && v.length > 40) continue;
      if (v is String && v.contains('@')) continue;
      safe[e.key] = v;
    }
    final entry = (name: name, params: safe, at: DateTime.now().toUtc());
    _log.add(entry);
    if (_log.length > 50) _log.removeAt(0);
    backend?.log(name, safe);
    if (kDebugMode) {
      debugPrint('[analytics] $name $safe');
    }
  }
}

/// Pluggable sink (Firebase Analytics, debug console, no-op).
abstract interface class AnalyticsBackend {
  void log(String name, Map<String, Object?> params);
}

class DebugAnalyticsBackend implements AnalyticsBackend {
  @override
  void log(String name, Map<String, Object?> params) {
    debugPrint('[analytics:backend] $name $params');
  }
}

/// Durable sink: appends to the local diagnostics log in the offline store.
///
/// This build ships no third-party analytics SDK, so without a persistent sink
/// a release build recorded **nothing at all** — the in-memory list died with
/// the process. Writing to the store means the parent can see what was
/// recorded, support bundles carry it, and the funnel exists on day one. When
/// Firebase Analytics is wired later, compose the two rather than replacing:
/// `MultiAnalyticsBackend([StoreAnalyticsBackend(...), FirebaseBackend()])`.
class StoreAnalyticsBackend implements AnalyticsBackend {
  StoreAnalyticsBackend(this._append);

  final Future<void> Function(String, Map<String, Object?>) _append;

  @override
  void log(String name, Map<String, Object?> params) {
    // Fire-and-forget: telemetry must never block or fail a learning write.
    unawaited(Future(() => _append(name, params)).catchError((_) {}));
  }
}

/// Fans one event out to several sinks; a throwing sink never blocks the rest.
class MultiAnalyticsBackend implements AnalyticsBackend {
  MultiAnalyticsBackend(this.sinks);

  final List<AnalyticsBackend> sinks;

  @override
  void log(String name, Map<String, Object?> params) {
    for (final s in sinks) {
      try {
        s.log(name, params);
      } on Object {
        // One bad sink must not cost the others their event.
      }
    }
  }
}

final analyticsProvider = Provider<AnalyticsService>((ref) {
  final store = ref.watch(offlineStoreProvider);
  return AnalyticsService(
    isOptedIn: () => store.analyticsOptIn,
    backend: MultiAnalyticsBackend([
      StoreAnalyticsBackend(store.appendAnalyticsEvent),
      if (kDebugMode) DebugAnalyticsBackend(),
    ]),
  );
});
