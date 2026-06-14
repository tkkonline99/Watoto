import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_models.dart';

/// Loads and indexes the bundled playable content library
/// (assets/content/watoto_content_library.json). In production this is served
/// by the catalog API and cached offline; here it ships as a bundled asset.
class LibraryRepository {
  LibraryRepository(this._items)
      : byId = {for (final i in _items) i.id: i};

  final List<LibraryItem> _items;
  final Map<String, LibraryItem> byId;

  List<LibraryItem> get all => _items;

  /// Playable items for a given stage + subject, lessons first then quizzes
  /// then stories.
  List<LibraryItem> forStageSubject(int stage, String subject) {
    final list = _items
        .where((i) => i.stage == stage && i.subject == subject)
        .toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
    return list;
  }

  bool hasItemsFor(int stage, String subject) =>
      _items.any((i) => i.stage == stage && i.subject == subject);

  static Future<LibraryRepository> load() async {
    final raw = await rootBundle.loadString('assets/content/watoto_content_library.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final items = (json['content'] as List)
        .map((c) => LibraryItem.fromJson(c as Map<String, dynamic>))
        .toList();
    return LibraryRepository(items);
  }
}

final libraryProvider = FutureProvider<LibraryRepository>((_) => LibraryRepository.load());

/// Synchronous handle used once the library has loaded (kept simple for the
/// curriculum screen, which is only reachable well after startup).
final libraryItemProvider = Provider.family<LibraryItem?, String>((ref, id) {
  return ref.watch(libraryProvider).maybeWhen(
        data: (repo) => repo.byId[id],
        orElse: () => null,
      );
});
