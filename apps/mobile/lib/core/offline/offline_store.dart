import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'sync_op.dart';

/// Offline-first local store: progress, reward balances, and the outbound
/// sync queue. Every learning write lands here first; the [SyncEngine]
/// drains the queue when the API is reachable (docs/15-offline-sync.md).
///
/// Hive keeps this portable across Android/iOS/Web and trivially testable;
/// the drift/SQLite upgrade slots in behind the same interface when
/// relational queries are needed.
class OfflineStore {
  OfflineStore._(this._progress, this._queue, this._stats);

  final Box<String> _progress; // 'lesson:<id>' / 'quiz:<id>' -> record JSON
  final Box<String> _queue; // clientOpId -> SyncOp JSON
  final Box<int> _stats; // 'xp' -> balance

  static const _uuid = Uuid();

  static Future<OfflineStore> open({bool inMemory = false}) async {
    Future<Box<T>> openBox<T>(String name) => inMemory
        ? Hive.openBox<T>(name, bytes: Uint8List(0))
        : Hive.openBox<T>(name);
    return OfflineStore._(
      await openBox<String>('progress'),
      await openBox<String>('sync_queue'),
      await openBox<int>('stats'),
    );
  }

  int get xp => _stats.get('xp', defaultValue: 0)!;

  Map<String, dynamic>? progressFor(String lessonId) => _read('lesson:$lessonId');

  Map<String, dynamic>? lastQuizAttempt(String quizId) => _read('quiz:$quizId');

  Map<String, dynamic>? _read(String key) {
    final raw = _progress.get(key);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  /// Queued ops, oldest first.
  List<SyncOp> get pendingOps {
    final ops = _queue.values
        .map((raw) =>
            SyncOp.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>()))
        .toList();
    ops.sort((a, b) => a.clientUpdatedAt.compareTo(b.clientUpdatedAt));
    return ops;
  }

  /// Records a lesson completion locally and enqueues the matching sync op.
  Future<void> recordLessonCompleted({
    required String lessonId,
    required int scorePct,
    required int timeSpentS,
    required int xpEarned,
  }) async {
    final now = DateTime.now().toUtc();
    await _progress.put(
      'lesson:$lessonId',
      jsonEncode({
        'lessonId': lessonId,
        'status': 'completed',
        'scorePct': scorePct,
        'timeSpentS': timeSpentS,
        'clientUpdatedAt': now.toIso8601String(),
      }),
    );
    await _grantXp(xpEarned);
    await _enqueue(SyncOp(
      clientOpId: _uuid.v4(),
      opType: 'lesson_progress',
      payload: {
        'lessonId': lessonId,
        'status': 'completed',
        'scorePct': scorePct,
        'timeSpentS': timeSpentS,
      },
      clientUpdatedAt: now,
    ));
  }

  /// Records a quiz attempt (pass or fail — attempts are data) and enqueues
  /// it for server-side authoritative re-grading.
  Future<void> recordQuizAttempt({
    required String quizId,
    required int scorePct,
    required bool passed,
    required List<Map<String, dynamic>> answers,
    required int durationS,
    required int xpEarned,
  }) async {
    final now = DateTime.now().toUtc();
    await _progress.put(
      'quiz:$quizId',
      jsonEncode({
        'quizId': quizId,
        'scorePct': scorePct,
        'passed': passed,
        'attemptedAt': now.toIso8601String(),
      }),
    );
    await _grantXp(xpEarned);
    await _enqueue(SyncOp(
      clientOpId: _uuid.v4(),
      opType: 'quiz_attempt',
      payload: {
        'quizId': quizId,
        'answers': answers,
        'durationS': durationS,
        'scorePct': scorePct,
        'passed': passed,
      },
      clientUpdatedAt: now,
    ));
  }

  Future<void> _grantXp(int amount) async {
    if (amount > 0) await _stats.put('xp', xp + amount);
  }

  Future<void> _enqueue(SyncOp op) =>
      _queue.put(op.clientOpId, jsonEncode(op.toJson()));

  Future<void> removeOps(Iterable<String> clientOpIds) =>
      _queue.deleteAll(clientOpIds);

  Future<void> close() async {
    await _progress.close();
    await _queue.close();
    await _stats.close();
  }
}
