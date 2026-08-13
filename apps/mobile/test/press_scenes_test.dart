import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/press_scenes.dart';

/// The 0–1 band's Cause & Effect pages promise a touch in their own text and,
/// until this landed, ignored it: the stage was a flat PNG of a flower that
/// was already grown, so the page asked for something, gave no way to do it,
/// and showed the answer up front.
void main() {
  group('which pages answer a press', () {
    test('a page is pressable exactly when its own text asks for it', () {
      expect(pageInvitesPress('Tap the seed... a flower grows!'), isTrue);
      expect(pageInvitesPress('Press the big red button.'), isTrue);
      expect(pageInvitesPress('Touch the soft blanket.'), isTrue);
      // Narration, not instruction: nothing here is offered to the child.
      expect(pageInvitesPress('The moon is round and bright.'), isFalse);
      expect(pageInvitesPress('Little Duck waddled to the pond.'), isFalse);
    });

    test('only the imperative counts, not the word appearing', () {
      // Whole-word matching, so "tapestry" does not hand a child a tap target
      // with nothing behind it — which teaches that pressing does nothing.
      expect(pageInvitesPress('The tapestry hung on the wall.'), isFalse);
      // Past tense is the narrator describing, not the page offering: "She
      // pressed the flowers in a book" is a sentence about someone else, and
      // making it pressable would promise the child something it cannot do.
      expect(pageInvitesPress('She pressed the flowers in a book.'), isFalse);
      expect(pageInvitesPress('He touched the cold glass.'), isFalse);
      // The bare imperative is the invitation.
      expect(pageInvitesPress('Touch the cold glass.'), isTrue);
    });

    test('the four drawn scenes map to the art they replace', () {
      expect(pressSceneForAsset('img/s01/seed_flower.png'),
          PressScene.seedFlower);
      expect(pressSceneForAsset('img/s01/sky_sun.png'), PressScene.skySun);
      expect(pressSceneForAsset('img/s01/cloud_rain.png'),
          PressScene.cloudRain);
      expect(pressSceneForAsset('img/s01/star.png'), PressScene.star);
      // Everything else keeps its own art and gets the generic press.
      expect(pressSceneForAsset('img/s05/pond.png'), isNull);
      expect(pressSceneForAsset(null), isNull);
    });

    test('every page of Press and See! is answered by a drawn scene', () {
      // The one story built entirely on cause and effect. If an illustration
      // ref is ever renamed, this fails rather than silently dropping that
      // page back to a picture that ignores the child.
      final raw = File('assets/content/watoto_content_library.json')
          .readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final item = (json['content'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == 's01.cause.story.01');
      final pages = (item['pages'] as List).cast<Map<String, dynamic>>();

      expect(pages, hasLength(4));
      for (final p in pages) {
        expect(pageInvitesPress(p['narration'] as String), isTrue,
            reason: 'every page of this story asks the child to tap');
        expect(pressSceneForAsset(p['illustration'] as String?), isNotNull,
            reason: '${p['illustration']} has no drawn scene behind it');
      }
    });
  });

  group('the stage as a tap target', () {
    testWidgets('a press is reported once, and replays keep reporting',
        (tester) async {
      var presses = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PressableStage(
            scene: PressScene.seedFlower,
            semanticLabel: 'Tap the seed... a flower grows!',
            onPressed: () => presses++,
            child: const SizedBox.square(dimension: 150),
          ),
        ),
      ));

      await tester.tap(find.byType(PressableStage));
      await tester.pump();
      expect(presses, 1);

      // Replays are welcome: repeating it is how a one-year-old confirms they
      // caused it. The caller decides what to do with the second press.
      await tester.tap(find.byType(PressableStage));
      await tester.pump();
      expect(presses, 2);

      await tester.pumpAndSettle();
    });

    testWidgets('it announces itself as a button, not as artwork',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PressableStage(
            scene: PressScene.star,
            semanticLabel: 'Tap the star... it twinkles goodnight.',
            child: SizedBox.square(dimension: 150),
          ),
        ),
      ));
      // QuestionScaffold suppresses the stage's own image label when the stage
      // is interactive, so this is the only thing a reader has to go on.
      expect(
        find.bySemanticsLabel('Tap the star... it twinkles goodnight.'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
