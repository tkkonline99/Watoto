import 'dart:convert';

import 'package:http/http.dart' as http;

import '../offline/sync_op.dart';

/// Seam between the sync engine and the network — fakes implement this in
/// tests; the production client adds Firebase-backed auth later without
/// touching callers.
abstract interface class SyncApi {
  /// Returns `clientOpId -> result` (`applied | duplicate |
  /// conflict_server_won | rejected`) for every submitted op.
  Future<Map<String, String>> syncBatch(List<SyncOp> ops);
}

class SyncApiException implements Exception {
  SyncApiException(this.message);
  final String message;

  @override
  String toString() => 'SyncApiException: $message';
}

class WatotoApi implements SyncApi {
  WatotoApi({http.Client? client, String? baseUrl, String? deviceId})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment('WATOTO_API_URL',
                defaultValue: 'http://localhost:3000/v1'),
        _deviceId = deviceId ?? 'dev-device';

  final http.Client _client;
  final String baseUrl;
  final String _deviceId;
  String? _childToken;

  /// Dev-mode child token (the API's POST /auth/dev-token, active until
  /// Firebase is provisioned). The Firebase exchange replaces only this.
  Future<String> _token() async {
    final cached = _childToken;
    if (cached != null) return cached;
    final res = await _client.post(
      Uri.parse('$baseUrl/auth/dev-token'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'role': 'child'}),
    );
    if (res.statusCode >= 300) {
      throw SyncApiException('auth failed (${res.statusCode})');
    }
    final token = (jsonDecode(res.body) as Map)['accessToken'] as String;
    _childToken = token;
    return token;
  }

  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async {
    final token = await _token();
    final res = await _client.post(
      Uri.parse('$baseUrl/sync/batch'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
        'x-device-id': _deviceId,
      },
      body: jsonEncode({'ops': ops.map((o) => o.toJson()).toList()}),
    );
    if (res.statusCode == 401) {
      _childToken = null; // expired — next flush re-authenticates
      throw SyncApiException('unauthorized');
    }
    if (res.statusCode >= 300) {
      throw SyncApiException('sync failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {
      for (final r in body['results'] as List)
        (r as Map)['clientOpId'] as String: r['result'] as String,
    };
  }
}
