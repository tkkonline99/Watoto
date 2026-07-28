import 'package:flutter/material.dart' hide Badge;

import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'achievements_sheet.dart';
import 'rewards.dart';

/// Shows a kid-friendly "new badge!" snackbar. Safe if [scaffold] is null.
void showBadgeUnlockToast(
  BuildContext context, {
  required List<Badge> newlyEarned,
}) {
  if (newlyEarned.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  final b = newlyEarned.first;
  final label = badgeLabel(l10n, b.id);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: WatotoColors.deep,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Text(b.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.badgeUnlocked,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (newlyEarned.length > 1)
            Text(
              '+${newlyEarned.length - 1}',
              style: const TextStyle(
                color: WatotoColors.sun,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    ),
  );
}

/// Level-up banner.
void showLevelUpToast(BuildContext context, {required int level}) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: WatotoColors.mango,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.levelUp(level),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: WatotoColors.deep,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
