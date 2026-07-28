import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_models.dart';

/// Runtime localization for content-library strings. The content file holds the
/// English source; locale bundles (assets/i18n/{en,fr,sw}.json) overlay
/// translations keyed by dotted paths (e.g. `s01.cause.lesson.01.title`).
/// Missing keys fall back to English, so partial bundles are always safe.
class ContentI18n {
  ContentI18n(this._byLang);

  final Map<String, Map<String, String>> _byLang;

  String tr(String lang, String key, String fallback) =>
      _byLang[lang]?[key] ?? _byLang['en']?[key] ?? fallback;

  static Future<ContentI18n> load() async {
    Future<Map<String, String>> bundle(String code) async {
      try {
        final raw = await rootBundle.loadString('assets/i18n/$code.json');
        return (jsonDecode(raw) as Map).cast<String, String>();
      } catch (_) {
        return const {};
      }
    }

    return ContentI18n({
      'en': await bundle('en'),
      'fr': await bundle('fr'),
      'sw': await bundle('sw'),
    });
  }
}

final contentI18nProvider = FutureProvider<ContentI18n>((_) => ContentI18n.load());

/// Localized title for an item (English fallback). Pure — pass the loaded
/// bundle and language; safe when [i18n] is still loading (returns English).
String itemTitle(ContentI18n? i18n, String lang, LibraryItem item) =>
    i18n?.tr(lang, '${item.id}.title', item.title) ?? item.title;

/// Convenience view over a [LibraryItem] that returns localized strings for the
/// given language, falling back to the English content embedded in the item.
class LocalizedItem {
  const LocalizedItem(this.item, this._i18n, this.lang);

  final LibraryItem item;
  final ContentI18n? _i18n;
  final String lang;

  String _t(String key, String fallback) =>
      _i18n?.tr(lang, '${item.id}.$key', fallback) ?? fallback;

  String get title => _t('title', item.title);

  String stepNarration(int i) => _t('steps.$i.narration', item.steps[i].narration);
  String stepFeedback(int i) => _t('steps.$i.feedback', item.steps[i].feedback);

  /// The question a choice step puts to the child. Null when the step has
  /// none (the narration is the question).
  String? stepPrompt(int i) {
    final english = item.steps[i].prompt;
    if (english == null) return null;
    return _t('steps.$i.prompt', english);
  }

  /// The answer options, each translated on its own key so the order — and
  /// therefore the recorded correct index — is identical in every language.
  List<String> stepChoices(int i) {
    final english = item.steps[i].choices;
    return [
      for (var o = 0; o < english.length; o++)
        _t('steps.$i.choices.$o', english[o]),
    ];
  }

  String questionPrompt(int i) => _t('questions.$i.prompt', item.questions[i].prompt);
  String questionCorrect(int i) =>
      _t('questions.$i.correctFeedback', item.questions[i].correctFeedback);
  String questionRetry(int i) =>
      _t('questions.$i.retryFeedback', item.questions[i].retryFeedback);
  String optionLabel(int q, int o) =>
      _t('questions.$q.options.$o.label', item.questions[q].options[o].label);

  String pageNarration(int i) => _t('pages.$i.narration', item.pages[i].narration);
}
