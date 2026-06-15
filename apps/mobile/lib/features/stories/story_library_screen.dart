import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../library/content_i18n.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';

/// Storybook library — lists the story items from the content library
/// (content/watoto_content_library.json). Tapping one opens the story player.
class StoryLibraryScreen extends ConsumerWidget {
  const StoryLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final libAsync = ref.watch(libraryProvider);

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
        child: libAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (repo) {
            final lang = ref.watch(localeProvider).languageCode;
            final i18n = ref.watch(contentI18nProvider).asData?.value;
            final stories =
                repo.all.where((i) => i.type == LibraryType.story).toList()
                  ..sort((a, b) => a.stage.compareTo(b.stage));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final story in stories)
                  _StoryTile(story: story, title: itemTitle(i18n, lang, story)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story, required this.title});

  final LibraryItem story;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Text('📖', style: TextStyle(fontSize: 36)),
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        subtitle: Text('${story.subject} · ${story.ages}'),
        trailing: const Icon(Icons.play_circle_fill, color: WatotoColors.mango),
        onTap: () => context.push('/play/${story.id}'),
      ),
    );
  }
}
