import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../profiles/child_profile.dart';
import 'economy.dart';
import 'rewards.dart';
import 'savanna_world.dart';

/// Child-facing coin shop for cosmetic avatar unlocks only.
class AvatarShopScreen extends ConsumerWidget {
  const AvatarShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final child = ref.watch(activeChildProvider);
    final coins = ref.watch(coinsProvider);
    final store = ref.watch(offlineStoreProvider);
    final childId = child?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.avatarShop),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '🪙 $coins',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: WatotoColors.deep,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.avatarShopBody,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Text(l10n.freeAvatars, style: _section),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final e in baseAvatarChoices.entries)
                  _AvatarTile(
                    emoji: e.value,
                    label: e.key,
                    selected: child?.avatarKey == e.key,
                    locked: false,
                    onTap: childId == null
                        ? null
                        : () => _equip(ref, childId, e.key),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l10n.shopDecorations, style: _section),
            const SizedBox(height: 4),
            Text(
              l10n.shopDecorationsBody,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const _DecorationGrid(),
            const SizedBox(height: 24),
            Text(l10n.shopAvatars, style: _section),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in shopAvatars)
                  Builder(
                    builder: (context) {
                      final unlocked = childId != null &&
                          (store.isAvatarUnlocked(childId, s.key) ||
                              baseAvatarChoices.containsKey(s.key));
                      return _AvatarTile(
                        emoji: s.emoji,
                        label: unlocked ? s.key : '${s.cost} 🪙',
                        selected: child?.avatarKey == s.key,
                        locked: !unlocked,
                        onTap: childId == null
                            ? null
                            : () async {
                                if (unlocked) {
                                  await _equip(ref, childId, s.key);
                                  return;
                                }
                                final ok = await store.spendCoins(
                                  childId,
                                  s.cost,
                                );
                                if (!ok) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l10n.notEnoughCoins)),
                                    );
                                  }
                                  return;
                                }
                                await store.unlockAvatar(childId, s.key);
                                await _equip(ref, childId, s.key);
                                ref.read(economyTickProvider.notifier).state++;
                              },
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _equip(WidgetRef ref, String childId, String key) async {
    final store = ref.read(offlineStoreProvider);
    final children = store.children;
    final idx = children.indexWhere((c) => c.id == childId);
    if (idx < 0) return;
    final c = children[idx];
    final updated = ChildProfile(
      id: c.id,
      nickname: c.nickname,
      avatarKey: key,
      birthYear: c.birthYear,
      ageBand: c.ageBand,
    );
    // Persist by rewriting profiles list.
    await store.updateChild(updated);
    ref.read(sessionProvider.notifier).touchProfiles();
  }

  static const _section = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: WatotoColors.deep,
  );
}

/// Savanna decorations — the deep end of the coin economy.
///
/// Earned decorations appear here too, unlocked and unpriced, so the child can
/// see that the world grows by playing as well as by spending.
class _DecorationGrid extends ConsumerWidget {
  const _DecorationGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final child = ref.watch(activeChildProvider);
    final childId = child?.id;
    final store = ref.watch(offlineStoreProvider);
    ref.watch(economyTickProvider);
    final xp = ref.watch(xpProvider);

    if (childId == null) return const SizedBox.shrink();

    final level = levelForXp(xp);
    final explored = store.completedSubjects(childId).length;
    final purchased = store.unlockedDecorations(childId);

    Future<void> buy(SavannaDecoration d) async {
      final ok = await store.spendCoins(childId, d.cost);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.notEnoughCoins)),
          );
        }
        return;
      }
      await store.unlockDecoration(childId, d.key);
      ref.read(economyTickProvider.notifier).state++;
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final d in earnedDecorations)
          Builder(
            builder: (context) {
              final unlocked =
                  isEarned(d, level: level, subjectsExplored: explored);
              return _AvatarTile(
                emoji: d.emoji,
                label: unlocked
                    ? l10n.decorationEarned
                    : (d.requiredLevel > 0
                        ? l10n.decorationNeedsLevel(d.requiredLevel)
                        : l10n.decorationNeedsSubjects(d.requiredSubjects)),
                selected: false,
                locked: !unlocked,
                onTap: null,
              );
            },
          ),
        for (final d in shopDecorations)
          Builder(
            builder: (context) {
              final owned = purchased.contains(d.key);
              return _AvatarTile(
                emoji: d.emoji,
                label: owned ? l10n.decorationOwned : '${d.cost} 🪙',
                selected: false,
                locked: !owned,
                onTap: owned ? null : () => buy(d),
              );
            },
          ),
      ],
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? WatotoColors.sun.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? WatotoColors.mango : Colors.black12,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: locked ? 0.45 : 1,
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 4),
            Text(
              locked ? '🔒 $label' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
