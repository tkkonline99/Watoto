import '../network/watoto_api.dart';
import 'offline_store.dart';

/// Drains the offline queue to `POST /v1/sync/batch`. Failures keep ops queued;
/// exponential backoff avoids hammering a down server. The server is idempotent
/// on clientOpId, so re-sends are safe.
class SyncEngine {
  SyncEngine(
    this._store,
    this._api, {
    this.maxQueueFlush = 50,
    this.maxBackoff = const Duration(minutes: 5),
  });

  final OfflineStore _store;
  final SyncApi _api;

  /// Max ops per batch flush (queue cap for a single request).
  final int maxQueueFlush;

  final Duration maxBackoff;

  int _failStreak = 0;
  DateTime? _nextAttemptAt;
  String? lastError;
  DateTime? lastSuccessAt;

  /// Pending ops waiting to sync (for parent dashboard).
  int get pendingCount => _store.pendingOps.length;

  /// Returns the number of ops the server acknowledged (any result).
  Future<int> flush() async {
    final ops = _store.pendingOps;
    if (ops.isEmpty) {
      lastError = null;
      return 0;
    }

    final now = DateTime.now();
    if (_nextAttemptAt != null && now.isBefore(_nextAttemptAt!)) {
      return 0;
    }

    final batch = ops.length > maxQueueFlush
        ? ops.sublist(0, maxQueueFlush)
        : ops;

    try {
      final results = await _api.syncBatch(batch);
      // Every returned op got a definitive answer — none should be re-sent.
      await _store.removeOps(results.keys);
      _failStreak = 0;
      _nextAttemptAt = null;
      lastError = null;
      lastSuccessAt = DateTime.now().toUtc();
      return results.length;
    } on Exception catch (e) {
      _failStreak++;
      lastError = e.toString();
      final seconds = (2 << (_failStreak.clamp(0, 6))).clamp(2, maxBackoff.inSeconds);
      _nextAttemptAt = DateTime.now().add(Duration(seconds: seconds));
      return 0; // offline or server unavailable — queue intact
    }
  }

  /// Clears backoff so the next [flush] runs immediately (e.g. app resume).
  void resetBackoff() {
    _failStreak = 0;
    _nextAttemptAt = null;
  }
}
