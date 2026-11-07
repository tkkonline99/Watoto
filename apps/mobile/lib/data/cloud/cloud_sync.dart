/// Cloud progress mirror — durable offline queue that flushes to Firestore
/// when Firebase is initialized (or to the NestJS HTTP API otherwise).
///
/// Free offline launch: mirrors progress JSON into app support for reinstall
/// recovery codes. Cloud path: same ops become Firestore writes under
/// `accounts/{uid}/profiles/{profileId}/progress/{itemId}` matching
/// `backend/firestore.rules`.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/network/watoto_api.dart';
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

/// Writer seam for [FirestoreSyncApi] so unit tests can inspect exact document
/// paths and payloads without requiring a live Firestore emulator.
abstract class FirestoreSyncWriter {
  Future<void> setProfile({
    required String uid,
    required String profileId,
    required Map<String, Object?> data,
  });

  Future<void> setProgress({
    required String uid,
    required String profileId,
    required String itemId,
    required Map<String, Object?> data,
  });
}

/// Production [FirestoreSyncWriter] backed by [FirebaseFirestore].
class SdkFirestoreSyncWriter implements FirestoreSyncWriter {
  SdkFirestoreSyncWriter({FirebaseFirestore? firestore}) {
    _firestore = firestore;
  }

  late final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> setProfile({
    required String uid,
    required String profileId,
    required Map<String, Object?> data,
  }) async {
    await _db
        .collection('accounts')
        .doc(uid)
        .collection('profiles')
        .doc(profileId)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<void> setProgress({
    required String uid,
    required String profileId,
    required String itemId,
    required Map<String, Object?> data,
  }) async {
    await _db
        .collection('accounts')
        .doc(uid)
        .collection('profiles')
        .doc(profileId)
        .collection('progress')
        .doc(itemId)
        .set(data, SetOptions(merge: true));
  }
}

/// Firestore implementation of [SyncApi] that writes child profiles and
/// learning progress to `accounts/{uid}/profiles/{profileId}/progress/{itemId}`
/// in compliance with `backend/firestore.rules`.
class FirestoreSyncApi implements SyncApi {
  FirestoreSyncApi({
    required this.uidProvider,
    this.store,
    FirestoreSyncWriter? writer,
  }) : _writer = writer ?? SdkFirestoreSyncWriter();

  final String? Function() uidProvider;
  final OfflineStore? store;
  final FirestoreSyncWriter _writer;

  static const Set<String> forbiddenProfilePiiKeys = <String>{
    'realName',
    'email',
    'phone',
    'address',
    'geo',
    'photo',
  };

  /// Builds a Firestore-rule-compliant child profile document.
  ///
  /// Enforces `displayName` length 1..40, `ageBand` string, and strips any
  /// forbidden PII fields per `backend/firestore.rules`.
  static Map<String, Object?> buildProfileDocument({
    required String nickname,
    required String ageBand,
    required String avatarKey,
    int? xp,
    int? coins,
    int? streak,
    int? stars,
    DateTime? updatedAt,
  }) {
    final trimmed = nickname.trim();
    final safeName = trimmed.isEmpty
        ? 'Learner'
        : (trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed);
    return <String, Object?>{
      'displayName': safeName,
      'ageBand': ageBand.isEmpty ? '3-5' : ageBand,
      'avatarKey': avatarKey,
      'xp': ?xp,
      'coins': ?coins,
      'streak': ?streak,
      'stars': ?stars,
      'updatedAt': Timestamp.fromDate((updatedAt ?? DateTime.now()).toUtc()),
    };
  }

  /// Extracts the Firestore `progress/{itemId}` document ID and payload from a
  /// queued [SyncOp].
  static ({String profileId, String itemId, Map<String, Object?> data})?
  mapOpToProgressDoc(SyncOp op) {
    final childId = op.payload['childId'] as String?;
    if (childId == null || childId.isEmpty) return null;
    final rawItemId =
        (op.payload['lessonId'] ??
                op.payload['quizId'] ??
                op.payload['storyId'] ??
                op.clientOpId)
            .toString();
    final itemId = rawItemId.isEmpty ? op.clientOpId : rawItemId;
    final cleanPayload = Map<String, Object?>.from(op.payload)
      ..remove('childId');
    return (
      profileId: childId,
      itemId: itemId,
      data: <String, Object?>{
        'clientOpId': op.clientOpId,
        'opType': op.opType,
        ...cleanPayload,
        'updatedAt': Timestamp.fromDate(op.clientUpdatedAt.toUtc()),
      },
    );
  }

  static String _ageBandForBirthYear(int birthYear) {
    final age = DateTime.now().year - birthYear;
    if (age <= 2) return '0-2';
    if (age <= 5) return '3-5';
    if (age <= 7) return '6-7';
    return '8-10';
  }

  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async {
    final uid = uidProvider();
    if (uid == null || uid.isEmpty) {
      // Keep ops queued locally until a session is active.
      return const <String, String>{};
    }

    final localStore = store;
    if (localStore != null) {
      for (final child in localStore.children) {
        final profileDoc = buildProfileDocument(
          nickname: child.nickname,
          ageBand: _ageBandForBirthYear(child.birthYear),
          avatarKey: child.avatarKey,
          xp: localStore.xpFor(child.id),
          coins: localStore.coinsFor(child.id),
          streak: localStore.streakFor(child.id),
          stars: localStore.totalStars(child.id),
        );
        await _writer.setProfile(
          uid: uid,
          profileId: child.id,
          data: profileDoc,
        );
      }
    }

    final results = <String, String>{};

    for (final op in ops) {
      final mapped = mapOpToProgressDoc(op);
      if (mapped == null) {
        results[op.clientOpId] = 'rejected';
        continue;
      }
      await _writer.setProgress(
        uid: uid,
        profileId: mapped.profileId,
        itemId: mapped.itemId,
        data: mapped.data,
      );
      results[op.clientOpId] = 'applied';
    }

    return results;
  }
}

/// Bidirectional family backup & progress sync client over HTTPS (NestJS or
/// Firebase Cloud Functions / Firestore REST).
class CloudSyncClient {
  CloudSyncClient({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       baseUrl =
           baseUrl ??
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
