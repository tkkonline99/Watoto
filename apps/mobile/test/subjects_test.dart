library;

/// Every subject a child can study has to be reachable, and has to read in the
/// family's language.
///
/// The home subject tiles used to resolve by keyword and keep only the first
/// matching topic, so 18 of the 57 topics — Cause & Effect, Body Parts,
/// Emotions, Health, Writing and more — had no way in from the home, and the
/// Daily Challenge and progress rings never counted them. The curriculum text
/// on every subject screen was English for every family.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/curriculum/curriculum_data.dart';
import 'package:watoto_mobile/features/curriculum/curriculum_i18n.dart';
import 'package:watoto_mobile/features/curriculum/curriculum_models.dart';
import 'package:watoto_mobile/features/curriculum/subject_catalog.dart';
import 'package:watoto_mobile/features/gamification/daily_challenge.dart';
import 'package:watoto_mobile/features/library/content_i18n.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

class _Offline implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

LibraryItem _lesson(String id, int stage, String subject) => LibraryItem(
      id: id,
      stage: stage,
      ages: '',
      subject: subject,
      type: LibraryType.lesson,
      title: id,
      objective: '',
      designTier: 'parent-led',
      reading: false,
      interaction: 'tap',
      steps: const [
        LessonStep(narration: 'Tap it.', action: 'tap', feedback: 'Yes!'),
      ],
    );

const _consent = ConsentRecord(
  coreData: true,
  aiFeatures: false,
  voiceRecording: false,
  recordedAt: null,
);

