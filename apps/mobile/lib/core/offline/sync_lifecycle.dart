import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import 'offline_providers.dart';

/// Flushes the offline sync queue on app resume and on a gentle interval.
///
/// Avoids a connectivity package dependency: when the device comes online the
/// next resume/tick succeeds; failures stay silent and the queue is intact.
class SyncLifecycle with WidgetsBindingObserver {
  SyncLifecycle(this._ref);

  final Ref _ref;
  Timer? _timer;
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _flush());
    // Immediate best-effort after attach (startup already flushes once).
    unawaited(_flush());
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_flush());
    }
  }

  Future<void> _flush() async {
    final n = await _ref.read(syncEngineProvider).flush();
    if (n > 0) {
      _ref.read(analyticsProvider).log(
            AnalyticsEvents.syncFlush,
            {'ops': n},
          );
    }
  }
}

final syncLifecycleProvider = Provider<SyncLifecycle>((ref) {
  final life = SyncLifecycle(ref);
  ref.onDispose(life.detach);
  return life;
});
