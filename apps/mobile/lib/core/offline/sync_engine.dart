import '../network/watoto_api.dart';
import 'offline_store.dart';

/// Drains the offline queue to `POST /v1/sync/batch`. Failures are silent
/// by design: ops stay queued and the next trigger (app start, post-write)
/// retries. The server is idempotent on clientOpId, so re-sends are safe.
class SyncEngine {
  SyncEngine(this._store, this._api);

  final OfflineStore _store;
  final SyncApi _api;

  /// Returns the number of ops the server acknowledged (any result).
  Future<int> flush() async {
    final ops = _store.pendingOps;
    if (ops.isEmpty) return 0;
    try {
      final results = await _api.syncBatch(ops);
      // Every returned op got a definitive answer (applied / duplicate /
      // conflict_server_won / rejected) — none should be re-sent.
      await _store.removeOps(results.keys);
      return results.length;
    } on Exception {
      return 0; // offline or server unavailable — queue intact
    }
  }
}
