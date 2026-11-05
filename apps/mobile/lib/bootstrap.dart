import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'core/offline/desktop_migration_stub.dart'
    if (dart.library.io) 'core/offline/desktop_migration_io.dart';
import 'core/analytics/analytics.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/sync_lifecycle.dart';
import 'core/crash/crash_reporting.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/firebase_auth_service.dart';
import 'features/onboarding/consent.dart';
import 'firebase/firebase_bootstrap.dart';
// LocalAuthService is exported via auth_service.dart

/// Shared startup for mobile, web, **and desktop** (Windows/macOS/Linux).
///
/// Keeps [main] and [main_demo] in lockstep so a Windows install never lags
/// behind phone/web on auth, offline store, or sync lifecycle.
Future<ProviderContainer> bootstrapWatoto({
  bool seedDemoFamily = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  installCrashHooks();
  _registerFontLicenses();
  await initializeWatotoFirebase();
  await initWatotoHive();
  final store = await OfflineStore.open();
  await store.ensureDeviceId();
  // Upgrade from the boot-time debug/no-op backend now that a durable sink
  // exists. Release builds recorded nothing before this line.
  crashReportingBackend = StoreCrashBackend(store.appendCrashEvent);
  crashReportingBackend.setCustomKey('deviceId', store.deviceId);

  if (seedDemoFamily && !store.onboardingComplete) {
    await store.completeOnboarding(
      consent: ConsentRecord(
        coreData: true,
        aiFeatures: true,
        voiceRecording: false,
        recordedAt: DateTime.now().toUtc(),
      ),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    await store.recordLessonCompleted(
      childId: store.activeChildId!,
      lessonId: 'demo-seed',
      scorePct: 100,
      timeSpentS: 60,
      xpEarned: 20,
    );
  }

  final auth = createAuthService();
  if (auth is LocalAuthService) {
    auth.bindStore(store);
  }

  final container = ProviderContainer(
    overrides: [
      offlineStoreProvider.overrideWithValue(store),
      authServiceProvider.overrideWithValue(auth),
    ],
  );

  // Anonymous session is best-effort — local always works; Firebase throws
  // only when USE_FIREBASE is on without packages (ignored here so boot works).
  unawaited(() async {
    try {
      await container.read(authServiceProvider).ensureAnonymousSession();
    } on Object {
      // Stay offline; parent can still use LocalAuth after flipping the flag off.
    }
  }());
  unawaited(container.read(syncEngineProvider).flush());
  container.read(syncLifecycleProvider).attach();

  // Session denominator: every funnel rate above is meaningless without it.
  container.read(analyticsProvider).log(AnalyticsEvents.appOpen, {
    'locale': store.localeCode ?? 'unset',
    'onboarded': store.onboardingComplete,
    'children': store.children.length,
  });

  return container;
}

/// Attributes the bundled OFL fonts (Baloo 2, Nunito) for the Licenses page.
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

/// Hive init with desktop OneDrive/Controlled-Folder-Access safe path.
///
/// Mobile/web: Flutter default. Desktop: application-support dir + legacy
/// migration so Windows rebuilds keep the family's progress.
Future<void> initWatotoHive() async {
  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (isDesktop) {
    final dir = await getApplicationSupportDirectory();
    await migrateLegacyDesktopData(dir.path);
    Hive.init(dir.path);
  } else {
    await Hive.initFlutter('watoto');
  }
}

/// True on Windows / macOS / Linux desktop shells (not web, not mobile).
bool get isDesktopShell =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);
