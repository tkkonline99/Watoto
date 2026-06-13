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
                onTap: () async {
                  await ref.read(sessionProvider.notifier).selectChild(child.id);
                  if (context.mounted) context.go('/');
                },
              ),
            _ProfileTile(
              emoji: '➕',
              label: l10n.addChild,
              onTap: () => context.go('/profiles/add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
