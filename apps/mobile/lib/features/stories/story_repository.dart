import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'story_models.dart';

/// Offline-first story source — bundled sample packs now, drift/Hive cache
/// over the catalog API later, behind this same provider.
class StoryRepository {
  /// The library catalog. In production this comes from
  /// `GET /catalog/stories`; here it lists the bundled sample packs.
  static const catalog = <StorySummary>[
    StorySummary(
      id: 'b7e6d5c4-3a2b-4c1d-9e8f-0a1b2c3d4e5f',
      slug: 'story-hare',
      emoji: '🐰',
      title: {'en': 'The Clever Hare', 'sw': 'Sungura Mwerevu', 'fr': 'Le Lièvre Malin'},
    ),
  ];

  Future<StoryBody> load(String slug) async {
    final raw = await rootBundle.loadString('assets/content/$slug.json');
    return StoryBody.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

final storyRepositoryProvider = Provider<StoryRepository>((_) => StoryRepository());

final storyCatalogProvider =
    Provider<List<StorySummary>>((_) => StoryRepository.catalog);

final storyProvider = FutureProvider.family<StoryBody, String>(
  (ref, slug) => ref.watch(storyRepositoryProvider).load(slug),
);
