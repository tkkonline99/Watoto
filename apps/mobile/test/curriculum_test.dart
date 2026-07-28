import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/features/curriculum/curriculum_data.dart';
import 'package:watoto_mobile/features/curriculum/subject_catalog.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// The app opens on the welcome screen; jump to the home to exercise the tiles.
void _goHome(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(WatotoApp)),
).read(appRouterProvider).go('/');

/// Scrolls the home list (the outermost Scrollable — the subject grid nests a
/// non-scrolling one inside it) until [target] is on screen.
Future<void> _scrollHomeTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('curriculum data (from curriculum.pptx)', () {
    test('has all 10 stages in order', () {
      expect(curriculumStages, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(curriculumStages[i].stage, i + 1);
      }
    });

    test('maps age to the right stage', () {
      expect(stageForAge(0).stage, 1);
      expect(stageForAge(2).stage, 3);
      expect(stageForAge(5).stage, 6);
      expect(stageForAge(7).stage, 8);
      expect(stageForAge(9).stage, 10);
      expect(stageForAge(10).stage, 10); // clamps to the top stage
    });

    test('every stage has topics, each with activities', () {
      for (final s in curriculumStages) {
        expect(s.topics, isNotEmpty, reason: 'stage ${s.stage}');
        for (final t in s.topics) {
          expect(t.activities, isNotEmpty, reason: '${s.stage}/${t.name}');
        }
      }
    });

    test('activities are transcribed faithfully', () {
      final stage1 = curriculumStages.first.topics.expand((t) => t.activities);
      expect(stage1, contains('Pop floating bubbles'));
      final grade2 = curriculumStages[7].topics.expand((t) => t.activities);
      expect(grade2, contains('Multiplication: arrays & groups'));
    });

    test('stageForBirthYear uses the current year', () {
      expect(stageForBirthYear(DateTime.now().year - 7).stage, 8);
    });
  });

  group('subject catalog (home grid → age picker)', () {
    test('every catalog subject maps to a real topic in some stage', () {
      for (final subject in subjectCatalog) {
        final stages = subject.stagesAvailable();
        expect(stages, isNotEmpty, reason: 'no stage offers ${subject.key}');
        for (final stage in stages) {
          final topic = subject.topicNameFor(stage);
          expect(
            topic,
            isNotNull,
            reason: '${subject.key} @ stage ${stage.stage}',
          );
          // The resolved topic must actually exist in that stage's curriculum.
          expect(stage.topics.map((t) => t.name), contains(topic));
        }
      }
    });

    test('catalog keys are unique', () {
      final keys = subjectCatalog.map((s) => s.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test(
      'daily challenge always resolves to a catalog subject and rotates',
      () {
        final start = DateTime(2026, 1, 1);
        // Every day maps to a real catalog subject...
        for (var d = 0; d < 14; d++) {
          final subject = dailyChallengeSubjectFor(
            start.add(Duration(days: d)),
          );
          expect(subjectCatalog, contains(subject));
        }
        // ...and the challenge is not the same subject every day.
        final picks = {
          for (var d = 0; d < subjectCatalog.length; d++)
            dailyChallengeSubjectFor(start.add(Duration(days: d))).key,
        };
        expect(picks.length, greaterThan(1));
      },
    );
  });

  group('curriculum screen', () {
    setUpAll(() {
      Hive.init(Directory.systemTemp.path);
      // Hold the perpetual savanna ambient drift still so pumpAndSettle works.
      debugDisableSavannaAmbient = true;
      debugDisableMascotAnimation = true;
    });

    testWidgets('home subject card opens the age picker, then drills in', (
      tester,
    ) async {
      final store = await OfflineStore.open(inMemory: true);
      await store.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: DateTime.now().year - 7,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            offlineStoreProvider.overrideWithValue(store),
            syncApiProvider.overrideWithValue(_UnreachableApi()),
          ],
          child: const WatotoApp(),
        ),
      );
      await tester.pumpAndSettle();
      _goHome(tester); // app opens on the welcome screen; enter the home
      await tester.pumpAndSettle();

      // The subject grid sits below the fold, and ensureVisible only reaches
      // widgets the lazy home list has already built — scroll it into view.
      final math = find.text('Math');
      await _scrollHomeTo(tester, math);

      // A plain tap uses the stage inferred from the child's profile and goes
      // straight into the subject detail ("Stage N · Ages …") — no picker.
      await tester.tap(math);
      await tester.pumpAndSettle();
      expect(find.text('How old are you?'), findsNothing);
      expect(find.textContaining('Stage '), findsWidgets);

      // Long-press forces the age picker so families can override the stage
      // for multi-age siblings.
      _goHome(tester);
      await tester.pumpAndSettle();
      await _scrollHomeTo(tester, math);
      await tester.longPress(math);
      await tester.pumpAndSettle();
      expect(find.text('How old are you?'), findsOneWidget);

      // Pick the first offered age band -> drills into that subject's detail
      // screen, which shows the chosen stage/age ("Stage N · Ages …").
      await tester.tap(find.textContaining('Ages ').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Stage '), findsWidgets);

      await store.close();
    });
  });
}
