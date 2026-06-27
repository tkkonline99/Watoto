import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/features/curriculum/curriculum_data.dart';
import 'package:watoto_mobile/features/curriculum/subject_catalog.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';

class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
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
          expect(topic, isNotNull, reason: '${subject.key} @ stage ${stage.stage}');
          // The resolved topic must actually exist in that stage's curriculum.
          expect(stage.topics.map((t) => t.name), contains(topic));
        }
      }
    });

    test('catalog keys are unique and the daily challenge is Math', () {
      final keys = subjectCatalog.map((s) => s.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
      expect(dailyChallengeSubject.key, 'math');
      // Math is a through-line: it should be offered across many age bands.
      expect(dailyChallengeSubject.stagesAvailable().length, greaterThan(5));
    });
  });

  group('curriculum screen', () {
    setUpAll(() => Hive.init(Directory.systemTemp.path));

    testWidgets('home subject card opens the age picker, then drills in',
        (tester) async {
      final store = await OfflineStore.open(inMemory: true);
      await store.completeOnboarding(
        consent: const ConsentRecord(
            coreData: true, aiFeatures: false, voiceRecording: false, recordedAt: null),
        pin: '1234',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: DateTime.now().year - 7,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_UnreachableApi()),
        ],
        child: const WatotoApp(),
      ));
      await tester.pumpAndSettle();

      // There's no fixed stage now: tapping a subject asks for an age first.
      await tester.tap(find.text('Math'));
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
