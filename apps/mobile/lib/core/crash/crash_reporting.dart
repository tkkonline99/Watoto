/// Crash / non-fatal reporting seam (store trust / observability).
///
/// Default: debugPrint only. Wire Firebase Crashlytics by implementing
/// [CrashReportingBackend] and setting [crashReportingBackend].
library;

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

/// Install FlutterError hooks once at bootstrap.
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
}
