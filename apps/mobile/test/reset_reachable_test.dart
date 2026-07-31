library;

/// Recovery has to be reachable by the person who is locked out.
///
/// Both reset screens existed and worked, but nothing routed to them and
/// nothing linked to them, so a grown-up who forgot the PIN had no way back
/// in. These tests pin the reachability, not the reset logic.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

class _Offline implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
    // These tests are about the *PIN* gate; start past the login gate so the
    // redirect under test is the one being asserted. app_flow_test covers
    // recovery being reachable from /login itself.
    debugSkipLoginGate = true;
  });

  setUp(() async => store = await OfflineStore.open(inMemory: true));
  tearDown(() async => await store.close());

  Widget buildApp() => ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_Offline()),
        ],
        child: const WatotoApp(),
      );

  void goTo(WidgetTester tester, String location) =>
      ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
          .read(appRouterProvider)
          .go(location);

  String location(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> seedPinFamily() => store.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: 2019,
      );

  testWidgets('the PIN gate offers a way out to someone who forgot it',
      (tester) async {
    await seedPinFamily();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    goTo(tester, '/parent');
    await tester.pumpAndSettle();
    // Gated, as expected.
    expect(location(tester), startsWith('/parent/unlock'));

    final forgot = find.text('Forgot your PIN?');
    expect(forgot, findsOneWidget);
    await tester.ensureVisible(forgot);
    await tester.pump();
    await tester.tap(forgot);
    await tester.pumpAndSettle();

    // Assert on what the grown-up actually sees. (The reset screen is pushed
    // over the gate, so the stack's URI is not the useful probe here — the
    // question is whether the recovery form is on screen.)
    expect(find.text('Set new PIN'), findsOneWidget);
  });

  testWidgets('a locked-out grown-up is not redirected away from recovery',
      (tester) async {
    // The trap this guards: /pin-reset must not sit under /parent, or the
    // redirect would bounce a PIN-less family straight back to the gate they
    // are trying to reset.
    await seedPinFamily();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    goTo(tester, '/pin-reset');
    await tester.pumpAndSettle();
    expect(location(tester), '/pin-reset');

    goTo(tester, '/password-reset');
    await tester.pumpAndSettle();
    expect(location(tester), '/password-reset');
  });

  testWidgets('recovery stays reachable while the PIN is locked out',
      (tester) async {
    await seedPinFamily();
    // Burn through the attempt allowance.
    for (var i = 0; i < OfflineStore.pinMaxAttempts; i++) {
      await store.tryPin('0000');
    }
    expect(store.isPinLocked, isTrue);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/parent');
    await tester.pumpAndSettle();

    // Unlock is disabled during lockout, but the way out must not be.
    final forgot = find.text('Forgot your PIN?');
    expect(forgot, findsOneWidget);
    await tester.ensureVisible(forgot);
    await tester.pump();
    await tester.tap(forgot);
    await tester.pumpAndSettle();
    expect(find.text('Set new PIN'), findsOneWidget);
  });
}
