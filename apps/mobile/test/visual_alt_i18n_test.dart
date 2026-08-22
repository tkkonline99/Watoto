import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_i18n.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';

/// A visual's `alt` is authored in English and used in two places a child
/// meets: it is the screen-reader label for the stage (§26.6), and it is
/// *printed on screen* inside the striped placeholder wherever the art behind
/// a slot has not been drawn yet — 1,512 parts of the library today.
///
/// Neither was localized. A French child heard the English brief announced and
/// then the French narration; a Swahili child read an English caption in the
/// middle of a Swahili lesson. These hold the fix.
void main() {
  const item = LibraryItem(
    id: 's01.cause.lesson.01',
    stage: 1,
    ages: '0-1',
    subject: 'Cause & Effect',
    type: LibraryType.lesson,
    title: 'Tap to Make a Star',
    objective: '',
    designTier: 'parent-led',
    reading: false,
    interaction: 'tap',
    steps: [
      LessonStep(
        narration: 'Tap the dark sky.',
        action: 'tap',
        feedback: 'A star appears.',
        visual: SlotVisual(
          ref: 'img/s01/step_cause_lesson_01_0.png',
          alt: "The dark sky, from the lesson 'Tap to Make a Star'",
        ),
      ),
    ],
  );

  final fr = ContentI18n({
    'fr': (jsonDecode(File('assets/i18n/fr.json').readAsStringSync()) as Map)
        .cast<String, String>(),
  });

  group('visual alt localization', () {
    test('English keeps the authored brief exactly', () {
      final loc = LocalizedItem(item, fr, 'en');
      expect(loc.stepVisual(0)!.alt,
          "The dark sky, from the lesson 'Tap to Make a Star'");
    });

    test('French describes the picture with the French narration, not the '
        'English brief', () {
      final loc = LocalizedItem(item, fr, 'fr');
      final alt = loc.stepVisual(0)!.alt;
      expect(alt, 'Touche le ciel sombre.');
      expect(alt, loc.stepNarration(0));
      expect(alt, isNot(contains('dark sky')));
    });

    test('a translated brief wins over the narration fallback', () {
      final overlay = ContentI18n({
        'fr': {
          's01.cause.lesson.01.steps.0.visual.alt': 'Un ciel de nuit vide',
        },
      });
      expect(LocalizedItem(item, overlay, 'fr').stepVisual(0)!.alt,
          'Un ciel de nuit vide');
    });

    test('the picture itself is untouched — only its description changes', () {
      final localized = LocalizedItem(item, fr, 'fr').stepVisual(0)!;
      expect(localized, isA<SlotVisual>());
      expect(localized.ref, 'img/s01/step_cause_lesson_01_0.png');
      expect((localized as SlotVisual).assetPath,
          'assets/images/img/s01/step_cause_lesson_01_0.png');
    });

    test('withAlt preserves the mode of every visual kind', () {
      const alt = 'described';
      expect(const TokenVisual(ref: 'sky', alt: 'x').withAlt(alt),
          isA<TokenVisual>());
      expect(const SceneVisual(ref: 'number_line', alt: 'x').withAlt(alt),
          isA<SceneVisual>());
      expect(const SlotVisual(ref: 'img/a.png', alt: 'x').withAlt(alt),
          isA<SlotVisual>());
      expect(const TokenVisual(ref: 'sky', alt: 'x').withAlt(alt).alt, alt);
    });

    test('no part is left describing itself in English to a French reader',
        () {
      final library = parseLibraryItems(
        File('assets/content/watoto_content_library.json').readAsStringSync(),
      );
      final english = <String>{};
      for (final item in library) {
        final loc = LocalizedItem(item, fr, 'fr');
        final frenchNarration = <String>{
          for (var i = 0; i < item.steps.length; i++) loc.stepNarration(i),
          for (var i = 0; i < item.pages.length; i++) loc.pageNarration(i),
          for (var i = 0; i < item.questions.length; i++) loc.questionPrompt(i),
        };
        void check(Visual? localized, Visual? authored) {
          if (localized == null || authored == null) return;
          // The alt is either translated, or it is the localized text of the
          // part it describes. What it must never be is the English brief.
          if (localized.alt == authored.alt &&
              !frenchNarration.contains(localized.alt)) {
            english.add('${item.id}: ${localized.alt}');
          }
        }

        for (var i = 0; i < item.steps.length; i++) {
          check(loc.stepVisual(i), item.steps[i].visual);
        }
        for (var i = 0; i < item.questions.length; i++) {
          check(loc.questionVisual(i), item.questions[i].visual);
        }
        for (var i = 0; i < item.pages.length; i++) {
          check(loc.pageVisual(i), item.pages[i].visual);
        }
      }
      expect(english, isEmpty,
          reason: '${english.length} parts still describe their picture in '
              'English to a French reader, e.g. ${english.take(3)}');
    });
  });
}
