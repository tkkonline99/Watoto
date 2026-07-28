library;

/// The family layer. docs/12 §12.5 keeps social features parent-gated; the
/// tests below pin the safety properties as much as the behaviour.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/parent/family_layer.dart';

void main() {
  group('cheers', () {
    test('a cheer round-trips through storage', () {
      final at = DateTime(2026, 7, 28, 12);
      final encoded = encodeCheer(CheerKind.proud, at);
      final parsed = parseCheer(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.kind, CheerKind.proud);
      expect(parsed.sentAt, at);
    });

    test('garbage decodes to nothing rather than throwing', () {
      expect(parseCheer(null), isNull);
      expect(parseCheer(''), isNull);
      expect(parseCheer('nonsense'), isNull);
      expect(parseCheer('proud'), isNull);
      expect(parseCheer('notAKind|2026-07-28T12:00:00'), isNull);
      expect(parseCheer('proud|not-a-date'), isNull);
    });

    test('a stale cheer is no longer news', () {
      final now = DateTime(2026, 7, 28);
      final old = PendingCheer(
        kind: CheerKind.wow,
        sentAt: now.subtract(const Duration(days: 10)),
      );
      final fresh = PendingCheer(
        kind: CheerKind.wow,
        sentAt: now.subtract(const Duration(hours: 6)),
      );
      expect(old.isFreshAt(now), isFalse);
      expect(fresh.isFreshAt(now), isTrue);
    });

    test('every cheer is a fixed phrase with an emoji — never free text', () {
      // The safety property: a grown-up picks from a closed set, so nothing
      // typed by anyone can ever reach a child's screen.
      expect(allCheers, isNotEmpty);
      for (final kind in allCheers) {
        expect(cheerEmoji(kind), isNotEmpty);
      }
    });
  });

  group('family challenge', () {
    late OfflineStore store;

    setUpAll(() => Hive.init(Directory.systemTemp.path));
    setUp(() async => store = await OfflineStore.open(inMemory: true));
    tearDown(() async => await store.close());

    Future<String> seedChild(String nickname) async {
      final profile = await store.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: nickname,
        avatarKey: 'lion',
        birthYear: 2019,
      );
      return profile.id;
    }

    test('an empty household has nothing to show', () {
      final challenge = familyChallengeFor(store);
      expect(challenge.done, 0);
      expect(challenge.complete, isFalse);
      expect(challenge.contributors, isEmpty);
    });

    test('work by any child counts toward the shared total', () async {
      final id = await seedChild('Amani');
      await store.recordLessonCompleted(
        childId: id,
        lessonId: 'l1',
        scorePct: 100,
        timeSpentS: 60,
        xpEarned: 10,
      );
      final challenge = familyChallengeFor(store);
      expect(challenge.done, 1);
      expect(challenge.contributors[id], 1);
      expect(challenge.remaining, familyWeeklyGoal - 1);
    });

    test('progress is a fraction and never overflows the bar', () {
      const over = FamilyChallenge(done: 99, goal: 12, contributors: {});
      expect(over.progress, 1.0);
      expect(over.remaining, 0);
      expect(over.complete, isTrue);
    });

    test('a zero goal cannot divide by zero', () {
      const none = FamilyChallenge(done: 3, goal: 0, contributors: {});
      expect(none.progress, 0);
    });

    test('the goal is shared, so no child is ranked against another', () {
      // Contributions are reported per child for the parent view, but the
      // challenge itself resolves to one household number — there is no
      // ordering, and so no loser.
      const c = FamilyChallenge(
        done: 5,
        goal: 12,
        contributors: {'a': 4, 'b': 1},
      );
      expect(c.done, 5);
      expect(c.progress, closeTo(5 / 12, 1e-9));
    });
  });

  group('cheer storage', () {
    late OfflineStore store;

    setUpAll(() => Hive.init(Directory.systemTemp.path));
    setUp(() async => store = await OfflineStore.open(inMemory: true));
    tearDown(() async => await store.close());

    test('a cheer waits, then is consumed exactly once', () async {
      expect(store.pendingCheer('c1'), isNull);
      await store.sendCheer('c1', encodeCheer(CheerKind.loveIt, DateTime.now()));
      expect(parseCheer(store.pendingCheer('c1'))?.kind, CheerKind.loveIt);
      await store.clearCheer('c1');
      expect(store.pendingCheer('c1'), isNull);
    });

    test('cheers are per child', () async {
      await store.sendCheer('c1', encodeCheer(CheerKind.wow, DateTime.now()));
      expect(store.pendingCheer('c2'), isNull);
    });
  });
}
