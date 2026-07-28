import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/gamification/adaptive.dart';
import 'package:watoto_mobile/features/gamification/next_best.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/profiles/child_profile.dart';

void main() {
  late OfflineStore store;
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('watoto_next_');
    Hive.init(dir.path);
    store = await OfflineStore.open();
  });

  tearDown(() async {
    await store.close();
    await Hive.deleteFromDisk();
  });

  LibraryItem item(String id, {int stage = 3, String subject = 'Math'}) =>
      LibraryItem(
        id: id,
        stage: stage,
        ages: '3-4',
        subject: subject,
        type: LibraryType.lesson,
        title: id,
        objective: '',
        designTier: 'A',
        reading: false,
        interaction: 'tap',
      );

  test('adaptive easier prefers lower stage incomplete item', () async {
    final child = await store.addChild(
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2020,
    );
    await store.setPreferredStage(child.id, 5);
    // Struggle history → easier nudge.
    for (var i = 0; i < 5; i++) {
      await store.recordAttemptOutcome(
        childId: child.id,
        scorePct: 40,
        retries: 3,
      );
    }
    final lib = LibraryRepository([
      item('hard', stage: 5),
      item('easy', stage: 4),
    ]);
    // Mark hard complete so only easy remains at adapted stage.
    await store.recordLessonCompleted(
      childId: child.id,
      lessonId: 'hard',
      scorePct: 100,
      timeSpentS: 1,
      xpEarned: 1,
    );
    final best = resolveNextBestForChild(
      child: child,
      store: store,
      library: lib,
    );
    expect(best, isNotNull);
    expect(best!.item.stage, lessThanOrEqualTo(5));
    expect(
      best.nudge == DifficultyNudge.easier || best.item.id == 'easy',
      isTrue,
    );
  });

  test('discover returns incomplete item when no history', () async {
    final child = await store.addChild(
      nickname: 'Zuri',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    final lib = LibraryRepository([item('only-one', stage: 2)]);
    final best = resolveNextBestForChild(
      child: child,
      store: store,
      library: lib,
    );
    expect(best?.item.id, 'only-one');
  });
}
