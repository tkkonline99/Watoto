import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/stories/story_models.dart';
import 'package:watoto_mobile/features/stories/story_repository.dart';

const _story = StoryBody(
  id: 'b7e6d5c4-3a2b-4c1d-9e8f-0a1b2c3d4e5f',
  schema: 'watoto.story/1.0',
  title: {'en': 'The Clever Hare'},
  pages: [
    StoryPage(emoji: '🐰', text: {'en': 'Hare was small but very clever.'}),
    StoryPage(emoji: '🌞', text: {'en': 'The sun was hot.'}),
    StoryPage(emoji: '🦁', text: {'en': 'Lion guarded the well.'}),
    StoryPage(emoji: '💡', text: {'en': 'All the animals drank together.'}),
  ],
  xp: 8,
);

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

  Future<String> seedOnboarded() async {
    final child = await store.completeOnboarding(
      consent: const ConsentRecord(
          coreData: true, aiFeatures: false, voiceRecording: false, recordedAt: null),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    return child.id;
  }

  Widget buildApp() => ProviderScope(
        overrides: [
          storyProvider.overrideWith((ref, slug) async => _story),
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_UnreachableApi()),
        ],
        child: const WatotoApp(),
      );

  /// A tall canvas so the home content (incl. the Storybooks card) all lays
  /// out without scrolling in the test viewport.
  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('read a story to the end: XP banked once, story_read op queued',
      (tester) async {
    useTallView(tester);
    final id = await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Home -> Storybooks -> library -> open the story.
    await tester.tap(find.text('Storybooks'));
    await tester.pumpAndSettle();
    expect(find.text('The Clever Hare'), findsWidgets);
    await tester.tap(find.text('The Clever Hare').last);
    await tester.pumpAndSettle();

    // Words render individually (for read-along), so match a word, not the line.
    expect(find.text('Hare'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);

    // Page through: Next x3, then Done on the last page.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('4 / 4'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('The End!'), findsOneWidget);
    expect(find.text('+8 XP'), findsOneWidget);

    expect(store.hasReadStory(id, _story.id), isTrue);
    expect(store.xpFor(id), 8);
    final reads = store.pendingOps.where((o) => o.opType == 'story_read');
    expect(reads, hasLength(1));
    expect(reads.single.payload['storyId'], _story.id);
  });

  testWidgets('reading again does not double-count XP', (tester) async {
    useTallView(tester);
    final id = await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Storybooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Clever Hare').last);
    await tester.pumpAndSettle();

    Future<void> pageToEnd() async {
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    await pageToEnd();
    expect(store.xpFor(id), 8);

    // Read again from the celebration screen.
    await tester.tap(find.text('Read again'));
    await tester.pumpAndSettle();
    await pageToEnd();

    // Still 8 — completion is idempotent per (child, story).
    expect(store.xpFor(id), 8);
    expect(store.pendingOps.where((o) => o.opType == 'story_read'), hasLength(1));
  });
}
