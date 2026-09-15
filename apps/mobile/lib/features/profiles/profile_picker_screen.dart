import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';

/// "Who's learning?" — family-only profile switch (no PIN; switching between
/// a parent's own children is friction-free, parent zone is what's gated).
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final children = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.whoIsLearning,
            style: const TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.deep)),
        actions: [
          IconButton(
            tooltip: l10n.parentZone,
            icon: const Icon(Icons.lock_outline, color: WatotoColors.deep),
            onPressed: () => context.go('/parent'),
          ),
        ],
      ),
      body: SafeArea(
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            for (final child in children)
              _ProfileTile(
                emoji: child.emoji,
                label: child.nickname,
                semanticLabel: '${child.nickname}. ${l10n.whoIsLearning}',
                onTap: () async {
                  await ref.read(sessionProvider.notifier).selectChild(child.id);
                  if (context.mounted) context.go('/');
                },
              ),
            _ProfileTile(
              emoji: '➕',
              label: l10n.addChild,
              semanticLabel: l10n.addChild,
              onTap: () => context.go('/profiles/add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.emoji,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  /// Spoken instead of the tile's contents. Read verbatim, a tile announces
  /// the avatar emoji by its Unicode name ("lion face") before the child's
  /// name, which is noise; the label says what the button does.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The label goes inside the Card and the exclusion inside the InkWell.
    // Wrapped around the card, the exclusion took the tap action too, and a
    // screen reader could hear a child's name but never pick them; and a Card
    // is its own semantics container, so a label outside it lands on a
    // different node from the tap.
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
