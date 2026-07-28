library;

/// The end-of-lesson recap. Coverage against the real content library matters
/// as much as the logic: a recap that almost never appears is not a feature.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/lesson_recap.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';

LibraryItem _lesson({
  required List<LessonStep> steps,
  bool reading = true,
  int stage = 6,
}) =>
    LibraryItem(
      id: 'test.recap.1',
      stage: stage,
      ages: '6-7',
      subject: 'Math',
      type: LibraryType.lesson,
      title: 'Test lesson',
      objective: '',
      designTier: 'gamify-gently',
      reading: reading,
      interaction: 'tap',
      steps: steps,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('building a recap', () {
    test('draws its questions from the lesson content', () {
      final item = _lesson(
        steps: const [
          LessonStep(
            narration: 'Two groups of four.',
            action: 'tap',
            feedback: '2 x 4 = 8.',
          ),
          LessonStep(
            narration: 'Three groups of four.',
            action: 'tap',
            feedback: '3 x 4 = 12.',
          ),
        ],
      );
      final recap = buildLessonRecap(item);
      expect(recap.length, 2);
      // Every answer is a real answer from the content, present in its options.
      for (final q in recap) {
        expect(q.options, contains(q.options[q.answerIndex]));
        expect(q.options.length, greaterThan(1));
      }
    });

    test('a lesson teaching one fact is not worth interrupting for', () {
      final item = _lesson(
        steps: const [
          LessonStep(
            narration: 'Two groups of four.',
            action: 'tap',
            feedback: '2 x 4 = 8.',
          ),
        ],
      );
      expect(buildLessonRecap(item), isEmpty);
    });

    test('pre-readers get no written quiz', () {
      final item = _lesson(
        reading: false,
        steps: const [
          LessonStep(
            narration: 'Two groups of four.',
            action: 'tap',
            feedback: '2 x 4 = 8.',
          ),
          LessonStep(
            narration: 'Three groups of four.',
            action: 'tap',
            feedback: '3 x 4 = 12.',
          ),
        ],
      );
      expect(buildLessonRecap(item), isEmpty);
      expect(hasLessonRecap(item), isFalse);
    });

    test('the same fact is never asked twice', () {
      final item = _lesson(
        steps: const [
          LessonStep(
            narration: 'Two groups of four.',
            action: 'tap',
            feedback: '2 x 4 = 8.',
          ),
          LessonStep(
            narration: 'Again: two fours.',
            action: 'tap',
            feedback: '2 x 4 = 8.',
          ),
          LessonStep(
            narration: 'Three groups of four.',
            action: 'tap',
            feedback: '3 x 4 = 12.',
          ),
        ],
      );
      final recap = buildLessonRecap(item);
      final answers =
          recap.map((q) => q.options[q.answerIndex].toLowerCase()).toList();
      expect(answers.toSet().length, answers.length);
    });

    test('never asks more than the cap', () {
      final steps = [
        for (var i = 1; i <= 12; i++)
          LessonStep(
            narration: 'Group $i.',
            action: 'tap',
            feedback: '$i x 4 = ${i * 4}.',
          ),
      ];
      expect(buildLessonRecap(_lesson(steps: steps)).length, maxRecapQuestions);
    });

    test('a question never contains its own answer', () {
      // The giveaway case: mid-lesson the line teaches ("That is a SIMILE"),
      // but asked again afterwards it hands the child the answer.
      expect(
        redactAnswer("'As brave as a lion'. That is a SIMILE.", 'SIMILE'),
        "'As brave as a lion'. That is a ___.",
      );
      // A prompt that opened with the answer loses the dangling blank.
      expect(redactAnswer('13. 8 + 5 = ?', '13'), '8 + 5 = ?');
      // Case-insensitive.
      expect(redactAnswer('The answer is Solid.', 'solid'), 'The answer is ___.');
      // Nothing meaningful left.
      expect(redactAnswer('8', '8'), isNull);
    });

    test('no recap question leaks its answer, across the whole library',
        () async {
      final raw = await rootBundle
          .loadString('assets/content/watoto_content_library.json');
      final lessons = parseLibraryItems(raw)
          .where((i) => i.type == LibraryType.lesson);
      for (final item in lessons) {
        for (final q in buildLessonRecap(item)) {
          final answer = q.options[q.answerIndex].toLowerCase();
          expect(
            q.prompt.toLowerCase().contains(answer),
            isFalse,
            reason: '${item.id}: "${q.prompt}" gives away "$answer"',
          );
        }
      }
    });

    test('scoring is a clamped percentage', () {
      expect(recapScorePct(correct: 3, total: 3), 100);
      expect(recapScorePct(correct: 2, total: 3), 67);
      expect(recapScorePct(correct: 0, total: 3), 0);
      // No questions asked is not a failure.
      expect(recapScorePct(correct: 0, total: 0), 100);
    });
  });

  group('coverage against the shipped library', () {
    test('reports how many real lessons can offer a recap', () async {
      final raw = await rootBundle
          .loadString('assets/content/watoto_content_library.json');
      final repo = LibraryRepository(parseLibraryItems(raw));

      final lessons =
          repo.all.where((i) => i.type == LibraryType.lesson).toList();
      final readable = lessons.where((i) => i.reading).toList();
      final withRecap = readable.where(hasLessonRecap).toList();

      // Printed so the number is visible rather than merely asserted — this is
      // the figure that decides whether the feature is worth its screen space.
      // ignore: avoid_print
      print(
        'recap coverage: ${withRecap.length}/${readable.length} readable '
        'lessons (${lessons.length} lessons total, '
        '${(withRecap.length / readable.length * 100).toStringAsFixed(1)}%)',
      );

      expect(lessons, isNotEmpty);
      expect(readable, isNotEmpty);
      // A floor, not a target: if a content change drops recap coverage
      // through this, the feature has quietly stopped existing.
      expect(
        withRecap.length / readable.length,
        greaterThan(0.25),
        reason: 'recap should reach a meaningful share of readable lessons',
      );
    });
  });
}