void main() {
  group('home subjects', () {
    test('every curriculum topic belongs to a home subject', () {
      final orphans = [
        for (final s in curriculumStages)
          for (final t in s.topics)
            if (homeSubjectFor(t.name) == null) 'stage ${s.stage}: ${t.name}',
      ];
      expect(orphans, isEmpty);
    });

    test('every published topic is reachable from exactly one tile', () {
      for (final stage in publishedCurriculumStages) {
        final reached = [
          for (final subject in subjectCatalog)
            ...subject.topicNamesFor(stage),
        ];
        expect(
          reached.toSet(),
          stage.topics.map((t) => t.name).toSet(),
          reason: 'stage ${stage.stage}',
        );
        expect(reached, hasLength(reached.toSet().length),
            reason: 'stage ${stage.stage} offers a topic under two tiles');
      }
    });

    test('the topics the keyword match used to drop are back', () {
      CurriculumStage stage(int n) => curriculumStages[n - 1];
      SubjectCategory tile(String key) =>
          subjectCatalog.firstWhere((s) => s.key == key);

      expect(tile('science').topicNamesFor(stage(1)),
          containsAll(['Cause & Effect', 'Object Permanence']));
      expect(tile('science').topicNamesFor(stage(2)), contains('Body Parts'));
      expect(tile('math').topicNamesFor(stage(2)), contains('First Numbers'));
      expect(tile('social').topicNamesFor(stage(3)), ['Emotions']);
      expect(tile('science').topicNamesFor(stage(7)), contains('Health'));
      expect(tile('literacy').topicNamesFor(stage(9)), ['Reading', 'Writing']);
      // Stage 4's technology tile used to open Math & Logic, the same topic
      // as the maths tile beside it.
      expect(
        tile('tech').topicNameFor(stage(4)),
        isNot(tile('math').topicNameFor(stage(4))),
      );
    });
  });

  group('curriculum text', () {
    final all = <String>[
      for (final s in curriculumStages) ...[
        s.title,
        s.theme,
        s.designTip,
        s.band,
        if (s.grade != null) s.grade!,
        for (final t in s.topics) ...t.activities,
      ],
    ];

    for (final lang in ['sw', 'fr']) {
      test('is all in $lang', () {
        final untranslated = {
          for (final text in all)
            if (localizedCurriculum(text, lang) == text) text,
        };
        expect(untranslated, isEmpty, reason: untranslated.join('\n'));
      });
    }

    test('stays English in English, and in an unknown language', () {
      expect(localizedCurriculum('Pop floating bubbles', 'en'),
          'Pop floating bubbles');
      expect(localizedCurriculum('Pop floating bubbles', 'xx'),
          'Pop floating bubbles');
      expect(localizedCurriculum('Pop floating bubbles', 'fr_CA'),
          'Éclater des bulles qui flottent');
    });
  });

  group('with a family', () {
    late OfflineStore store;

    setUpAll(() {
      Hive.init(Directory.systemTemp.path);
      debugDisableSavannaAmbient = true;
      debugDisableMascotAnimation = true;
      debugSkipLoginGate = true;
    });

    setUp(() async => store = await OfflineStore.open(inMemory: true));
    tearDown(() async => await store.close());

    test('the daily challenge draws from every topic of its subject',
        () async {
      final child = await store.completeOnboarding(
        consent: _consent,
        pin: '1234',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: DateTime.now().year - 1,
      );
      await store.setPreferredStage(child.id, 2);
      var day = DateTime(2026, 1, 1);
      while (dailyChallengeSubjectFor(day).key != 'math') {
        day = day.add(const Duration(days: 1));
      }
      final library = LibraryRepository([
        _lesson('shapes', 2, 'Colors & Shapes'),
        _lesson('sorting', 2, 'Simple Sorting'),
        _lesson('numbers', 2, 'First Numbers'),
      ]);

      final ids = dailyChallengeCandidates(
        child: child,
        store: store,
        library: library,
        now: day,
      ).map((i) => i.id);
      expect(ids, ['shapes', 'sorting', 'numbers']);
    });

    group('subject screen', () {
      final library = LibraryRepository([
        _lesson('read-1', 9, 'Reading'),
        _lesson('read-2', 9, 'Reading'),
        _lesson('write-1', 9, 'Writing'),
      ]);

      Widget buildApp() => ProviderScope(
            overrides: [
              offlineStoreProvider.overrideWithValue(store),
              syncApiProvider.overrideWithValue(_Offline()),
              libraryProvider.overrideWith((ref) async => library),
              contentI18nProvider
                  .overrideWith((ref) async => ContentI18n(const {})),
            ],
            child: const WatotoApp(),
          );

      void goTo(WidgetTester tester, String location) =>
          ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
              .read(appRouterProvider)
              .go(location);

      Future<String> seed() async => (await store.completeOnboarding(
            consent: _consent,
            pin: '1234',
            nickname: 'Amani',
            avatarKey: 'lion',
            birthYear: DateTime.now().year - 8,
          ))
              .id;

      testWidgets('moves between a subject\'s topics and shows the progress',
          (tester) async {
        final childId = await seed();
        await store.recordLessonCompleted(
          childId: childId,
          lessonId: 'read-1',
          scorePct: 100,
          timeSpentS: 30,
          xpEarned: 10,
        );
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        goTo(tester, '/subject/9/Reading');
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ChoiceChip, 'Reading'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Writing'), findsOneWidget);
        expect(find.text('1 of 2 done'), findsOneWidget);
        expect(find.text('Up next'), findsOneWidget);
        expect(find.text("What we'll explore"), findsOneWidget);
        expect(find.text('Main idea & inferencing'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Writing'));
        await tester.pumpAndSettle();

        expect(find.text('0 of 1 done'), findsOneWidget);
        expect(find.text('Organized paragraphs'), findsOneWidget);
        expect(find.text('Main idea & inferencing'), findsNothing);
      });

      testWidgets('speaks a Swahili family\'s language', (tester) async {
        await seed();
        await store.setLocaleCode('sw');
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        goTo(tester, '/subject/9/Reading');
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ChoiceChip, 'Kuandika'), findsOneWidget);
        expect(find.text('Tutakachogundua'), findsOneWidget);
        expect(find.text('Wazo kuu na kukisia'), findsOneWidget);
        expect(find.text('Main idea & inferencing'), findsNothing);
        expect(find.text('0 kati ya 2 zimekamilika'), findsOneWidget);
      });
    });
  });
}
