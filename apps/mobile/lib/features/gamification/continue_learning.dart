/// Pure "continue learning" resolver (unit-tested).
library;

import '../../core/offline/offline_store.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';

/// Next incomplete activity for the child, preferring the last subject they
/// played, then any incomplete item at their preferred stage.
class ContinueTarget {
  const ContinueTarget({
    required this.item,
    required this.reason,
  });

  final LibraryItem item;
  final String reason; // 'resume' | 'next' | 'discover'

  String get itemId => item.id;
  String get title => item.title;
}

ContinueTarget? resolveContinueLearning({
  required String childId,
  required OfflineStore store,
  required LibraryRepository library,
}) {
  final last = store.lastPlayed(childId);
  if (last != null) {
    final stage = last['stage'] as int?;
    final subject = last['subject'] as String?;
    final lastId = last['itemId'] as String?;
    if (stage != null && subject != null) {
      final list = library.forStageSubject(stage, subject);
      // Prefer first incomplete after the last played item.
      var seenLast = lastId == null;
      for (final item in list) {
        if (!seenLast) {
          if (item.id == lastId) seenLast = true;
          continue;
        }
        if (!store.hasCompletedLibraryItem(childId, item.id, item.type.name)) {
          return ContinueTarget(item: item, reason: 'next');
        }
      }
      // Or any incomplete in that subject (including before last).
      for (final item in list) {
        if (!store.hasCompletedLibraryItem(childId, item.id, item.type.name)) {
          return ContinueTarget(item: item, reason: 'resume');
        }
      }
    }
  }

  // Discover: first incomplete at preferred / any stage content.
  final preferred = store.preferredStage(childId);
  final candidates = preferred == null
      ? library.all
      : library.all.where((i) => i.stage == preferred).toList();
  for (final item in candidates) {
    if (!store.hasCompletedLibraryItem(childId, item.id, item.type.name)) {
      return ContinueTarget(item: item, reason: 'discover');
    }
  }
  return null;
}
