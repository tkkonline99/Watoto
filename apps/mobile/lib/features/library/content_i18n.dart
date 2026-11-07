import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_models.dart';

/// The translated locales. English is deliberately absent: it is not an
/// overlay, it is the content library itself.
///
/// `assets/i18n/en.json` is extracted *from* the library by
/// `content/extract_strings.py`, so all 12,191 of its values are the same
/// strings [LocalizedItem] already passes as the fallback — verified key by
/// key in `test/auth_i18n_test.dart`. Shipping it bought a second copy of
/// every English string: about 1 MB of install, a 12,000-entry map on the
/// heap, and a JSON parse at startup, in exchange for no string a child could
/// ever see change. It stays on disk as the translators' catalog and as the
/// coverage source for the depth tests; it is simply not bundled — see the
/// assets list in `pubspec.yaml`.
const translatedLangs = ['fr', 'sw'];

/// Runtime localization for content-library strings. The content file holds the
/// English source; locale bundles (assets/i18n/{fr,sw}.json) overlay
/// translations keyed by dotted paths (e.g. `s01.cause.lesson.01.title`).
/// Missing keys fall back to English, so partial bundles are always safe.
class ContentI18n {
  ContentI18n(this._byLang);

  final Map<String, Map<String, String>> _byLang;

  /// The overlay's string, or [fallback] — which the caller reads off the
  /// English content library, and is therefore what an English key would have
  /// resolved to anyway.
  String tr(String lang, String key, String fallback) =>
      _byLang[lang]?[key] ?? fallback;

  static Future<ContentI18n> load() async {
    // Both bundles at once, and decoded off the UI thread. Each is about a
    // megabyte of JSON, and `jsonDecode` is not cheap on the low-end Android
    // hardware this app is aimed at — on the platform thread it lands as a
    // frozen first frame rather than as a slow one.
    final bundles = await Future.wait(translatedLangs.map(_bundle));
    return ContentI18n({
      for (final (i, lang) in translatedLangs.indexed) lang: bundles[i],
    });
  }

  static Future<Map<String, String>> _bundle(String code) async {
    try {
      final raw = await rootBundle.loadString('assets/i18n/$code.json');
      return await compute(_decodeBundle, raw, debugLabel: 'i18n:$code');
    } catch (_) {
      return const {};
    }
  }
}

/// Top-level so it can cross an isolate boundary.
Map<String, String> _decodeBundle(String raw) =>
    (jsonDecode(raw) as Map).cast<String, String>();

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

  /// The item's note to the grown-up, or null when it has none.
  ///
  /// Every stage-1 and stage-2 item carries one ("Hold baby close and trace
  /// the swirl together") and until CoPlayTip was wired nothing displayed
  /// them, so 342 of these had never been read by a parent.
  String? get parentNote {
    final english = item.parentNote;
    if (english == null || english.isEmpty) return null;
    return _t('parentNote', english);
  }

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

  /// An authored recap question, translated.
  String recapPrompt(int i) => _t('recap.$i.prompt', item.recap[i].prompt);

  /// Recap options, each on its own key so the order — and therefore the
  /// authored answer index — is identical in every language.
  List<String> recapOptions(int i) {
    final english = item.recap[i].options;
    return [
      for (var o = 0; o < english.length; o++)
        _t('recap.$i.options.$o', english[o]),
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

  /// The step's declared picture, described in [lang].
  Visual? stepVisual(int i) {
    final step = item.steps[i];
    return _localizedVisual(
      step.visual,
      'steps.$i',
      // author_visuals.py derives the brief from the narration, or from the
      // prompt where a step has no narration. Describing the picture with the
      // same part of the same step is what keeps the fallback honest.
      () => step.narration.isNotEmpty
          ? stepNarration(i)
          : (stepPrompt(i) ?? stepNarration(i)),
    );
  }

  /// The question's declared picture, described in [lang].
  Visual? questionVisual(int i) => _localizedVisual(
        item.questions[i].visual,
        'questions.$i',
        () => questionPrompt(i),
      );

  /// The story page's declared picture, described in [lang].
  Visual? pageVisual(int i) => _localizedVisual(
        item.pages[i].visual,
        'pages.$i',
        () => pageNarration(i),
      );

  /// [visual] with its `alt` in [lang].
  ///
  /// Three outcomes, in order. A translated brief is used when one exists. In
  /// English the authored brief is used as written. Otherwise — every part in
  /// Swahili and French until the briefs are translated — the description
  /// falls back to the localized text the brief was written from, rather than
  /// to the English brief.
  ///
  /// That last case is the whole point. The English brief was being announced
  /// to a screen reader and printed on screen inside the striped placeholder
  /// on 1,512 parts, in all three languages: a French child heard the English
  /// sentence and then the French one, and a Swahili child read an English
  /// caption where the picture should be. The localized narration is a true
  /// description of the same part and is already translated, so it says
  /// something right in the child's language instead of something right in
  /// somebody else's.
  Visual? _localizedVisual(
    Visual? visual,
    String path,
    String Function() localizedSource,
  ) {
    if (visual == null) return null;
    final translated = _i18n?.tr(lang, '${item.id}.$path.visual.alt', '');
    if (translated != null && translated.isNotEmpty) {
      return visual.withAlt(translated);
    }
    if (lang == 'en') return visual;
    final source = localizedSource().trim();
    return source.isEmpty ? visual : visual.withAlt(source);
  }
}
