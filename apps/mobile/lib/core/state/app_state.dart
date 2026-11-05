import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/offline_providers.dart';

/// Active UI/content locale; one-click switching from the home screen and
/// onboarding. Seeded from the offline store and written back on every change,
/// so the family's language choice survives a restart. Before any choice is
/// made the app follows the device language when we support it, else English.
///
/// The active child profile lives in `offline_providers.dart`
/// (`activeChildProvider`), seeded from the persisted store.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final store = ref.watch(offlineStoreProvider);
    final saved = store.localeCode;
    if (saved != null) return Locale(saved);

    const supported = {'en', 'fr', 'sw'};
    final device = PlatformDispatcher.instance.locale.languageCode;
    return Locale(supported.contains(device) ? device : 'en');
  }

  /// Switches language and persists the choice for the next launch.
  void set(Locale locale) {
    ref.read(offlineStoreProvider).setLocaleCode(locale.languageCode);
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// App-wide text-size multiplier (1.0 / 1.3 / 1.6), layered on top of the OS
/// text scale in [WatotoApp] so grown-ups can enlarge every screen for young
/// or low-vision readers. Persisted so the choice survives a restart.
class TextScaleController extends Notifier<double> {
  @override
  double build() => ref.watch(offlineStoreProvider).textScale;

  void set(double scale) {
    ref.read(offlineStoreProvider).setTextScale(scale);
    state = scale;
  }
}

final textScaleProvider = NotifierProvider<TextScaleController, double>(
  TextScaleController.new,
);

class DyslexiaFriendlyController extends Notifier<bool> {
  @override
  bool build() => ref.watch(offlineStoreProvider).dyslexiaFriendly;

  Future<void> set(bool value) async {
    await ref.read(offlineStoreProvider).setDyslexiaFriendly(value);
    state = value;
  }
}

final dyslexiaFriendlyProvider =
    NotifierProvider<DyslexiaFriendlyController, bool>(
  DyslexiaFriendlyController.new,
);

class HighContrastController extends Notifier<bool> {
  @override
  bool build() => ref.watch(offlineStoreProvider).highContrast;

  Future<void> set(bool value) async {
    await ref.read(offlineStoreProvider).setHighContrast(value);
    state = value;
  }
}

final highContrastProvider = NotifierProvider<HighContrastController, bool>(
  HighContrastController.new,
);

class ReducedMotionController extends Notifier<bool> {
  @override
  bool build() => ref.watch(offlineStoreProvider).reducedMotion;

  Future<void> set(bool value) async {
    await ref.read(offlineStoreProvider).setReducedMotion(value);
    state = value;
  }
}

final reducedMotionProvider = NotifierProvider<ReducedMotionController, bool>(
  ReducedMotionController.new,
);

class AnalyticsOptInController extends Notifier<bool> {
  @override
  bool build() => ref.watch(offlineStoreProvider).analyticsOptIn;

  Future<void> set(bool value) async {
    await ref.read(offlineStoreProvider).setAnalyticsOptIn(value);
    state = value;
  }
}

final analyticsOptInProvider =
    NotifierProvider<AnalyticsOptInController, bool>(
  AnalyticsOptInController.new,
);

/// Cozy sunset / starry bedtime mode ("Usiku Mwema") for calm evening reading.
class BedtimeModeController extends Notifier<bool> {
  @override
  bool build() => ref.watch(offlineStoreProvider).bedtimeMode;

  Future<void> set(bool value) async {
    await ref.read(offlineStoreProvider).setBedtimeMode(value);
    state = value;
  }

  Future<void> toggle() => set(!state);
}

final bedtimeModeProvider = NotifierProvider<BedtimeModeController, bool>(
  BedtimeModeController.new,
);
