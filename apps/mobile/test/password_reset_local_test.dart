/// The local password reset tells the truth, and stops handing out the answer.
///
/// Two defects, both only visible in a shipped build. No `firebase_*` package
/// is in pubspec, so `authServiceProvider` is always `LocalAuthService`; there
/// is no mail server, and no `url_launcher` to open the `mailto:` URI the
/// service builds. Nothing was ever sent. Yet the screen said "Check your
/// email for the reset code", and the code went to the clipboard with nothing
/// on screen saying so — a parent who had genuinely forgotten their password
/// waited for mail that could not arrive.
///
/// And the screen pre-filled the account email. `/password-reset` sits outside
/// the login gate by design (a grown-up who forgot the password cannot be
/// asked for it), so its only barrier was the spelled-digit parent gate — an
/// FTC gate built to stop a *young* child, on an app that goes to age ten.
/// Pre-filling the email removed the one secret a child was unlikely to have.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/auth/auth_service.dart';
import 'package:watoto_mobile/features/auth/parent_gate.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

const _email = 'parent@example.com';
const _gate = ParentGateChallenge(prompt: 'four — two — nine', answer: '429');

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
  });

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
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
      birthYear: 2020,
    );
    await store.createAccount(_email, 'originalpass');
  });

  tearDown(() async {
    await store.close();
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          parentGateChallengeProvider.overrideWithValue(_gate),
        ],
        child: const WatotoApp(),
      );

  Future<void> openReset(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(appRouterProvider)
        .go('/password-reset');
    await tester.pumpAndSettle();
  }

  /// The email field is the first text field on the screen.
  Finder emailField() => find.byType(TextField).first;

  /// Answers the spelled-digit gate. Its confirm button is labelled "Next".
  Future<void> passGate(WidgetTester tester) async {
    final gateField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(gateField, _gate.answer);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Next'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the account email is not pre-filled', (tester) async {
    await openReset(tester);
    final field = tester.widget<TextField>(emailField());
    expect(
      field.controller?.text ?? '',
      isEmpty,
      reason: 'pre-filling hands the one secret a child lacks straight to '
          'whoever picked up the phone',
    );
  });

  testWidgets('it never claims an email was sent', (tester) async {
    await openReset(tester);
    await tester.enterText(emailField(), _email);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show my reset code'));
    await tester.pumpAndSettle();

    await passGate(tester);

    expect(
      find.text('Check your email for the reset code.'),
      findsNothing,
      reason: 'no build that ships can send mail, so saying so strands the '
          'parent waiting for it',
    );
  });

  testWidgets('the code is shown on screen, not just slipped to the clipboard',
      (tester) async {
    await openReset(tester);
    await tester.enterText(emailField(), _email);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show my reset code'));
    await tester.pumpAndSettle();
    await passGate(tester);

    expect(
      find.textContaining('Your reset code is'),
      findsOneWidget,
      reason: 'the clipboard was the undocumented delivery channel',
    );
    // And it says why a code on screen is not a mistake.
    expect(find.textContaining('Copied to the clipboard.'), findsOneWidget);
  });

  testWidgets('a wrong email yields no code', (tester) async {
    await openReset(tester);
    await tester.enterText(emailField(), 'guess@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show my reset code'));
    await tester.pumpAndSettle();
    await passGate(tester);

    expect(
      find.textContaining('Your reset code is'),
      findsNothing,
      reason: 'knowing the account email is the barrier that does the work',
    );
    // And the real password still works.
    expect(store.verifyAccount('originalpass'), isTrue);
  });

  testWidgets('a family with a PIN is pointed at the way in they already have',
      (tester) async {
    await openReset(tester);
    expect(
      find.textContaining('Know your parent PIN?'),
      findsOneWidget,
      reason: 'a PIN is a login on its own; resetting the password to get in '
          'is a detour they do not need',
    );
  });
}
