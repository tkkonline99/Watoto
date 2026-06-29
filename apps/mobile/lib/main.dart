import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/offline/desktop_migration_stub.dart'
    if (dart.library.io) 'core/offline/desktop_migration_io.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/offline_store.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  await _initHive();
  final store = await OfflineStore.open();

  final container = ProviderContainer(
    overrides: [offlineStoreProvider.overrideWithValue(store)],
  );
  // Start an anonymous session so a child can play immediately (auth.ts design);
  // upgraded in place when a parent signs up. Local until Firebase is wired.
  unawaited(container.read(authServiceProvider).ensureAnonymousSession());
  // Best-effort: push progress recorded while offline. Never blocks startup.
  unawaited(container.read(syncEngineProvider).flush());

  runApp(UncontrolledProviderScope(container: container, child: const WatotoApp()));
}

/// Attributes the bundled OFL fonts (Baloo 2, Nunito) so they show up in the
/// app's Licenses page (showLicensePage / AboutDialog). Loaded lazily.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Baloo 2'],
      await rootBundle.loadString('assets/licenses/OFL-Baloo2.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Nunito'],
      await rootBundle.loadString('assets/licenses/OFL-Nunito.txt'),
    );
  });
}

/// Initializes Hive in a writable location for the platform. On desktop the
/// user's Documents folder is commonly redirected to OneDrive and locked by
/// Controlled Folder Access, so `initFlutter` (which targets Documents) can't
/// create the database there; store under the app-support dir instead
/// (%APPDATA% on Windows, ~/.local/share on Linux, Application Support on
/// macOS). Mobile and web keep the Flutter default.
Future<void> _initHive() async {
  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (isDesktop) {
    final dir = await getApplicationSupportDirectory();
    // Recover data orphaned by a past app-support path change (see the shim).
    await migrateLegacyDesktopData(dir.path);
    Hive.init(dir.path);
  } else {
    await Hive.initFlutter('watoto');
  }
}
