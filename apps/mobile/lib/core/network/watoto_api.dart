import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../offline/sync_op.dart';

/// Seam between the sync engine and the network — fakes implement this in
/// tests; production uses a real token (Firebase) or stays offline-only.
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

typedef TokenProvider = Future<String?> Function({bool forceRefresh});

class WatotoApi implements SyncApi {
  WatotoApi({
    http.Client? client,
    String? baseUrl,
    String? deviceId,
    this.tokenProvider,
    this.timeout = const Duration(seconds: 12),
    bool? allowDevToken,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'WATOTO_API_URL',
              defaultValue: 'http://localhost:3000/v1',
            ),
        _deviceId = deviceId ?? 'dev-device',
        allowDevToken = allowDevToken ?? _defaultAllowDevToken;

  /// Nest `/auth/dev-token` is for local development only. Release and profile
  /// builds never call it — sync stays queued offline until a real token exists.
  static bool get _defaultAllowDevToken {
    if (kReleaseMode) return false;
    return const bool.fromEnvironment(
      'ALLOW_NEST_DEV_TOKEN',
      defaultValue: true,
    );
  }

  final http.Client _client;
  final String baseUrl;
  final String _deviceId;
  final TokenProvider? tokenProvider;
  final Duration timeout;
  final bool allowDevToken;
  String? _childToken;

  /// Prefer Firebase / AuthPort token; else Nest dev-token when allowed.
  Future<String> _token({bool forceRefresh = false}) async {
    final fromAuth = await tokenProvider?.call(forceRefresh: forceRefresh);
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;

    if (!allowDevToken) {
      throw SyncApiException(
        'no auth token (dev-token disabled in this build)',
      );
    }

    if (!forceRefresh) {
      final cached = _childToken;
      if (cached != null) return cached;
    }
    final res = await _client
        .post(
          Uri.parse('$baseUrl/auth/dev-token'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'role': 'child'}),
        )
        .timeout(timeout);
    if (res.statusCode >= 300) {
      throw SyncApiException('auth failed (${res.statusCode})');
    }
    final token = (jsonDecode(res.body) as Map)['accessToken'] as String;
    _childToken = token;
    return token;
  }

  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async {
    Future<http.Response> send(String token) => _client
        .post(
          Uri.parse('$baseUrl/sync/batch'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $token',
            'x-device-id': _deviceId,
          },
          body: jsonEncode({'ops': ops.map((o) => o.toJson()).toList()}),
        )
        .timeout(timeout);

    var token = await _token();
    var res = await send(token);
    if (res.statusCode == 401) {
      _childToken = null;
      token = await _token(forceRefresh: true);
      res = await send(token);
    }
    if (res.statusCode == 401) {
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
