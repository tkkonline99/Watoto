import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/curriculum/subject_catalog.dart';
import 'package:watoto_mobile/features/gamification/daily_challenge.dart';
import 'package:watoto_mobile/features/gamification/rewards.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/profiles/child_profile.dart';

LibraryItem _item({
  required String id,
  required int stage,
  required String subject,
  LibraryType type = LibraryType.lesson,
}) =>
    LibraryItem(
      id: id,
      stage: stage,
      ages: '5-6',
      subject: subject,
      type: type,
      title: 'Title $id',
      objective: 'obj',
      designTier: 'A',
      reading: false,
      interaction: 'tap',
    );

void main() {
  late OfflineStore store;
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('watoto_daily_');
    Hive.init(dir.path);
    store = await OfflineStore.open();
  });

  tearDown(() async {
    await store.close();
    await Hive.deleteFromDisk();
  });

  test('dailyChallengeSubjectFor rotates by day of year', () {
    final a = dailyChallengeSubjectFor(DateTime(2026, 1, 1));
    final b = dailyChallengeSubjectFor(DateTime(2026, 1, 2));
    expect(a.key, isNot(equals(b.key)));
  });

  test('the challenge does not change in the hour after a spring-forward',
      () {
    // From local midnight a spring-forward day is 23 hours old at 23:00, so a
    // local `inDays` count runs one short until 01:00 for the rest of summer.
    for (final day in [DateTime(2026, 3, 9), DateTime(2026, 3, 30)]) {
      final justAfterMidnight = day.add(const Duration(minutes: 30));
      final noon = DateTime(day.year, day.month, day.day, 12);
      expect(
        dailyChallengeSubjectFor(justAfterMidnight).key,
        dailyChallengeSubjectFor(noon).key,
      );
    }
  });

  test('preferred stage overrides birth-year stage', () async {
    const child = ChildProfile(
      id: 'c1',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2020, // ~6 years in 2026 → stage ~7
      ageBand: AgeBand.b6_8,
    );
    await store.setPreferredStage(child.id, 4);
    expect(stageForChild(child, store).stage, 4);
  });

  test('resolve picks first incomplete item and bonus awards once', () async {
    const childId = 'c1';
    const child = ChildProfile(
      id: childId,
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2020,
      ageBand: AgeBand.b6_8,
    );
    // Force a stage that we control content for.
    await store.setPreferredStage(childId, 6);
    final stage = stageForChild(child, store);
    final subject = dailyChallengeSubjectFor(DateTime(2026, 6, 1));
    final topic = subject.topicNameFor(stage);
    expect(topic, isNotNull);

    final items = [
      _item(id: 'A', stage: stage.stage, subject: topic!),
      _item(id: 'B', stage: stage.stage, subject: topic),
    ];
    final lib = LibraryRepository(items);

    final challenge = resolveDailyChallenge(
      child: child,
      store: store,
      library: lib,
      now: DateTime(2026, 6, 1),
    );
    expect(challenge, isNotNull);
    expect(challenge!.itemId, 'A');
    expect(challenge.completed, isFalse);

    await store.setDailyChallengeTarget(childId, 'A', now: DateTime(2026, 6, 1));

    // Completing A should match and grant bonus once.
    await store.recordLessonCompleted(
      childId: childId,
      lessonId: 'A',
      scorePct: 100,
      timeSpentS: 10,
      xpEarned: 10,
    );
    expect(
      isTodaysChallengeItem(
        itemId: 'A',
        child: child,
        store: store,
        library: lib,
        now: DateTime(2026, 6, 1),
      ),
      isTrue,
    );
    final bonus = await store.markDailyChallengeDone(
      childId,
      'A',
      now: DateTime(2026, 6, 1),
    );
    expect(bonus, OfflineStore.dailyChallengeBonusXp);
    expect(store.xpFor(childId), 10 + OfflineStore.dailyChallengeBonusXp);

    // Second claim same day is a no-op.
    expect(
      await store.markDailyChallengeDone(
        childId,
        'A',
        now: DateTime(2026, 6, 1),
      ),
      0,
    );
    expect(store.dailyChallengeTotalCount(childId), 1);
  });

  test('daily hero badge unlocks after one daily challenge', () {
    const none = BadgeStats(xp: 0, streak: 0, lessons: 0, stories: 0);
    expect(earnedBadges(none).map((b) => b.id), isNot(contains('dailyChallenge')));

    const one = BadgeStats(
      xp: 0,
      streak: 0,
      lessons: 0,
      stories: 0,
      dailyChallenges: 1,
    );
    expect(earnedBadges(one).map((b) => b.id), contains('dailyChallenge'));
  });
}
