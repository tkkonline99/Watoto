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
