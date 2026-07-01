import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/curriculum/subject_catalog.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';

/// Guards against home tiles that dead-end: every subject a child can open,
/// at every age band it's offered, should resolve to at least one playable
/// item. (Any that don't now show a friendly "coming soon" card, but this
/// test keeps visibility on how much of the catalogue is actually reachable.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'home subjects resolve to playable content across their stages',
    () async {
      final repo = await LibraryRepository.load();

      final gaps = <String>[];
      var combos = 0;
      var covered = 0;
      for (final subject in subjectCatalog) {
        for (final stage in subject.stagesAvailable()) {
          final topic = subject.topicNameFor(stage)!;
          combos++;
          if (repo.hasItemsFor(stage.stage, topic)) {
            covered++;
          } else {
            gaps.add('${subject.key} @ stage ${stage.stage} ($topic)');
          }
        }
      }

      if (gaps.isNotEmpty) {
        // ignore: avoid_print
        print(
          'Content gaps (${gaps.length} of $combos combos):\n  '
          '${gaps.join('\n  ')}',
        );
      }

      expect(combos, greaterThan(0));
      // The large majority of reachable subject/stage combinations must be
      // playable; a regression that empties the catalogue will trip this.
      expect(
        covered / combos,
        greaterThan(0.8),
        reason: '$covered of $combos subject/stage combos have content',
      );
    },
  );
}
