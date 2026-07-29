/// Crash / non-fatal reporting seam (store trust / observability).
///
/// Default: debugPrint only. Wire Firebase Crashlytics by implementing
/// [CrashReportingBackend] and setting [crashReportingBackend].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

abstract interface class CrashReportingBackend {
  void recordError(Object error, StackTrace? stack, {bool fatal = false});
  void log(String message);
  void setCustomKey(String key, Object value);
}

class DebugCrashBackend implements CrashReportingBackend {
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    debugPrint('[crash${fatal ? ":fatal" : ""}] $error');
    if (stack != null) debugPrint('$stack');
  }

  @override
  void log(String message) => debugPrint('[crash:log] $message');

  @override
  void setCustomKey(String key, Object value) =>
      debugPrint('[crash:key] $key=$value');
}

/// Durable backend: keeps the last errors on device so a release build is not
/// silent about its own crashes.
///
/// Without this, release builds discarded every error — no Crashlytics SDK is
/// bundled, and the previous default was a no-op. Parents can now send a
/// support bundle that actually says what broke, and the crash count is
/// visible in the Parent Zone.
class StoreCrashBackend implements CrashReportingBackend {
  StoreCrashBackend(this._append);

  final Future<void> Function({
    required String error,
    String? stack,
    bool fatal,
  }) _append;

  final Map<String, Object> _keys = {};

  /// Custom keys collected so far (device id, locale, screen).
  Map<String, Object> get customKeys => Map.unmodifiable(_keys);

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    // Never let the reporter throw inside an error handler.
    unawaited(
      Future(() => _append(
            error: error.toString(),
            stack: stack?.toString(),
            fatal: fatal,
          )).catchError((_) {}),
    );
    if (kDebugMode) debugPrint('[crash${fatal ? ":fatal" : ""}] $error');
  }

  @override
  void log(String message) {
    if (kDebugMode) debugPrint('[crash:log] $message');
  }

  @override
  void setCustomKey(String key, Object value) => _keys[key] = value;
}

CrashReportingBackend crashReportingBackend =
    kDebugMode ? DebugCrashBackend() : _NoopCrashBackend();

class _NoopCrashBackend implements CrashReportingBackend {
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {}

  @override
  void log(String message) {}

  @override
  void setCustomKey(String key, Object value) {}
}

/// Install error hooks once at bootstrap.
///
/// Covers both halves: [FlutterError.onError] catches errors raised inside the
/// framework (build/layout/paint), and [PlatformDispatcher.onError] catches
/// uncaught **async** errors. The second hook was missing, so every failed
/// Future — sync flushes, TTS calls, file writes — disappeared without trace.
void installCrashHooks() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    crashReportingBackend.recordError(
      details.exception,
      details.stack,
      fatal: true,
    );
    previous?.call(details);
  };

  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashReportingBackend.recordError(error, stack);
    // Returning true marks it handled — the app keeps running, which is right
    // for a child mid-lesson. Chain any previously installed handler first.
    previousPlatform?.call(error, stack);
    return true;
  };
}
