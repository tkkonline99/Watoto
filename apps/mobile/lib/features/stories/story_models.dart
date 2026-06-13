/// Story body model — `watoto.story/1.0`. Content text is inline-localized
/// per page (en/sw/fr), mirroring how localized content packs ship offline
/// (docs/11 §11.6); UI chrome uses ARB strings instead.
library;

class StoryBody {
  const StoryBody({
    required this.id,
    required this.schema,
    required this.title,
    required this.pages,
    required this.xp,
  });

  final String id;
  final String schema;
  final Map<String, String> title;
  final List<StoryPage> pages;
  final int xp;

  String localizedTitle(String lang) => title[lang] ?? title['en'] ?? '';

  factory StoryBody.fromJson(Map<String, dynamic> json) => StoryBody(
        id: json['id'] as String,
        schema: json['schema'] as String,
        title: _localeMap(json['title']),
        pages: (json['pages'] as List<dynamic>)
            .map((p) => StoryPage.fromJson(p as Map<String, dynamic>))
            .toList(),
        xp: (json['completion'] as Map<String, dynamic>?)?['xp'] as int? ?? 5,
      );
}

class StoryPage {
  const StoryPage({required this.emoji, required this.text});

  final String emoji;
  final Map<String, String> text;

  String localizedText(String lang) => text[lang] ?? text['en'] ?? '';

  /// Words for read-along highlighting.
  List<String> words(String lang) =>
      localizedText(lang).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  factory StoryPage.fromJson(Map<String, dynamic> json) => StoryPage(
        emoji: json['emoji'] as String? ?? '📖',
        text: _localeMap(json['text']),
      );
}

Map<String, String> _localeMap(Object? raw) =>
    (raw as Map).map((k, v) => MapEntry(k as String, v as String));

/// Lightweight catalog entry for the library list (no need to load full bodies).
/// [id] matches the story body's id so read-state can be shown without loading.
class StorySummary {
  const StorySummary({
    required this.id,
    required this.slug,
    required this.emoji,
    required this.title,
  });

  final String id;
  final String slug;
  final String emoji;
  final Map<String, String> title;

  String localizedTitle(String lang) => title[lang] ?? title['en'] ?? '';
}
