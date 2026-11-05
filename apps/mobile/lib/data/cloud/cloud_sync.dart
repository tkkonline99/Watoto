/// Cloud progress mirror — durable offline queue that can flush to Firestore
/// once Firebase is configured.
///
/// Free offline launch: mirrors progress JSON into app support for reinstall
/// recovery codes. Cloud path: same ops become Firestore writes under
/// `accounts/{uid}/profiles/{profileId}/progress/{itemId}`.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/offline/offline_store.dart';
import '../../core/offline/sync_op.dart';

/// Portable family snapshot for backup / reinstall handoff.
class FamilyBackup {
  const FamilyBackup({
    required this.exportedAt,
    required this.payload,
    required this.recoveryHint,
  });

  final DateTime exportedAt;
  final Map<String, dynamic> payload;
  final String recoveryHint;

  String toJsonString() => jsonEncode({
        'v': 1,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'recoveryHint': recoveryHint,
        'payload': payload,
      });

  factory FamilyBackup.fromJsonString(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return FamilyBackup(
      exportedAt: DateTime.parse(m['exportedAt'] as String),
      recoveryHint: m['recoveryHint'] as String? ?? '',
      payload: (m['payload'] as Map).cast<String, dynamic>(),
    );
  }
}

/// Builds a parent-facing backup from the offline store.
///
/// The payload is [OfflineStore.exportBackupBundle] — the raw, restorable box
/// contents — not [OfflineStore.exportFamilyData]. Those are different jobs:
/// the family export is a readable "download my data" answer that flattens
/// progress into summaries, which is exactly what a restore cannot use. This
/// used to carry the readable one, so "backup for reinstall handoff" produced
/// a file no code could read back.
FamilyBackup buildFamilyBackup(OfflineStore store, {String? email}) {
  final hint = email ?? store.accountEmail ?? 'local-device';
  return FamilyBackup(
    exportedAt: DateTime.now().toUtc(),
    payload: store.exportBackupBundle(),
    recoveryHint: hint,
  );
}

/// Restores a [FamilyBackup] produced by [buildFamilyBackup].
///
/// Accepts either the wrapped backup envelope or a bare bundle, because a
/// parent pasting from a text file will not reliably keep the wrapper.
Future<BackupRestoreResult> restoreFamilyBackup(
  OfflineStore store,
  String raw, {
  bool overwrite = false,
}) async {
  // The export writes "<backup>\n---\n<readable json>"; take the first half.
  final head = raw.split('\n---\n').first.trim();
  final Object? decoded;
  try {
    decoded = jsonDecode(head);
  } on FormatException {
    throw const FormatException('That does not look like a Watoto backup.');
  }
  if (decoded is! Map) {
    throw const FormatException('That does not look like a Watoto backup.');
  }
  final map = decoded.cast<String, dynamic>();
  final payload = map['payload'] is Map
      ? (map['payload'] as Map).cast<String, dynamic>()
      : map;
  return store.restoreBackupBundle(payload, overwrite: overwrite);
}

/// Maps pending offline sync ops into a cloud-shaped batch (for future
/// Firestore writer / Nest batch).
List<Map<String, dynamic>> cloudProgressBatch(List<SyncOp> ops) {
  return [
    for (final op in ops)
      {
        'clientOpId': op.clientOpId,
        'type': op.opType,
        'payload': op.payload,
        'clientUpdatedAt': op.clientUpdatedAt.toUtc().toIso8601String(),
      },
  ];
}

/// Debug-only: log what would upload.
void debugLogCloudFlush(List<SyncOp> ops) {
  if (!kDebugMode) return;
  debugPrint('[cloud] would flush ${ops.length} ops');
  for (final op in ops.take(5)) {
    debugPrint('  ${op.opType} ${op.clientOpId}');
  }
}

/// Bidirectional family backup & progress sync client over HTTPS (NestJS or
/// Firebase Cloud Functions / Firestore REST).
class CloudSyncClient {
  CloudSyncClient({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 12),
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'WATOTO_API_URL',
              defaultValue: 'http://localhost:3000/v1',
            );

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  /// Uploads a portable [FamilyBackup] snapshot for [uid] so another device
  /// signed into the same parent account can pull and merge it.
  Future<bool> pushFamilySnapshot(
    OfflineStore store, {
    required String uid,
    required String idToken,
    String? email,
  }) async {
    final backup = buildFamilyBackup(store, email: email);
    final res = await _client
        .put(
          Uri.parse('$baseUrl/accounts/$uid/backup'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $idToken',
          },
          body: backup.toJsonString(),
        )
        .timeout(timeout);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  /// Pulls the latest cloud [FamilyBackup] for [uid] and merges it
  /// non-destructively into [store].
  Future<BackupRestoreResult> pullAndMergeSnapshot(
    OfflineStore store, {
    required String uid,
    required String idToken,
  }) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/accounts/$uid/backup'),
          headers: {
            'accept': 'application/json',
            'authorization': 'Bearer $idToken',
          },
        )
        .timeout(timeout);
    if (res.statusCode == 404) {
      return const BackupRestoreResult(
        childrenRestored: 0,
        progressRestored: 0,
      );
    }
    if (res.statusCode >= 300) {
      throw StateError('Cloud snapshot fetch failed (${res.statusCode})');
    }
    return restoreFamilyBackup(store, res.body, overwrite: false);
  }
}
