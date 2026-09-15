import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/offline_providers.dart';
import '../../l10n/gen/app_localizations.dart';
import 'library_models.dart';

/// Whether the active child has completed [item] — the single source for the
/// ✅ marks on every list of playable items (subject page, curriculum browser,
/// story library). Watches xpProvider, which bumps on every completion, so
/// callers rebuild when the child returns from a lesson.
bool isItemDone(WidgetRef ref, LibraryItem item) {
  ref.watch(xpProvider);
  final childId = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (childId == null) return false;
  final store = ref.watch(offlineStoreProvider);
  return switch (item.type) {
    LibraryType.lesson => store.progressFor(childId, item.id) != null,
    LibraryType.quiz => store.lastQuizAttempt(childId, item.id) != null,
    LibraryType.story => store.hasReadStory(childId, item.id),
  };
}

/// The shared "completed" mark. An emoji rather than a conditional Icon:
/// icon-font tree-shaking can drop conditionally-referenced glyphs, and the
/// emoji matches the app's visual language anyway.
const String doneMark = '✅';

/// The item's kind in the family's language, for screen-reader labels. The
/// enum's own name ("lesson") is English whatever language the app is in.
String itemTypeLabel(AppLocalizations l10n, LibraryType type) =>
    switch (type) {
      LibraryType.lesson => l10n.itemTypeLesson,
      LibraryType.quiz => l10n.itemTypeQuiz,
      LibraryType.story => l10n.itemTypeStory,
    };
