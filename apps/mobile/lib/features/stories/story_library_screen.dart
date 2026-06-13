import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'story_repository.dart';

class StoryLibraryScreen extends ConsumerWidget {
  const StoryLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final stories = ref.watch(storyCatalogProvider);
    final child = ref.watch(activeChildProvider);
    final store = ref.watch(offlineStoreProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
        title: Text(l10n.storybooks,
            style: const TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.deep)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final story in stories)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Text(story.emoji, style: const TextStyle(fontSize: 44)),
                  title: Text(story.localizedTitle(lang),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  trailing: child != null && store.hasReadStory(child.id, story.id)
                      ? const Icon(Icons.check_circle, color: WatotoColors.leaf)
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.go('/story/${story.slug}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
