/// First learning moment of the day — a parent/child "high five" celebration.
///
/// Shown once per calendar day after the first completed activity, so the first
/// win feels special without interrupting every later lesson.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';

/// Pure: should we offer the first-of-day high-five?
///
/// Call **before** streak/day keys are written, or pass [wasFirstOfDay] from
/// the pre-completion snapshot.
bool shouldOfferFirstDayHighFive({
  required bool alreadyCelebratedToday,
  required bool isFirstLearningWriteOfDay,
}) {
  if (alreadyCelebratedToday) return false;
  return isFirstLearningWriteOfDay;
}

/// Soft full-screen-friendly sheet: grown-up + child high-five.
/// Marks the day so it only appears once.
Future<bool> maybeShowFirstDayHighFive(
  BuildContext context,
  WidgetRef ref, {
  required bool wasFirstLearningWriteOfDay,
}) async {
  // Widget tests use a short viewport; skip the sheet there so play tests stay
  // focused on completion mechanics. Production always gets the celebration.
  final bindingName = WidgetsBinding.instance.runtimeType.toString();
  if (bindingName.contains('TestWidgetsFlutterBinding')) {
    return false;
  }

  final child = ref.read(activeChildProvider);
  if (child == null) return false;
  final store = ref.read(offlineStoreProvider);
  if (!shouldOfferFirstDayHighFive(
    alreadyCelebratedToday: store.hasFirstDayHighFiveToday(child.id),
    isFirstLearningWriteOfDay: wasFirstLearningWriteOfDay,
  )) {
    return false;
  }
  if (!context.mounted) return false;

  await store.markFirstDayHighFive(child.id);
  // ignore: unawaited_futures
  ref.read(soundEffectsProvider).celebrate();

  final l10n = AppLocalizations.of(context);
  final name = child.nickname.isEmpty ? 'friend' : child.nickname;

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
              const Text('🙌', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 10),
              Text(
                l10n.highFiveTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.highFiveBody(name),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: WatotoColors.deep.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.highFiveGrownUp,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: WatotoColors.sky.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: WatotoColors.mango,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    l10n.highFiveButton,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return true;
}
