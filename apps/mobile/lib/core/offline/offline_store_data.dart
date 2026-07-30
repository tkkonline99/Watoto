/// The parent's data rights and the support surface: export, erase,
/// diagnostics, and backup/restore.
part of 'offline_store.dart';

extension OfflineStoreData on OfflineStore {
  // --------------------------------------------------------------- export / erase

  /// Parent data export (local JSON) — no network. Suitable for "download my data".
  Map<String, dynamic> exportFamilyData() {
    final children = this.children.map((c) {
      final id = c.id;
      return {
        'profile': c.toJson(),
        'xp': xpFor(id),
        'streak': streakFor(id),
        'coins': coinsFor(id),
        'stars': totalStars(id),
        'lessonsCompleted': completedLessonCount(id),
        'storiesRead': completedStoryCount(id),
        'progress': [
          for (final e in progressEntriesFor(id))
            {
              'kind': e.kind,
              'at': e.at?.toIso8601String(),
              'timeSpentS': e.timeSpentS,
              'stars': e.stars,
            },
        ],
      };
    }).toList();
    return {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'locale': localeCode,
      'consent': consent.toJson(),
      'plan': entitlementRaw.plan,
      'pendingSyncOps': pendingOps.length,
      'children': children,
    };
  }

  // ---------------------------------------------------------- diagnostics


