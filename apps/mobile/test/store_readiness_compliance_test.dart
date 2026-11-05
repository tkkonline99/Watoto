import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/config/publish_config.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/domain/models/consent.dart';
import 'package:watoto_mobile/features/auth/account_screen.dart';
import 'package:watoto_mobile/features/auth/auth_service.dart';
import 'package:watoto_mobile/features/auth/parent_gate.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
  });

  group('1. Google Play Families & Android Manifest Hardening', () {
    test('AndroidManifest strips AD_ID, disables auto-backup, and blocks cleartext HTTP', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      // Google Play Families Policy: must explicitly strip Advertising ID.
      expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
      expect(manifest, contains('tools:node="remove"'));

      // OWASP MASVS / COPPA: prevent automatic cloud backup of PBKDF2 hashes & child profiles.
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));

      // Enforce HTTPS-only transport at OS level.
      expect(manifest, contains('android:usesCleartextTraffic="false"'));

      // Must never request high-risk permissions that trigger Kids Category rejection.
      for (final forbidden in [
        'android.permission.RECORD_AUDIO',
        'android.permission.CAMERA',
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.READ_CONTACTS',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.USE_EXACT_ALARM',
      ]) {
        expect(manifest, isNot(contains(forbidden)));
      }
    });
  });

  group('2. Apple App Store Kids Category, ATS & Privacy Manifest', () {
    test('Info.plist declares trilingual locales, export compliance, and strict ATS', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, contains('<key>CFBundleLocalizations</key>'));
      expect(plist, contains('<string>en</string>'));
      expect(plist, contains('<string>fr</string>'));
      expect(plist, contains('<string>sw</string>'));

      expect(plist, contains('<key>ITSAppUsesNonExemptEncryption</key>'));
      expect(plist, contains('<key>NSAppTransportSecurity</key>'));
      expect(plist, contains('<key>NSAllowsArbitraryLoads</key>'));
    });

    test('PrivacyInfo.xcprivacy disables tracking and declares required reason APIs', () {
      final privacyManifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();

      expect(privacyManifest, contains('<key>NSPrivacyTracking</key>'));
      expect(privacyManifest, contains('<false/>'));
      expect(privacyManifest, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
      expect(privacyManifest, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
    });

    test('Native iOS StoreKit 2 and Android MainActivity register app.watoto.iap MethodChannel', () {
      final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      final kotlin = File(
        'android/app/src/main/kotlin/app/watoto/watoto_mobile/MainActivity.kt',
      ).readAsStringSync();

      expect(swift, contains('"app.watoto.iap"'));
      expect(swift, contains('Product.products'));
      expect(swift, contains('Transaction.currentEntitlements'));
      expect(kotlin, contains('"app.watoto.iap"'));
    });
  });

  group('3. Production Store URLs & Non-Draft Legal Copy', () {
    test('publish_config exposes HTTPS legal and support URLs', () {
      expect(privacyPolicyUrl, startsWith('https://'));
      expect(termsOfServiceUrl, startsWith('https://'));
      expect(supportUrl, startsWith('https://'));
    });

    testWidgets('trilingual legal subtitle never displays Draft placeholder copy', (
      tester,
    ) async {
      for (final locale in const [Locale('en'), Locale('sw'), Locale('fr')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        final note = l10n.legalDraftNote.toLowerCase();
        expect(note, isNot(contains('draft')));
        expect(note, isNot(contains('rasimu')));
        expect(note, isNot(contains('brouillon')));
        expect(note, contains('coppa'));
      }
    });
  });

  group('4. Parental Gate on Destructive Account Deletion', () {
    testWidgets('AccountScreen requires passing FTC parent gate before deleting account', (
      tester,
    ) async {
      final store = await OfflineStore.open(inMemory: true);
      addTearDown(store.close);

      await store.completeOnboarding(
        consent: ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: DateTime.utc(2026, 7, 18),
        ),
        pin: '1234',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: 2020,
      );
      expect(store.children, hasLength(1));

      const fixedChallenge = ParentGateChallenge(
        prompt: 'two — four — one',
        answer: '241',
      );

      final router = GoRouter(
        initialLocation: '/account',
        routes: [
          GoRoute(
            path: '/account',
            builder: (_, _) => const Scaffold(body: AccountScreen()),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const Scaffold(body: Text('Onboarding Reset')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            offlineStoreProvider.overrideWithValue(store),
            parentGateChallengeProvider.overrideWith((ref) => fixedChallenge),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to Delete account button and tap it.
      final deleteBtn = find.text('Delete account');
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // 1. Parent gate dialog must appear first; cancelling keeps the account intact.
      expect(find.text('Grown-ups only'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.children, hasLength(1));

      // 2. Tap Delete account again, pass the parent gate, then confirm deletion.
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '241');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Now the destructive confirmation dialog is shown.
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(store.children, isEmpty);
      expect(store.onboardingComplete, isFalse);
    });
  });
}
