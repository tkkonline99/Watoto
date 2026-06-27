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

final localeProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);
