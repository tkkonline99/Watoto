import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/config/publish_config.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/auth/entitlements.dart';
import 'package:watoto_mobile/features/gamification/economy.dart';
import 'package:watoto_mobile/features/gamification/stars.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/gamification/continue_learning.dart';

void main() {
  group('stars', () {
    test('thresholds match design quality bands', () {
      expect(starsFromScorePct(100), 3);
      expect(starsFromScorePct(80), 2);
      expect(starsFromScorePct(50), 1);
      expect(starsFromScorePct(20), 0);
    });
  });

  group('economy', () {
    test('daily coin cap is enforced', () {
      expect(cappedCoinGrant(requested: 10, alreadyEarnedToday: 25), 5);
      expect(cappedCoinGrant(requested: 10, alreadyEarnedToday: 30), 0);
      expect(cappedCoinGrant(requested: 3, alreadyEarnedToday: 0), 3);
    });
  });

  group('entitlements', () {
    test('publish free-only unlocks every published stage; premium always '
        'unlocks', () {
      // Default PUBLISH_FREE_ONLY=true so a no-IAP store launch is playable.
      // "All stages" now means all *published* stages: this build stops at
      // maxPublishedStage, and a free ceiling above that would advertise
      // content the build does not contain (test/published_stages_test.dart).
      expect(isStageUnlocked(3, Entitlement.free), isTrue);
      expect(isStageUnlocked(5, Entitlement.free), isTrue);
      expect(isStageUnlocked(maxPublishedStage, Entitlement.free), isTrue);
      expect(
        isStageUnlocked(
          10,
          const Entitlement(
            plan: 'premium',
            entitlementExpiry: null,
            isPremium: true,
          ),
        ),
        isTrue,
      );
    });
  });

  group('store coins/stars/screen/premium', () {
    late OfflineStore store;
    late Directory dir;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('watoto_econ_');
      Hive.init(dir.path);
      store = await OfflineStore.open();
    });

    tearDown(() async {
      await store.close();
      await Hive.deleteFromDisk();
    });

    test('coins grant with daily cap and spend', () async {
      const c = 'c1';
      expect(await store.grantCoins(c, 20), 20);
      expect(await store.grantCoins(c, 20), 10); // cap 30
      expect(store.coinsFor(c), 30);
      expect(await store.spendCoins(c, 15), isTrue);
      expect(store.coinsFor(c), 15);
      expect(await store.spendCoins(c, 100), isFalse);
    });

    test('quiz stars accumulate best-of', () async {
      const c = 'c1';
      await store.recordQuizAttempt(
        childId: c,
        quizId: 'Q1',
        scorePct: 70,
        passed: true,
        answers: const [],
        durationS: 5,
        xpEarned: 10,
        stars: 2,
      );
      expect(store.totalStars(c), 2);
      await store.recordQuizAttempt(
        childId: c,
        quizId: 'Q1',
        scorePct: 100,
        passed: true,
        answers: const [],
        durationS: 5,
        xpEarned: 5,
        stars: 3,
      );
      expect(store.totalStars(c), 3); // +1 delta
      expect(store.starsForQuiz(c, 'Q1'), 3);
    });

    test('screen time soft limit', () async {
      await store.setScreenTimeLimitMinutes(1);
      expect(store.isScreenTimeExceeded(), isFalse);
      await store.addScreenTimeSeconds(60);
      expect(store.isScreenTimeExceeded(), isTrue);
      await store.grantScreenTimeGrace(minutes: 10);
      expect(store.isScreenTimeExceeded(), isFalse);
    });

    test('local premium entitlement', () async {
      expect(store.entitlementRaw.isPremium, isFalse);
      await store.setLocalPremium(true);
      expect(store.entitlementRaw.isPremium, isTrue);
      expect(store.hadPremiumBefore, isTrue);
    });

    test('continue learning picks next incomplete', () async {
      const c = 'c1';
      const items = [
        LibraryItem(
          id: 'A',
          stage: 1,
          ages: '0-1',
          subject: 'Sensory',
          type: LibraryType.lesson,
          title: 'One',
          objective: '',
          designTier: 'A',
          reading: false,
          interaction: 'tap',
        ),
        LibraryItem(
          id: 'B',
          stage: 1,
          ages: '0-1',
          subject: 'Sensory',
          type: LibraryType.lesson,
          title: 'Two',
          objective: '',
          designTier: 'A',
          reading: false,
          interaction: 'tap',
        ),
      ];
      final lib = LibraryRepository(items);
      await store.setLastPlayed(
        childId: c,
        itemId: 'A',
        stage: 1,
        subject: 'Sensory',
      );
      await store.recordLessonCompleted(
        childId: c,
        lessonId: 'A',
        scorePct: 100,
        timeSpentS: 5,
        xpEarned: 10,
      );
      final next = resolveContinueLearning(
        childId: c,
        store: store,
        library: lib,
      );
      expect(next?.itemId, 'B');
    });
  });
}
