library;

/// Every question a child reads must be translatable, and the translations
/// must line up option-for-option — a French child picking option 2 has to be
/// picking the same answer an English child would.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _bundle(String lang) => jsonDecode(
      File('assets/i18n/$lang.json').readAsStringSync(),
    ) as Map<String, dynamic>;

List<Map<String, dynamic>> _lessons() {
  final raw =
      File('assets/content/watoto_content_library.json').readAsStringSync();
  final content =
      (jsonDecode(raw) as Map<String, dynamic>)['content'] as List<dynamic>;
  return [
    for (final e in content)
      if ((e as Map<String, dynamic>)['type'] == 'lesson') e,
  ];
}

/// Subjects whose answers *are* the English being taught (phonics tokens,
/// spellings, idioms). The translator re-authors these with the narration, as
/// they already did for rhymes ("Fan!" → "Nain !" → "Saka!"), so they are not
/// expected to have mechanical translations.
const _languageSubjects = {
  'Reading', 'Reading & Writing', 'Writing', 'Writing & Grammar',
  'Language & Literacy', 'Phonological Awareness', 'Vocabulary',
  'Early Language',
};

/// Steps still awaiting the translator: the ones whose options *are* the
/// English being taught — phonics blends ('st', 'bl'), the plural -s, prefixes
/// ('re-do'), English sentences being read, idioms, and the rhyme family,
/// which has to be re-authored per language. Lower this as translation lands;
/// it must never rise.
const int _awaitingTranslation = 10;

void main() {
  final lessons = _lessons();
  final en = _bundle('en');
  final fr = _bundle('fr');
  final sw = _bundle('sw');

  test('every question and option is exposed as an English key', () {
    final missing = <String>[];
    for (final item in lessons) {
      final steps = (item['steps'] as List?) ?? const [];
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i] as Map<String, dynamic>;
        final choices = (step['choices'] as List?) ?? const [];
        if (choices.isEmpty) continue;
        if (step['prompt'] != null &&
            !en.containsKey('${item['id']}.steps.$i.prompt')) {
          missing.add('${item['id']}.steps.$i.prompt');
        }
        for (var o = 0; o < choices.length; o++) {
          final key = '${item['id']}.steps.$i.choices.$o';
          if (!en.containsKey(key)) missing.add(key);
        }
      }
    }
    expect(missing, isEmpty, reason: 'untranslatable strings:\n'
        '${missing.take(20).join('\n')}');
  });

  test('translated steps are complete — never half a screen in English', () {
    // A step is translated or it is not; a French question above English
    // options would be worse than leaving the screen in English.
    final partial = <String>[];
    var awaiting = 0;

    for (final item in lessons) {
      final steps = (item['steps'] as List?) ?? const [];
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i] as Map<String, dynamic>;
        final choices = (step['choices'] as List?) ?? const [];
        if (choices.isEmpty) continue;

        final keys = <String>[
          if (step['prompt'] != null) '${item['id']}.steps.$i.prompt',
          for (var o = 0; o < choices.length; o++)
            '${item['id']}.steps.$i.choices.$o',
        ];

        for (final entry in {'fr': fr, 'sw': sw}.entries) {
          final have = keys.where(entry.value.containsKey).length;
          if (have == keys.length) continue;
          if (have == 0) {
            if (entry.key == 'fr') awaiting++;
            continue;
          }
          partial.add('${entry.key} ${item['id']} step$i: '
              '$have of ${keys.length} keys');
        }
      }
    }

    expect(partial, isEmpty, reason: 'half-translated screens:\n'
        '${partial.take(20).join('\n')}');
    expect(
      awaiting,
      lessThanOrEqualTo(_awaitingTranslation),
      reason: 'more steps are awaiting translation than when this was written',
    );
  });

  test('untranslated steps are only the language lessons', () {
    final unexpected = <String>[];
    for (final item in lessons) {
      final steps = (item['steps'] as List?) ?? const [];
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i] as Map<String, dynamic>;
        final choices = (step['choices'] as List?) ?? const [];
        if (choices.isEmpty) continue;
        final translated = fr.containsKey('${item['id']}.steps.$i.choices.0');
        if (!translated &&
            !_languageSubjects.contains(item['subject'] as String)) {
          unexpected.add('${item['id']} (${item['subject']}) step$i');
        }
      }
    }
    expect(unexpected, isEmpty, reason: 'these are not language lessons and '
        'should have been translated:\n${unexpected.take(20).join('\n')}');
  });

  test('an option never translates to the same text as another option', () {
    // Two identical buttons would make the question unanswerable.
    final clashes = <String>[];
    for (final item in lessons) {
      final steps = (item['steps'] as List?) ?? const [];
      for (var i = 0; i < steps.length; i++) {
        final choices = ((steps[i] as Map<String, dynamic>)['choices'] as List?)
            ?? const [];
        if (choices.isEmpty) continue;
        for (final entry in {'fr': fr, 'sw': sw}.entries) {
          final rendered = [
            for (var o = 0; o < choices.length; o++)
              entry.value['${item['id']}.steps.$i.choices.$o'] ?? choices[o],
          ].map((e) => '$e'.toLowerCase()).toList();
          if (rendered.toSet().length != rendered.length) {
            clashes.add('${entry.key} ${item['id']} step$i: $rendered');
          }
        }
      }
    }
    expect(clashes, isEmpty, reason: clashes.take(20).join('\n'));
  });
}
