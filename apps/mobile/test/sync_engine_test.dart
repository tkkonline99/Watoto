import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_engine.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';

class _FakeApi implements SyncApi {
  _FakeApi(this._handler);

  final Future<Map<String, String>> Function(List<SyncOp> ops) _handler;
  int calls = 0;
  List<SyncOp> lastBatch = const [];

  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) {
    calls++;
    lastBatch = ops;
    return _handler(ops);
  }
}

void main() {
  late OfflineStore store;

  setUpAll(() => Hive.init(Directory.systemTemp.path));

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  Future<void> seedOps(int n) async {
    for (var i = 0; i < n; i++) {
      await store.recordLessonCompleted(
          childId: 'c1', lessonId: 'L$i', scorePct: 100, timeSpentS: 5, xpEarned: 10);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  test('acknowledged ops leave the queue', () async {
    await seedOps(2);
    final api = _FakeApi(
        (ops) async => {for (final op in ops) op.clientOpId: 'applied'});

    final flushed = await SyncEngine(store, api).flush();

    expect(flushed, 2);
    expect(api.lastBatch, hasLength(2));
    expect(store.pendingOps, isEmpty);
  });

  test('duplicate / conflict / rejected results also dequeue', () async {
    await seedOps(3);
    final api = _FakeApi((ops) async => {
          ops[0].clientOpId: 'duplicate',
          ops[1].clientOpId: 'conflict_server_won',
          ops[2].clientOpId: 'rejected',
        });

    final flushed = await SyncEngine(store, api).flush();

    expect(flushed, 3);
    expect(store.pendingOps, isEmpty);
  });

  test('network failure keeps the queue intact for retry', () async {
    await seedOps(2);
    final api = _FakeApi((ops) async => throw SyncApiException('offline'));
    final engine = SyncEngine(store, api);

    expect(await engine.flush(), 0);
    expect(store.pendingOps, hasLength(2));

    expect(await engine.flush(), 0); // retried, still queued
    expect(api.calls, 2);
    expect(store.pendingOps, hasLength(2));
  });

  test('empty queue never touches the network', () async {
    final api = _FakeApi((ops) async => const {});

    expect(await SyncEngine(store, api).flush(), 0);
    expect(api.calls, 0);
  });
}
