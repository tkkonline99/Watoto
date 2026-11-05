import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/features/curriculum/subject_i18n.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';

class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// Loads the bundled library JSON from disk for pure-Dart tests
/// (cwd is the package root under `flutter test`).
Future<LibraryRepository> loadFromDisk() async {
  final raw = await File('assets/content/watoto_content_library.json').readAsString();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final items = (json['content'] as List)
      .map((c) => LibraryItem.fromJson(c as Map<String, dynamic>))
      .toList();
  return LibraryRepository(items);
}

void main() {
  group('content library', () {
    test('parses all v0.13.0 items by type', () async {
      final repo = await loadFromDisk();
      // 565 before any authoring, then 626, 636, 648, 660 and 672 as stages
      // 1-9 landed. With stage 10 the whole library hits the build plan:
      // 6 lessons, 4 quizzes and 2 stories for every one of the 57 subjects.
      // 342 + 228 + 114 = 684, and there is nothing left to author.
      expect(repo.all, hasLength(684));
      expect(repo.all.where((i) => i.type == LibraryType.lesson), hasLength(342));
      expect(repo.all.where((i) => i.type == LibraryType.quiz), hasLength(228));
      expect(repo.all.where((i) => i.type == LibraryType.story), hasLength(114));
    });

    test('indexes by stage + subject', () async {
      final repo = await loadFromDisk();
      final s8math = repo.forStageSubject(8, 'Math');
      expect(s8math, isNotEmpty);
      expect(s8math.map((e) => e.id), contains('s08.math.lesson.01'));
      expect(repo.byId['s01.cause.lesson.01']?.subject, 'Cause & Effect');
    });

    test('quiz items carry retry-friendly feedback', () async {
      final repo = await loadFromDisk();
      final quiz = repo.byId['s02.animals.quiz.01']!;
      expect(quiz.questions, isNotEmpty);
      for (final q in quiz.questions) {
        expect(q.correctFeedback, isNotEmpty);
        expect(q.retryFeedback, isNotEmpty);
      }
    });
  });

  group('subject translations', () {
    test('default English returns the source name', () {
      expect(localizedSubject('Math', 'en'), 'Math');
      expect(localizedSubject('Reading & Writing', 'en'), 'Reading & Writing');
    });

    test('French and Swahili exist for every curriculum subject', () async {
      final repo = await loadFromDisk();
      for (final s in repo.all.map((i) => i.subject).toSet()) {
        expect(localizedSubject(s, 'fr'), isNot(s), reason: 'FR missing for "$s"');
        expect(localizedSubject(s, 'sw'), isNot(s), reason: 'SW missing for "$s"');
      }
    });
  });

  group('playable library items record offline', () {
    late OfflineStore store;
    late String childId;

    setUpAll(() => Hive.init(Directory.systemTemp.path));

    setUp(() async {
      store = await OfflineStore.open(inMemory: true);
      final child = await store.completeOnboarding(
        consent: const ConsentRecord(
            coreData: true, aiFeatures: false, voiceRecording: false, recordedAt: null),
        pin: '1234',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: DateTime.now().year - 7,
      );
      childId = child.id;
    });

    tearDown(() async => store.close());

    ProviderContainer container(LibraryRepository repo) {
      final c = ProviderContainer(overrides: [
        offlineStoreProvider.overrideWithValue(store),
        syncApiProvider.overrideWithValue(_UnreachableApi()),
        libraryProvider.overrideWith((ref) async => repo),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('quiz attempt is recorded with xp and a queued sync op', () async {
      final repo = await loadFromDisk();
      final quiz = repo.byId['s02.animals.quiz.01']!;
      await container(repo).read(learningServiceProvider).completeLibraryQuiz(
            quiz,
            scorePct: 100,
            passed: true,
            answers: const [
              {'questionId': 's02.animals.quiz.01.q0', 'selectedIndex': 0},
            ],
            durationS: 5,
          );

      expect(store.lastQuizAttempt(childId, quiz.id)?['passed'], true);
      expect(store.xpFor(childId), quiz.xp);
      final ops = store.pendingOps.where((o) => o.opType == 'quiz_attempt');
      expect(ops, hasLength(1));
      expect(ops.single.payload['quizId'], 's02.animals.quiz.01');
    });

    test('lesson + story completions grant xp and persist', () async {
      final repo = await loadFromDisk();
      final c = container(repo);
      final lesson = repo.byId['s01.cause.lesson.01']!;
      final story = repo.byId['s01.lang.story.01']!;
      final ls = c.read(learningServiceProvider);
      await ls.completeLibraryLesson(lesson, timeSpentS: 30);
      await ls.completeLibraryStory(story);

      expect(store.progressFor(childId, lesson.id)?['status'], 'completed');
      expect(store.hasReadStory(childId, story.id), isTrue);
      expect(store.xpFor(childId), lesson.xp + story.xp);
    });

    test('replaying a lesson compacts duplicate lesson_progress sync ops',
        () async {
      await store.recordLessonCompleted(
        childId: childId,
        lessonId: 's01.cause.lesson.01',
        scorePct: 80,
        timeSpentS: 20,
        xpEarned: 10,
      );
      await store.recordLessonCompleted(
        childId: childId,
        lessonId: 's01.cause.lesson.01',
        scorePct: 100,
        timeSpentS: 25,
        xpEarned: 10,
      );
      final lessonOps = store.pendingOps
          .where((o) =>
              o.opType == 'lesson_progress' &&
              o.payload['lessonId'] == 's01.cause.lesson.01')
          .toList();
      expect(lessonOps, hasLength(1));
      expect(lessonOps.single.payload['scorePct'], 100);
      expect(lessonOps.single.payload['childId'], childId);
    });

    test('deleting a child purges their queued sync ops', () async {
      await store.recordLessonCompleted(
        childId: childId,
        lessonId: 's01.cause.lesson.01',
        scorePct: 100,
        timeSpentS: 20,
        xpEarned: 10,
      );
      expect(
        store.pendingOps.where((o) => o.payload['childId'] == childId),
        isNotEmpty,
      );
      await store.deleteChild(childId);
      expect(
        store.pendingOps.where((o) => o.payload['childId'] == childId),
        isEmpty,
      );
    });
  });
}
