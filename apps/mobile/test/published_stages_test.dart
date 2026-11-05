import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/config/publish_config.dart';
import 'package:watoto_mobile/features/curriculum/curriculum_data.dart';
import 'package:watoto_mobile/features/curriculum/subject_catalog.dart';

/// Guards the published stage ceiling enforced by [maxPublishedStage].
///
/// The decision itself is [maxPublishedStage] and the reasoning lives there.
/// What these tests hold is that the cap is actually *enforced* on every
/// surface a child reaches a stage through — the home age picker, the
/// curriculum chips, and the age→stage mapping — rather than being a constant
/// that one screen happens to respect.
///
/// They are deliberately written against `maxPublishedStage` rather than
/// against a literal stage count so overriding the flag in builds or tests
/// exercises the clamp cleanly.
void main() {
  group('published curriculum', () {
    test('stops at the cap and starts at stage 1', () {
      expect(publishedCurriculumStages.first.stage, 1);
      expect(publishedCurriculumStages.last.stage, maxPublishedStage);
      expect(publishedCurriculumStages, hasLength(maxPublishedStage));
    });

    test('the full curriculum is still intact behind it', () {
      // The parent's reference data must not be trimmed by a publish flag —
      // only what a child is offered.
      expect(curriculumStages, hasLength(10));
    });

    test('no subject offers an unpublished age band', () {
      for (final subject in subjectCatalog) {
        for (final stage in subject.stagesAvailable()) {
          expect(
            stage.stage,
            lessThanOrEqualTo(maxPublishedStage),
            reason: '${subject.englishLabel} offers stage ${stage.stage}, '
                'which this build does not ship',
          );
        }
      }
    });

    test('every subject still has somewhere to go', () {
      // The cap must not silently empty a subject off the home grid.
      for (final subject in subjectCatalog) {
        expect(
          subject.stagesAvailable(),
          isNotEmpty,
          reason: '${subject.englishLabel} has no published stage at all',
        );
      }
    });
  });

  group('age mapping', () {
    test('an older child lands on the top published stage, not past it', () {
      for (final age in [7, 8, 9, 10, 12]) {
        expect(
          stageForAge(age).stage,
          lessThanOrEqualTo(maxPublishedStage),
          reason: 'age $age resolved past the published curriculum',
        );
      }
      expect(stageForAge(12).stage, maxPublishedStage);
    });

    test('ages inside the published band still map to their own stage', () {
      // The clamp must not flatten the band it is meant to preserve.
      expect(stageForAge(0).stage, 1);
      expect(stageForAge(4).stage, 5);
      expect(stageForAge(5).stage, 6);
    });

    test('a negative age is still the first stage', () {
      expect(stageForAge(-1).stage, 1);
    });
  });

  test('the free-stage ceiling cannot exceed what is published', () {
    // PUBLISH_FREE_ONLY unlocks "everything"; everything has to mean the
    // stages that exist, or the paywall copy promises content this build
    // does not contain.
    expect(effectiveFreeStageMax, lessThanOrEqualTo(maxPublishedStage));
  });
}
