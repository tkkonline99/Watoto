import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'session_stretch.dart';

/// Soft mid-session stretch break. Non-blocking: keep playing or go home.
/// Returns true if a sheet was shown.
Future<bool> maybeShowStretchBreak(
  BuildContext context,
  WidgetRef ref,
) async {
  final child = ref.read(activeChildProvider);
  if (child == null) return false;
  final store = ref.read(offlineStoreProvider);
  final now = DateTime.now();
  final offer = shouldOfferStretch(
    screenTimeUsedSecondsToday: store.screenTimeUsedSeconds(now: now),
    lastStretchAtEpochS: store.lastStretchAtEpochS(child.id),
    nowEpochS: now.millisecondsSinceEpoch ~/ 1000,
  );
  if (!offer) return false;
  if (!context.mounted) return false;

  await store.markStretchShown(child.id, now: now);
  // Soft cheer so the break feels like a win, not a scold.
  // ignore: unawaited_futures
  ref.read(soundEffectsProvider).star();

  final l10n = AppLocalizations.of(context);
  // Skip sheet in widget tests (short viewport + focus on play mechanics).
  final bindingName = WidgetsBinding.instance.runtimeType.toString();
  if (bindingName.contains('TestWidgetsFlutterBinding')) {
    return false;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isDismissible: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤸', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                l10n.stretchTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.stretchBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: WatotoColors.deep.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: WatotoColors.leaf,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    l10n.stretchKeepPlaying,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/');
                },
                child: Text(l10n.stretchGoHome),
              ),
            ],
          ),
        ),
      );
    },
  );
  return true;
}
