import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/option_words.dart';
import 'package:watoto_mobile/features/library/play_stages.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

/// A staged choice used to be three bare emoji with nothing written on them,
/// so "Tap the smiling grown-up" offered 🧑 😠 😊 and the child had to guess
/// which picture the sentence meant. The options are named now — and named in
/// the child's own language, or not at all.

Widget _host(Locale locale, ChoicePlan plan) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChoiceStage(plan: plan, onCompleted: _noop),
        ),
      ),
    );

void _noop() {}

/// The step from image 1: the lesson that started all of this.
ChoicePlan _smilingPlan() =>
    choicePlanFor('s01.lang.lesson.01', 0, 'Tap the smiling grown-up.')!;

void main() {
  group('optionLabel', () {
    test('names a lexicon picture in each language', () {
      expect(optionLabel('smiling', 'en'), 'Smiling');
      expect(optionLabel('smiling', 'sw'), 'Anayetabasamu');
      expect(optionLabel('smiling', 'fr'), 'Souriant');
    });

    test('builds the letter and number templates', () {
      expect(optionLabel('letter a', 'en'), 'Letter A');
      expect(optionLabel('letter a', 'sw'), 'Herufi A');
      expect(optionLabel('number 13', 'fr'), 'Numéro 13');
    });

    test('stays silent rather than falling back to English', () {
      // The nonsense half of a reading minimal pair. There is no Swahili for
      // "bookse" and printing the English would be worse than printing
      // nothing, so nothing is what it returns — in every language, so the
      // three locales cannot drift apart.
      for (final lang in ['en', 'sw', 'fr']) {
        expect(optionLabel('bookse', lang), isNull);
        expect(optionLabel('cepe', lang), isNull);
      }
    });

    test('every choosable lexicon word has a name', () {
      final unnamed = <String>[];
      for (final entry in lexicon.entries) {
        if (!entry.value.choice) continue;
        if (optionWords.containsKey(entry.key)) continue;
        unnamed.add(entry.key);
      }
      expect(
        unnamed,
        isEmpty,
        reason: 'these words can be staged as an answer but would render as a '
            'picture with no name: $unnamed. Add them to optionWords.',
      );
    });

    test('names cover all three languages with no English left in', () {
      for (final entry in optionWords.entries) {
        for (final s in [entry.value.en, entry.value.sw, entry.value.fr]) {
          expect(s.trim(), isNotEmpty, reason: '${entry.key} has a blank name');
        }
      }
    });
  });

  group('a staged choice', () {
    testWidgets('writes the name beside the picture', (tester) async {
      await tester.pumpWidget(_host(const Locale('en'), _smilingPlan()));
      await tester.pump();

      expect(find.text('😊'), findsOneWidget);
      expect(find.text('Smiling'), findsOneWidget);
    });

    testWidgets('names it in Swahili for a Swahili child', (tester) async {
      final plan = _smilingPlan();
      await tester.pumpWidget(_host(const Locale('sw'), plan));
      await tester.pump();

      expect(find.text('Anayetabasamu'), findsOneWidget);
      // The lexicon key itself must not reach the screen.
      for (final o in plan.options) {
        expect(find.text(o.word), findsNothing,
            reason: '"${o.word}" is the English lexicon key');
      }
    });

    testWidgets('names it in French for a French child', (tester) async {
      final plan = _smilingPlan();
      await tester.pumpWidget(_host(const Locale('fr'), plan));
      await tester.pump();

      expect(find.text('Souriant'), findsOneWidget);
      for (final o in plan.options) {
        expect(find.text(o.word), findsNothing);
      }
    });

    testWidgets('leaves a word to read as the word itself', (tester) async {
      // "Tap 'cap'" stages text, not pictures: the glyph *is* the answer, so
      // there is nothing to caption and nothing to translate.
      final plan = choicePlanFor(
        'test.word.1',
        0,
        "'cap' has a SHORT a. Tap 'cap'.",
      )!;
      await tester.pumpWidget(_host(const Locale('fr'), plan));
      await tester.pump();

      for (final o in plan.options) {
        expect(o.isPictorial, isFalse);
        expect(find.text(o.word), findsOneWidget);
      }
      // Not captioned "Casquette" underneath — that would answer the question.
      expect(find.text('Casquette'), findsNothing);
    });
  });

  group('distractors', () {
    test('come from the target\'s own kind, not the whole category', () {
      final plan = _smilingPlan();
      // Every option is a face. The pool used to be all of `people`, which
      // put 👂 Ear up against 😊 Smiling and 😠 Cross.
      for (final o in plan.options) {
        expect(
          lexiconLookup(o.word)!.category,
          'people',
          reason: '${o.word} left the category entirely',
        );
        expect(
          const {'ear', 'eye', 'eyes', 'nose', 'mouth', 'hand', 'hands',
              'foot', 'toes', 'teeth', 'lips', 'lungs', 'head'},
          isNot(contains(o.word)),
          reason: '${o.word} is a body part, not an expression',
        );
      }
    });

    test('a category with interchangeable members is left alone', () {
      // Nothing in `animal` needed splitting: any animal is a fair
      // alternative to any other.
      final plan = choicePlanFor('test.choice.1', 0, 'Tap the elephant.')!;
      expect(plan.options, hasLength(3));
      expect(plan.options[plan.targetIndex].word, 'elephant');
    });
  });
}
