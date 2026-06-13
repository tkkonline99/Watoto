import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_models.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_repository.dart';

const _lesson = LessonBody(
  id: '5d3f1a2b-9c4e-4f6a-8b7d-1e2f3a4b5c6d',
  schema: 'watoto.lesson/1.0',
  titleKey: 'lessonCountingTitle',
  blocks: [
    ConceptBlock(textKey: 'lessonCountingTitle', emoji: '🥭'),
    TapToCountBlock(items: 3),
    CheckBlock(
      promptKey: 'checkAnswerPrompt',
      options: [
        CheckOption(text: '2', correct: false),
        CheckOption(text: '3', correct: true),
      ],
    ),
  ],
  completion: LessonCompletion(xp: 10, stars: 1, skills: ['counting.1-10']),
);

/// Simulates being offline: every sync attempt fails, ops must stay queued.
class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
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

  Widget buildApp() => ProviderScope(
        overrides: [
          lessonProvider.overrideWith((ref, slug) async => _lesson),
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_UnreachableApi()),
        ],
        child: const WatotoApp(),
      );

  testWidgets('home shows greeting, subjects, and daily challenge', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Jambo, Amani!'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
  });

  testWidgets('child completes the lesson offline: XP banked, op queued', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Enter the lesson from the Math island.
    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    expect(find.text('Counting 1 to 3'), findsWidgets);

    // Block 1: concept → Next.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Block 2: tap all three mangoes, then Next.
    expect(find.text('Tap each mango to count it!'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('🥭').at(i));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Block 3: wrong answer is forgiving, correct answer completes.
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('So close! Try again!'), findsOneWidget);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);

    // Done → home, with XP banked.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('10 XP'), findsOneWidget);

    // Offline-first contract: completion persisted locally and the sync op
    // is still queued because the (fake) network was unreachable.
    expect(store.xp, 10);
    expect(store.progressFor(_lesson.id)?['status'], 'completed');
    final ops = store.pendingOps;
    expect(ops, hasLength(1));
    expect(ops.single.opType, 'lesson_progress');
    expect(ops.single.payload['lessonId'], _lesson.id);
  });

  testWidgets('locale switches to Swahili', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose your language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();

    expect(find.text('Changamoto ya Leo'), findsOneWidget);
    expect(find.text('Hesabu'), findsOneWidget);
  });
}
