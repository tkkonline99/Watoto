import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/auth/entitlements.dart';
import 'package:watoto_mobile/features/gamification/adaptive.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_play.dart';
import 'package:watoto_mobile/features/parent/parent_insights.dart';

void main() {
  group('sandbox IAP gate', () {
    test('defaultPurchaseBridge is sandbox outside release', () {
      // Test process is not kReleaseMode.
      expect(sandboxIapEnabled, isTrue);
      expect(defaultPurchaseBridge(), isA<SandboxPurchaseBridge>());
    });

    test('freePremiumMapSummary mentions free stages', () {
      final s = freePremiumMapSummary(isPremium: false);
      // Free-only launch copy (PUBLISH_FREE_ONLY default).
      expect(s.toLowerCase(), contains('free'));
      expect(s, contains('1–10'));
      expect(freePremiumMapSummary(isPremium: true).toLowerCase(), contains('free'));
    });
  });

  group('explicit step mechanics', () {
    test('prefers mechanic field over English heuristics', () {
      final plan = planStep(
        item: const LibraryItem(
          id: 't1',
          stage: 4,
          ages: '4-5',
          subject: 'Math & Logic',
          type: LibraryType.lesson,
          title: 'T',
          objective: '',
          designTier: 'encourage-effort',
          reading: false,
          interaction: 'tap',
        ),
        stepIndex: 0,
        step: const LessonStep(
          narration: 'Comment ça va?', // FR — no EN keywords
          action: 'play',
          feedback: 'Bravo!',
          mechanic: 'numberAnswer',
          answer: 7,
        ),
      );
      expect(plan.mechanic, StepMechanic.numberAnswer);
      expect(plan.answer, 7);
    });

    test('answer alone without mechanic still works', () {
      final plan = planStep(
        item: const LibraryItem(
          id: 't2',
          stage: 3,
          ages: '',
          subject: 'Math & Logic',
          type: LibraryType.lesson,
          title: 'T',
          objective: '',
          designTier: '',
          reading: false,
          interaction: 'tap',
        ),
        stepIndex: 0,
        step: const LessonStep(
          narration: 'Combien?',
          action: 'x',
          feedback: 'ok',
          answer: 3,
        ),
      );
      expect(plan.mechanic, StepMechanic.numberAnswer);
      expect(plan.answer, 3);
    });
  });

  group('adaptive rules', () {
    test('struggling → easier', () {
      final now = DateTime(2026, 1, 10);
      final hist = [
        for (var i = 0; i < 4; i++)
          AttemptOutcome(
            scorePct: 40,
            retries: 3,
            at: now.subtract(Duration(days: i)),
          ),
      ];
      expect(recommendNudge(hist, now: now), DifficultyNudge.easier);
      expect(stageOffsetFor(DifficultyNudge.easier), -1);
    });

    test('flying → harder', () {
      final now = DateTime(2026, 1, 10);
      final hist = [
        for (var i = 0; i < 4; i++)
          AttemptOutcome(
            scorePct: 95,
            retries: 0,
            at: now.subtract(Duration(days: i)),
          ),
      ];
      expect(recommendNudge(hist, now: now), DifficultyNudge.harder);
    });

    test('clampStage', () {
      expect(clampStage(1, -1), 1);
      expect(clampStage(10, 1), 10);
      expect(clampStage(5, 1), 6);
    });
  });

  group('PIN lockout + export', () {
    late OfflineStore store;

    setUp(() async {
      Hive.init(null);
      store = await OfflineStore.open(inMemory: true);
    });

    tearDown(() async {
      await store.close();
    });

    test('tryPin locks after max failures', () async {
      await store.setPin('1234');
      for (var i = 0; i < OfflineStore.pinMaxAttempts; i++) {
        final r = await store.tryPin('0000');
        if (i < OfflineStore.pinMaxAttempts - 1) {
          expect(r, 'wrong');
        } else {
          expect(r, 'locked');
        }
      }
      expect(store.isPinLocked, isTrue);
      expect(await store.tryPin('1234'), 'locked');
    });

    test('exportFamilyData includes children scaffold', () async {
      await store.completeOnboarding(
        consent: store.consent,
        pin: '9999',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: 2020,
      );
      final data = store.exportFamilyData();
      expect(data['children'], isA<List<dynamic>>());
      expect((data['children'] as List<dynamic>).length, 1);
      expect(data['exportedAt'], isNotNull);
    });

    test('parent insights for quiet week', () async {
      final child = await store.addChild(
        nickname: 'Zuri',
        avatarKey: 'lion',
        birthYear: 2019,
      );
      final insights = buildParentInsights(
        store: store,
        childId: child.id,
        nickname: child.nickname,
      );
      expect(insights, isNotEmpty);
      expect(insights.first.tone, 'nudge');
    });
  });
}
