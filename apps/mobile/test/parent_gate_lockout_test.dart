library;

/// The two grown-up gates have to hold against a child and open for the
/// grown-up actually holding the device.
///
/// Three ways they failed, each pinned below:
/// - the adult check picked its number once per run, so a child who had
///   watched a grown-up answer it could replay the same three digits;
/// - that number was spelled in English for every family, so a parent reading
///   Swahili or French was asked to decode a language they may not read;
/// - the Parent Zone gate never noticed a PIN lockout ending, and left the
///   grown-up facing a disabled field — with no message at all if the lockout
///   began somewhere else, such as the login screen.
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
import 'package:watoto_mobile/features/auth/auth_service.dart';
import 'package:watoto_mobile/features/auth/parent_gate.dart';
import 'package:watoto_mobile/features/auth/parent_gate_dialog.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';
import 'package:watoto_mobile/router/app_router.dart';

class _Offline implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

void main() {
  group('adult check wording', () {
    const challenge =
        ParentGateChallenge(prompt: 'four — two — nine', answer: '429');

    test('spells the digits in the family language', () {
      expect(challenge.promptIn('sw'), 'nne — mbili — tisa');
      expect(challenge.promptIn('fr'), 'quatre — deux — neuf');
      expect(challenge.promptIn('en'), 'four — two — nine');
    });

    test('a regional locale name still finds its words', () {
      expect(challenge.promptIn('fr_CA'), 'quatre — deux — neuf');
    });

    test('a language with no words here falls back to the English prompt', () {
      expect(challenge.promptIn('xx'), challenge.prompt);
    });

    test('every generated challenge reads back as its own answer', () {
      for (var i = 0; i < 50; i++) {
        final c = makeParentGate();
        expect(c.promptIn('en'), c.prompt);
        expect(checkParentGate(c.answer, c), isTrue);
      }
    });
  });

  group('adult check dialog', () {
    Widget harness(List<ParentGateChallenge> queue, {String lang = 'en'}) =>
        ProviderScope(
          overrides: [
            parentGateChallengeProvider.overrideWith((_) => queue.removeAt(0)),
          ],
          child: MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => showParentGateDialog(context, ref),
                  child: const Text('open gate'),
                ),
              ),
            ),
          ),
        );

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('open gate'));
      await tester.pumpAndSettle();
    }

    Future<void> cancel(WidgetTester tester) async {
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('asks a new number every time it opens', (tester) async {
      final queue = [
        const ParentGateChallenge(prompt: 'four — two — nine', answer: '429'),
        const ParentGateChallenge(prompt: 'one — eight — six', answer: '186'),
        const ParentGateChallenge(prompt: 'seven — seven — zero', answer: '770'),
      ];
      await tester.pumpWidget(harness(queue));

      await open(tester);
      expect(find.textContaining('four — two — nine'), findsOneWidget);
      await cancel(tester);

      await open(tester);
      expect(find.textContaining('four — two — nine'), findsNothing);
      expect(find.textContaining('one — eight — six'), findsOneWidget);
    });

    testWidgets('speaks to a Swahili family in Swahili', (tester) async {
      final queue = [
        const ParentGateChallenge(prompt: 'four — two — nine', answer: '429'),
        const ParentGateChallenge(prompt: 'one — eight — six', answer: '186'),
      ];
      await tester.pumpWidget(harness(queue, lang: 'sw'));

      await open(tester);
      expect(find.textContaining('nne — mbili — tisa'), findsOneWidget);
      expect(find.textContaining('four'), findsNothing);
    });
  });

  group('Parent Zone gate during a PIN lockout', () {
    late OfflineStore store;

    setUpAll(() {
      Hive.init(Directory.systemTemp.path);
      debugDisableSavannaAmbient = true;
      debugDisableMascotAnimation = true;
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

    Future<void> seedLockedPinFamily() async {
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
      for (var i = 0; i < OfflineStore.pinMaxAttempts; i++) {
        await store.tryPin('0000');
      }
      expect(store.isPinLocked, isTrue);
    }

    FilledButton unlockButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('says why the field is shut when it arrives locked',
        (tester) async {
      await seedLockedPinFamily();
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      goTo(tester, '/parent');
      await tester.pumpAndSettle();

      expect(unlockButton(tester).onPressed, isNull);
      expect(find.textContaining('Too many tries'), findsOneWidget);
    });

    testWidgets('opens again by itself when the lockout ends', (tester) async {
      await seedLockedPinFamily();
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      goTo(tester, '/parent');
      await tester.pumpAndSettle();
      expect(unlockButton(tester).onPressed, isNull);

      // The lockout lapsing, as far as the screen can tell.
      await store.clearPinFailures();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(unlockButton(tester).onPressed, isNotNull);
      expect(find.textContaining('Too many tries'), findsNothing);
    });
  });
}
