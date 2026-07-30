library;

/// The reward moment: rating a run, and the cool-down that stops the fifth
/// celebration of a sitting from shouting as loudly as the first.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/gamification/reward_outcome.dart';

void main() {
  group('rating a lesson run', () {
    test('a clean run earns three stars', () {
      expect(starsForLessonRun(steps: 4, mistakes: 0), 3);
    });

    test('a few slips still earn two', () {
      expect(starsForLessonRun(steps: 6, mistakes: 1), 2);
      expect(starsForLessonRun(steps: 6, mistakes: 2), 2);
    });

    test('more than a third wrong drops to one — never zero', () {
      expect(starsForLessonRun(steps: 6, mistakes: 3), 1);
      expect(starsForLessonRun(steps: 3, mistakes: 9), 1);
    });

    test('an ungradeable run is unrated rather than perfect', () {
      // Nothing to get wrong => no stars claimed. Calling every tap-only
      // lesson "perfect" would make the word meaningless.
      expect(starsForLessonRun(steps: 0, mistakes: 0), 0);
    });

    test('score reflects the run, not a hardcoded 100', () {
      expect(scorePctForLessonRun(steps: 4, mistakes: 0), 100);
      expect(scorePctForLessonRun(steps: 4, mistakes: 1), 75);
      expect(scorePctForLessonRun(steps: 4, mistakes: 4), 0);
      // Never negative, however many times they tried.
      expect(scorePctForLessonRun(steps: 2, mistakes: 7), 0);
    });
  });

  group('celebration cool-down', () {
    test('the first few finishes get the full treatment', () {
      for (var i = 0; i < celebrationCooldownAfter; i++) {
        expect(RewardOutcome(sessionIndex: i).brief, isFalse);
      }
    });

    test('later finishes in the same sitting are shortened', () {
      expect(
        const RewardOutcome(sessionIndex: celebrationCooldownAfter).brief,
        isTrue,
      );
    });

    test('a milestone always gets the full treatment', () {
      const late = celebrationCooldownAfter + 3;
      expect(
        const RewardOutcome(sessionIndex: late, levelUp: 4).brief,
        isFalse,
      );
      expect(
        const RewardOutcome(sessionIndex: late, badgeIds: ['streak7']).brief,
        isFalse,
      );
      expect(
        const RewardOutcome(sessionIndex: late, streakSavedDays: 6).brief,
        isFalse,
      );
      expect(
        const RewardOutcome(sessionIndex: late, stars: 3).brief,
        isFalse,
      );
      expect(
        const RewardOutcome(sessionIndex: late, firstInSubject: true).brief,
        isFalse,
      );
    });
  });

  group('streak shield reveal', () {
    late OfflineStore store;

    setUpAll(() => Hive.init(Directory.systemTemp.path));
    setUp(() async => store = await OfflineStore.open(inMemory: true));
    tearDown(() async => await store.close());

    test('a plain completion spends no shield', () async {
      await store.recordLessonCompleted(
        childId: 'c1',
        lessonId: 'l1',
        scorePct: 100,
        timeSpentS: 30,
        xpEarned: 10,
      );
      expect(store.takeShieldJustUsed(), isFalse);
    });

    test('the flag is one-shot so the moment is shown exactly once', () async {
      await store.recordLessonCompleted(
        childId: 'c1',
        lessonId: 'l1',
        scorePct: 100,
        timeSpentS: 30,
        xpEarned: 10,
      );
      // Whatever it was, reading twice must not report it twice.
      store.takeShieldJustUsed();
      expect(store.takeShieldJustUsed(), isFalse);
    });
  });

  group('first time in a subject', () {
    late OfflineStore store;

    setUpAll(() => Hive.init(Directory.systemTemp.path));
    setUp(() async => store = await OfflineStore.open(inMemory: true));
    tearDown(() async => await store.close());

    test('is true until the subject has been visited', () async {
      expect(store.hasCompletedAnyInSubject('c1', 'Reading & Writing'), isFalse);
      await store.markSubjectCompleted('c1', 'Reading & Writing');
      expect(store.hasCompletedAnyInSubject('c1', 'Reading & Writing'), isTrue);
    });

    test('subjects with spaces round-trip intact', () async {
      // Stored as one string: a space separator would split these in half.
      await store.markSubjectCompleted('c1', 'Reading & Writing');
      await store.markSubjectCompleted('c1', 'Technology & Logic');
      expect(
        store.completedSubjects('c1'),
        {'Reading & Writing', 'Technology & Logic'},
      );
    });

    test('is tracked per child', () async {
      await store.markSubjectCompleted('c1', 'Math');
      expect(store.hasCompletedAnyInSubject('c2', 'Math'), isFalse);
    });
  });
}
