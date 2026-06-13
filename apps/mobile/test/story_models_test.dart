import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/stories/story_models.dart';

const sampleStoryJson = '''
{
  "id": "b7e6d5c4-3a2b-4c1d-9e8f-0a1b2c3d4e5f",
  "schema": "watoto.story/1.0",
  "title": { "en": "The Clever Hare", "sw": "Sungura Mwerevu", "fr": "Le Lièvre Malin" },
  "pages": [
    { "emoji": "🐰", "text": { "en": "Hare was small but very clever.", "sw": "Sungura alikuwa mdogo." } },
    { "emoji": "💡", "text": { "en": "All the animals drank together." } }
  ],
  "completion": { "xp": 8 }
}
''';

void main() {
  test('parses a watoto.story/1.0 body with localized text', () {
    final story =
        StoryBody.fromJson(jsonDecode(sampleStoryJson) as Map<String, dynamic>);

    expect(story.id, 'b7e6d5c4-3a2b-4c1d-9e8f-0a1b2c3d4e5f');
    expect(story.pages, hasLength(2));
    expect(story.xp, 8);
    expect(story.localizedTitle('sw'), 'Sungura Mwerevu');
    expect(story.localizedTitle('fr'), 'Le Lièvre Malin');
  });

  test('falls back to English when a locale is missing', () {
    final story =
        StoryBody.fromJson(jsonDecode(sampleStoryJson) as Map<String, dynamic>);
    // page 2 has no Swahili text -> falls back to English
    expect(story.pages[1].localizedText('sw'), 'All the animals drank together.');
  });

  test('splits page text into words for read-along', () {
    final story =
        StoryBody.fromJson(jsonDecode(sampleStoryJson) as Map<String, dynamic>);
    expect(story.pages[0].words('en'), ['Hare', 'was', 'small', 'but', 'very', 'clever.']);
  });
}