  List<Map<String, dynamic>> _diagList(String key) {
    final raw = _account.get(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> _appendDiag(String key, Map<String, dynamic> entry) async {
    final list = [..._diagList(key), entry];
    if (list.length > OfflineStore.diagnosticsCap) {
      list.removeRange(0, list.length - OfflineStore.diagnosticsCap);
    }
    await _account.put(key, jsonEncode(list));
  }

  /// Product events recorded since install (newest last).
  List<Map<String, dynamic>> get analyticsLog => _diagList('analyticsLog');

  Future<void> appendAnalyticsEvent(
    String name,
    Map<String, Object?> params, {
    DateTime? at,
  }) =>
      _appendDiag('analyticsLog', {
        'name': name,
        'params': params,
        'at': (at ?? DateTime.now().toUtc()).toIso8601String(),
      });

  /// Non-fatal / fatal errors recorded on this device (newest last).
  List<Map<String, dynamic>> get crashLog => _diagList('crashLog');

  Future<void> appendCrashEvent({
    required String error,
    String? stack,
    bool fatal = false,
    DateTime? at,
  }) =>
      _appendDiag('crashLog', {
        // Truncated: a stack trace is diagnostic, not an archive.
        'error': error.length > 400 ? error.substring(0, 400) : error,
        if (stack != null)
          'stack': stack.length > 2000 ? stack.substring(0, 2000) : stack,
        'fatal': fatal,
        'at': (at ?? DateTime.now().toUtc()).toIso8601String(),
      });

  Future<void> clearDiagnostics() async {
    await _account.delete('analyticsLog');
    await _account.delete('crashLog');
  }

  // ------------------------------------------------------- backup / restore



  /// A **restorable** snapshot of this device's learning data.
  ///
  /// [exportFamilyData] is the human-readable "download my data" answer and
  /// deliberately flattens things; it cannot rebuild a device. This keeps the
  /// raw box contents so a reinstall or a replacement phone can be brought
  /// back to where the child left off — the closest thing to cloud backup an
  /// offline build can offer.
  Map<String, dynamic> exportBackupBundle() {
    final account = <String, String>{};
    for (final k in _account.keys) {
      final key = k as String;
      if (OfflineStore._backupExcludedKeys.contains(key)) continue;
      final v = _account.get(key);
      if (v != null) account[key] = v;
    }
    final progress = <String, String>{};
    for (final k in _progress.keys) {
      final v = _progress.get(k as String);
      if (v != null) progress[k] = v;
    }
    final stats = <String, int>{};
    for (final k in _stats.keys) {
      final v = _stats.get(k as String);
      if (v != null) stats[k] = v;
    }
    return {
      'format': 'watoto.backup',
      'version': OfflineStore.backupFormatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'childCount': children.length,
      'account': account,
      'progress': progress,
      'stats': stats,
    };
  }

  /// Restores a bundle produced by [exportBackupBundle].
  ///
  /// Merge semantics, not replace: existing keys are kept unless
  /// [overwrite] is set, and XP/coin counters take the **higher** of the two
  /// values. Restoring a stale backup should never cost a child progress they
  /// have already made on this device.
  ///
  /// Throws [FormatException] on anything that is not a Watoto backup, so a
  /// parent who picks the wrong file gets told rather than silently nothing.
  Future<BackupRestoreResult> restoreBackupBundle(
    Map<String, dynamic> bundle, {
    bool overwrite = false,
  }) async {
    if (bundle['format'] != 'watoto.backup') {
      throw const FormatException('Not a Watoto backup file.');
    }
    final version = (bundle['version'] as num?)?.toInt() ?? 0;
    if (version > OfflineStore.backupFormatVersion) {
      throw const FormatException(
        'This backup was made by a newer version of Watoto. Update the app first.',
      );
    }
    final account = (bundle['account'] as Map?)?.cast<String, dynamic>() ?? {};
    final progress = (bundle['progress'] as Map?)?.cast<String, dynamic>() ?? {};
    final stats = (bundle['stats'] as Map?)?.cast<String, dynamic>() ?? {};

    var childrenRestored = 0;
    var progressRestored = 0;

    for (final e in account.entries) {
      if (OfflineStore._backupExcludedKeys.contains(e.key)) continue;
      final value = e.value;
      if (value is! String) continue;
      final exists = _account.get(e.key) != null;
      if (exists && !overwrite) continue;
      await _account.put(e.key, value);
      if (e.key.startsWith('child:')) childrenRestored++;
    }
    for (final e in progress.entries) {
      final value = e.value;
      if (value is! String) continue;
      if (_progress.get(e.key) != null && !overwrite) continue;
      await _progress.put(e.key, value);
      progressRestored++;
    }
    // Counters merge by max so a restore never subtracts.
    for (final e in stats.entries) {
      final value = (e.value as num?)?.toInt();
      if (value == null) continue;
      final current = _stats.get(e.key) ?? 0;
      await _stats.put(e.key, value > current ? value : current);
    }
    return BackupRestoreResult(
      childrenRestored: childrenRestored,
      progressRestored: progressRestored,
    );
  }

  /// Soft-delete a child profile and all per-child learning keys on device.
  Future<void> deleteChild(String childId) async {
    await _account.delete('child:$childId');
    final accountKeys = _account.keys
        .where((k) => (k as String).contains(childId))
        .toList();
    for (final k in accountKeys) {
      await _account.delete(k);
    }
    final progressKeys = _progress.keys
        .where((k) => (k as String).contains(':$childId:'))
        .toList();
    await _progress.deleteAll(progressKeys);
    final statKeys = _stats.keys.where((k) {
      final key = k as String;
      return key.endsWith(':$childId') || key.contains(':$childId');
    }).toList();
    await _stats.deleteAll(statKeys);
    if (activeChildId == childId) {
      await _account.delete('activeChildId');
    }
  }

  /// Factory-reset local learning data for all children (keeps PIN/account).
  Future<void> eraseAllLearningData() async {
    await _progress.clear();
    await _queue.clear();
    await _stats.clear();
    for (final child in children) {
      final id = child.id;
      for (final prefix in [
        'preferredStage:',
        'dailyDone:',
        'dailyTarget:',
        'tourDone:',
        'tourPrompted:',
        'seenBadges:',
        'lastPlayed:',
        'avatars:',
        'themes:',
        'theme:',
        'highfive:',
        'stretch:',
        'attempts:',
        'review:',
        'streakDate:',
        'coinsDay:',
        // Progress-derived personalisation: erasing learning data has to take
        // the savanna and the companion with it, or a "cleared" profile still
        // remembers what the child did.
        'decor:',
        'mascotName:',
        'subjects:',
        'cheer:',
        'streakShieldWeek:',
        'streakShieldUsedAt:',
      ]) {
        final keys = _account.keys
            .where((k) => (k as String).startsWith('$prefix$id'))
            .toList();
        for (final k in keys) {
          await _account.delete(k);
        }
      }
    }
  }

  Future<void> _enqueue(SyncOp op) =>
      _queue.put(op.clientOpId, jsonEncode(op.toJson()));

  Future<void> removeOps(Iterable<String> clientOpIds) =>
      _queue.deleteAll(clientOpIds);

  Future<void> close() async {
    await _progress.close();
    await _queue.close();
    await _stats.close();
    await _account.close();
  }
}
