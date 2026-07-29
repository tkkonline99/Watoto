library;

/// The savanna as progress surface, and the companion's moods.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/gamification/economy.dart';
import 'package:watoto_mobile/features/gamification/mascot_mood.dart';
import 'package:watoto_mobile/features/gamification/savanna_world.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';

void main() {
  group('the world grows with progress', () {
    test('a brand-new child has an empty savanna', () {
      expect(
        visibleDecorations(purchased: {}, level: 1, subjectsExplored: 0),
        isEmpty,
      );
    });

    test('finishing a first subject puts something in the scene', () {
      final world =
          visibleDecorations(purchased: {}, level: 1, subjectsExplored: 1);
      expect(world.map((d) => d.key), contains('zebra'));
    });

    test('levelling up adds to the scene without spending a coin', () {
      final world =
          visibleDecorations(purchased: {}, level: 3, subjectsExplored: 0);
      expect(world.map((d) => d.key), contains('acacia'));
      expect(world.map((d) => d.key), contains('elephant'));
      expect(world.every((d) => d.cost == 0), isTrue);
    });

    test('bought decorations show up alongside earned ones', () {
      final world = visibleDecorations(
        purchased: {'hut', 'rainbow'},
        level: 5,
        subjectsExplored: 5,
      );
      expect(world.map((d) => d.key), containsAll(['hut', 'rainbow', 'lion']));
    });

    test('an unpurchased shop item stays out of the scene', () {
      final world =
          visibleDecorations(purchased: {}, level: 10, subjectsExplored: 10);
      expect(world.map((d) => d.key), isNot(contains('rainbow')));
    });

    test('the next earned decoration is a concrete goal, then runs out', () {
      expect(
        nextEarnedDecoration(level: 1, subjectsExplored: 0)?.key,
        'zebra',
      );
      expect(
        nextEarnedDecoration(level: 99, subjectsExplored: 99),
        isNull,
      );
    });
  });

  group('the coin sink is actually deep', () {
    test('every shop decoration is priced and unique', () {
      final keys = shopDecorations.map((d) => d.key).toSet();
      expect(keys.length, shopDecorations.length);
      expect(shopDecorations.every((d) => d.cost > 0), isTrue);
    });

    test('buying out the shop takes weeks, not days', () {
      // The avatar shop was ~140 coins against a 30/day cap — about three
      // days, after which coins stopped meaning anything.
      final daysToClear = shopTotalCost / dailyCoinCap;
      expect(daysToClear, greaterThan(14));
    });

    test('prices climb so later goals are worth saving for', () {
      for (var i = 1; i < shopDecorations.length; i++) {
        expect(
          shopDecorations[i].cost,
          greaterThanOrEqualTo(shopDecorations[i - 1].cost),
        );
      }
    });

    test('keys never collide between earned and bought', () {
      final all = allDecorations.map((d) => d.key).toList();
      expect(all.toSet().length, all.length);
    });

    test('every decoration sits inside the scene', () {
      for (final d in allDecorations) {
        expect(d.x, inInclusiveRange(0.0, 1.0), reason: d.key);
        expect(d.y, inInclusiveRange(0.0, 1.0), reason: d.key);
      }
    });
  });

  group('companion moods', () {
    final now = DateTime(2026, 7, 28, 9);

    test('a child who has never played gets a neutral, waiting friend', () {
      expect(
        mascotMoodFor(lastActiveDayKey: null, streak: 0, now: now),
        MascotMood.idle,
      );
    });

    test('a long absence makes the companion sleepy, not cross', () {
      expect(
        mascotMoodFor(lastActiveDayKey: '2026-07-20', streak: 0, now: now),
        MascotMood.sleep,
      );
    });

    test('a good run today makes it proud', () {
      expect(
        mascotMoodFor(lastActiveDayKey: '2026-07-28', streak: 5, now: now),
        MascotMood.cheer,
      );
    });

    test('one day away is curiosity, not alarm', () {
      expect(
        mascotMoodFor(lastActiveDayKey: '2026-07-27', streak: 4, now: now),
        MascotMood.think,
      );
    });
  });

  group('store', () {
    late OfflineStore store;

    setUpAll(() => Hive.init(Directory.systemTemp.path));
    setUp(() async => store = await OfflineStore.open(inMemory: true));
    tearDown(() async => await store.close());

    test('a decoration stays bought', () async {
      expect(store.isDecorationUnlocked('c1', 'hut'), isFalse);
      await store.unlockDecoration('c1', 'hut');
      expect(store.isDecorationUnlocked('c1', 'hut'), isTrue);
    });

    test('the companion keeps the name it was given', () async {
      expect(store.mascotName('c1'), isNull);
      await store.setMascotName('c1', '  Simba  ');
      expect(store.mascotName('c1'), 'Simba');
    });

    test('a blank name clears rather than storing whitespace', () async {
      await store.setMascotName('c1', 'Simba');
      await store.setMascotName('c1', '   ');
      expect(store.mascotName('c1'), isNull);
    });

    test('an over-long name is trimmed to fit the bubble', () async {
      await store.setMascotName('c1', 'A' * 40);
      expect(store.mascotName('c1')!.length, 16);
    });

    test('erasing learning data takes the savanna and the name with it',
        () async {
      // eraseAllLearningData walks real profiles, so seed one.
      final profile = await store.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: 2019,
      );
      final child = profile.id;
      await store.unlockDecoration(child, 'hut');
      await store.setMascotName(child, 'Simba');
      await store.markSubjectCompleted(child, 'Math');

      await store.eraseAllLearningData();

      // A "cleared" profile must not still remember what the child did.
      expect(store.isDecorationUnlocked(child, 'hut'), isFalse);
      expect(store.mascotName(child), isNull);
      expect(store.completedSubjects(child), isEmpty);
    });
  });
}
