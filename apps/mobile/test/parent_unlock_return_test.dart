library;

/// A grown-up who unlocks something must land back on *that thing*, not on the
/// Parent Zone dashboard. Every gate (PIN, account, paywall) carries the
/// intended destination through and hands control back to it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/auth/entitlements.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';
import 'package:watoto_mobile/router/return_to.dart';

class _Unreachable implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// Stage 7 — past the free tier, so opening it is parent-gated.
const _premiumLesson = LibraryItem(
  id: 'test.premium.1',
  stage: 7,
  ages: '6-7',
  subject: 'Reading',
  type: LibraryType.lesson,
  title: 'Locked Lesson',
  objective: '',
  designTier: 'guided',
  reading: true,
  interaction: 'tap',
  steps: [
    LessonStep(
      narration: 'Tap the cat.',
      action: 'tap',
      feedback: 'Yes!',
    ),
  ],
);

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
    // Start past the login gate: what's under test here is the PIN gate
    // handing the family back to where they were headed.
    debugSkipLoginGate = true;
  });

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_Unreachable()),
          libraryProvider.overrideWith(
            (ref) async => LibraryRepository([_premiumLesson]),
          ),
          // The shipping default is a free-only launch (PUBLISH_FREE_ONLY),
          // which unlocks all ten stages and takes the paywall out of the
          // path entirely. This suite is *about* the paywall handoff, so put
          // the free ceiling back at stage 5.
          freeStageMaxProvider.overrideWithValue(freeStageMax),
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

  Future<void> seed() async {
    await store.completeOnboarding(
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
  }

  group('return_to', () {
    test('carries an in-app destination', () {
      expect(
        gateWithReturn('/parent/unlock', '/play/abc'),
        '/parent/unlock?from=%2Fplay%2Fabc',
      );
    });

    test('survives nesting: PIN gate -> paywall -> the lesson', () {
      // The real chain: a locked lesson sends the grown-up to the paywall, and
      // the router wraps that in the PIN gate. Both hops must decode back out.
      final toPaywall = gateWithReturn('/paywall', '/play/s07.reading.lesson.03');
      final toPin = gateWithReturn('/parent/unlock', toPaywall);

      final afterPin = Uri.parse(toPin).queryParameters[returnToParam];
      expect(afterPin, toPaywall);
      final afterPaywall = Uri.parse(afterPin!).queryParameters[returnToParam];
      expect(afterPaywall, '/play/s07.reading.lesson.03');
    });

    test('refuses external and gate destinations', () {
      // No open redirects, and no bouncing back into the gate just passed.
      expect(gateWithReturn('/parent/unlock', 'https://evil.example'),
          '/parent/unlock');
      expect(gateWithReturn('/parent/unlock', '//evil.example'), '/parent/unlock');
      expect(gateWithReturn('/parent/unlock', '/parent/unlock'), '/parent/unlock');
      expect(gateWithReturn('/parent/unlock', '/login'), '/parent/unlock');
    });

    test('carries /account, which is a destination and no longer a gate', () {
      expect(gateWithReturn('/parent/unlock', '/account'),
          '/parent/unlock?from=%2Faccount');
    });
  });

  testWidgets('the PIN gate carries the family to the paywall, not the '
      'dashboard', (tester) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // A child opens a premium lesson and hands the device over.
    goTo(tester, '/play/${_premiumLesson.id}');
    await tester.pumpAndSettle();
    expect(find.text('Parent Zone'), findsOneWidget);
    await tester.tap(find.text('Parent Zone'));
    await tester.pumpAndSettle();

    // Gated: the PIN screen, remembering the lesson behind the paywall.
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(location(tester), contains('from='));

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    // The unlock surface — NOT the "This week / Insights / Children" dashboard.
    expect(location(tester), startsWith('/paywall'));
    expect(find.text('Children'), findsNothing);
  });

  testWidgets('unlocking premium returns to the locked lesson', (tester) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Come in already past the PIN, straight at the paywall, with the lesson
    // recorded as the destination.
    goTo(tester, '/parent/unlock?from=%2Fpaywall');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    goTo(
      tester,
      gateWithReturn('/paywall', '/play/${_premiumLesson.id}'),
    );
    await tester.pumpAndSettle();

    // Granting premium and leaving the paywall lands on the lesson itself.
    await store.setLocalPremium(true);
    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(sessionProvider.notifier)
        .touchSession();
    await tester.pumpAndSettle();

    goTo(tester, '/play/${_premiumLesson.id}');
    await tester.pumpAndSettle();
    expect(find.text('Tap the cat.'), findsOneWidget);
    expect(find.text('Parent Zone'), findsNothing);
  });

  testWidgets('a grown-up who asked for the dashboard still gets the dashboard',
      (tester) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    goTo(tester, '/parent');
    await tester.pumpAndSettle();
    expect(find.text('Grown-ups only'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(location(tester), '/parent');
    expect(find.text('Children'), findsOneWidget);
  });
}
