import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

/// Simulates being offline: every sync attempt fails, ops must stay queued.
class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// Drives the router straight to a location, for tests whose subject is the
/// screen rather than the journey to it. The app opens on `/welcome`, so most
/// tests here start with `goTo(tester, '/')`.
void goTo(WidgetTester tester, String location) {
  ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
      .read(appRouterProvider)
      .go(location);
}

/// Stands in for a grown-up passing `/parent/unlock`, for tests whose subject
/// is what lies *behind* the gate rather than the gate itself.
void unlockParent(WidgetTester tester) {
  ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
      .read(sessionProvider.notifier)
      .unlockParent();
}

/// The home XP counter is a stat pill that renders the bare number ("⭐ 10");
/// the readable `<n> XP · Level <l>` string lives only on its semantics label,
/// so assert against the semantics tree rather than the pill's digits.
void expectXp(WidgetTester tester, int xp) {
  final handle = tester.ensureSemantics();
  expect(find.bySemanticsLabel(RegExp('^$xp XP')), findsOneWidget);
  handle.dispose();
}

/// The subject grid sits below the fold on the test surface, so scroll the home
/// list until the tile is on screen.
Future<void> scrollToSubjects(WidgetTester tester, Finder tile) async {
  await tester.scrollUntilVisible(tile, 200);
  await tester.pumpAndSettle();
}

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    // Hold the perpetual savanna ambient drift still so pumpAndSettle (used
    // throughout) doesn't wait forever on an animation that never completes.
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
    // Most tests here jump straight to a learning surface; the login gate has
    // its own group below, which turns this back off.
    debugSkipLoginGate = true;
  });

  setUp(() async {
    store = await OfflineStore.open(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  /// Seeds an onboarded family (PIN 1234, child "Amani") so tests start on
  /// the child home instead of onboarding.
  Future<String> seedOnboarded() async {
    final child = await store.completeOnboarding(
      consent: const ConsentRecord(
          coreData: true, aiFeatures: false, voiceRecording: false, recordedAt: null),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    return child.id;
  }

  Widget buildApp() => ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_UnreachableApi()),
        ],
        child: const WatotoApp(),
      );

  testWidgets('first run: onboarding -> consent -> account -> child -> home',
      (tester) async {
    // The onboarding cards can exceed a short test viewport; give them room so
    // the primary buttons aren't scrolled off-screen when tapped.
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // store is fresh (not onboarded) -> app must start in onboarding.
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    // The button can sit below the fold on a small test viewport; bring it in.
    final letsGo = find.text("Let's go! 🚀");
    await tester.ensureVisible(letsGo);
    await tester.pump();
    await tester.tap(letsGo);
    await tester.pumpAndSettle();

    // The grown-up gate step has been removed: language -> consent directly.
    expect(find.text('A safe place to learn'), findsOneWidget);
    final agree = find.text('Agree & continue');
    await tester.ensureVisible(agree);
    await tester.tap(agree);
    await tester.pumpAndSettle();

    // Default secure step = create a parent account (no PIN asked).
    await tester.enterText(find.byType(TextField).at(0), 'parent@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.pump(); // let the (input-gated) Next button enable
    final next = find.text('Next');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Zuri');
    await tester.pumpAndSettle();
    final done = find.text('Done');
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(find.text('Hello, Zuri!'), findsOneWidget);
    expect(store.onboardingComplete, isTrue);
    expect(store.children.single.nickname, 'Zuri');
    expect(store.hasAccount, isTrue);
    expect(store.accountEmail, 'parent@example.com');
    expect(store.isLoggedIn, isTrue);
    expect(store.hasPin, isFalse); // account families are never asked for a PIN
  });

  testWidgets('a signed-in account family is still gated at the parent zone',
      (tester) async {
    // The trap this guards: being logged in used to *be* parent access, so a
    // child using the family's session all afternoon could open settings,
    // purchases and account deletion by tapping the padlock.
    await store.completeOnboarding(
      consent: const ConsentRecord(
          coreData: true, aiFeatures: false, voiceRecording: false, recordedAt: null),
      accountEmail: 'mom@example.com',
      accountPassword: 'secret123',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/');
    await tester.pumpAndSettle();
    // Onboarding leaves the zone open for setup; a child's session would not.
    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(sessionProvider.notifier)
        .lockParent();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Parent Zone'));
    await tester.pumpAndSettle();

    // Account families used to have no gate at all — now they get one, asking
    // for the password rather than a PIN they never set.
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.text('Enter your password to continue.'), findsOneWidget);
    expect(find.text('Children'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Children'), findsNothing);

    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Children'), findsOneWidget);
  });

  testWidgets('the account screen is behind the gate too', (tester) async {
    // It can change the password and delete the family; a padlock on the
    // Parent Zone alone would just move the door.
    await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/');
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(sessionProvider.notifier)
        .lockParent();
    await tester.pumpAndSettle();

    goTo(tester, '/account');
    await tester.pumpAndSettle();
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.text('My account'), findsNothing);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('My account'), findsOneWidget);
  });

  testWidgets('the account screen shows the family their own information',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await store.completeOnboarding(
      consent: ConsentRecord(
        coreData: true,
        aiFeatures: false,
        voiceRecording: false,
        recordedAt: DateTime.utc(2026, 3, 4),
      ),
      accountEmail: 'mom@example.com',
      accountPassword: 'secret123',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    unlockParent(tester);
    goTo(tester, '/account');
    await tester.pumpAndSettle();

    expect(find.text('My account'), findsOneWidget);
    // Exactly once: the header used to repeat the address as a subtitle.
    expect(find.text('mom@example.com'), findsOneWidget);
    expect(find.text('Email & password'), findsOneWidget);
    expect(find.text('Amani, age ${DateTime.now().year - 2019}'),
        findsOneWidget);
    // Consent is reported as what was turned on, not just a date.
    expect(find.text('Progress saving only'), findsOneWidget);
    // Plan and where the progress actually lives.
    expect(find.text('On this device only'), findsOneWidget);
    expect(find.text('Everything is saved'), findsOneWidget);
    // An account family is offered a password change, not a PIN change.
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Change PIN'), findsNothing);
    expect(find.text('Add an email'), findsNothing);
    // Both dispose-of-my-data actions are offered, log out first.
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('unsynced work is reported, not silently at risk',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final childId = await seedOnboarded();
    await store.recordLessonCompleted(
      childId: childId,
      lessonId: 'counting-1-3',
      scorePct: 100,
      timeSpentS: 60,
      xpEarned: 10,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    unlockParent(tester);
    goTo(tester, '/account');
    await tester.pumpAndSettle();

    expect(find.textContaining('waiting to sync'), findsOneWidget);
    expect(find.text('Everything is saved'), findsNothing);
  });

  testWidgets('a PIN family is offered an email, and adding one keeps the PIN',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedOnboarded(); // PIN 1234, no account
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    unlockParent(tester);
    goTo(tester, '/account');
    await tester.pumpAndSettle();

    expect(find.text('No email saved'), findsOneWidget);
    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('Change password'), findsNothing);

    final add = find.text('Add an email');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'dad@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.accountEmail, 'dad@example.com');
    expect(store.hasAccountPassword, isTrue);
    // The PIN is not traded away — the family can use either.
    expect(store.hasPin, isTrue);
    expect(store.verifyPin('1234'), isTrue);
  });

  testWidgets('a grown-up who knows the password can change it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await store.completeOnboarding(
      consent: const ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: null),
      accountEmail: 'mom@example.com',
      accountPassword: 'secret123',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    unlockParent(tester);
    goTo(tester, '/account/password');
    await tester.pumpAndSettle();

    // The wrong current password changes nothing.
    await tester.enterText(find.byType(TextField).at(0), 'not-it');
    await tester.enterText(find.byType(TextField).at(1), 'brandnew1');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('That password is not right'), findsOneWidget);
    expect(store.verifyAccount('secret123'), isTrue);

    await tester.enterText(find.byType(TextField).at(0), 'secret123');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.verifyAccount('brandnew1'), isTrue);
    expect(store.verifyAccount('secret123'), isFalse);
  });

  testWidgets('a grown-up who knows the PIN can change it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedOnboarded(); // PIN 1234
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    unlockParent(tester);
    goTo(tester, '/account/pin');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '9999');
    await tester.enterText(find.byType(TextField).at(1), '5678');
    await tester.enterText(find.byType(TextField).at(2), '5678');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('That PIN is not right'), findsOneWidget);
    expect(store.verifyPin('1234'), isTrue);

    await tester.enterText(find.byType(TextField).at(0), '1234');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.verifyPin('5678'), isTrue);
    expect(store.verifyPin('1234'), isFalse);
  });

  testWidgets('logging out from the account screen returns to the welcome '
      'screen and ends the session', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedOnboarded(); // PIN 1234, no account
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    unlockParent(tester);
    goTo(tester, '/account');
    await tester.pumpAndSettle();

    final logOut = find.text('Log out');
    await tester.ensureVisible(logOut);
    await tester.tap(logOut);
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    expect(store.isLoggedIn, isFalse);
  });

  testWidgets('deleting the account erases the device back to first run',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final childId = await seedOnboarded();
    await store.recordLessonCompleted(
      childId: childId,
      lessonId: 'counting-1-3',
      scorePct: 100,
      timeSpentS: 60,
      xpEarned: 25,
    );
    expect(store.xpFor(childId), 25);
    expect(store.pendingOps, isNotEmpty);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    unlockParent(tester);
    goTo(tester, '/account');
    await tester.pumpAndSettle();

    final delete = find.text('Delete account');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    // Destructive, so it asks first.
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(store.onboardingComplete, isFalse);
    expect(store.children, isEmpty);
    expect(store.hasAccount, isFalse);
    expect(store.hasPin, isFalse);
    expect(store.xpFor(childId), 0);
    expect(store.pendingOps, isEmpty);
    // Back at the very beginning.
    expect(find.text('Choose your language'), findsOneWidget);
  });

  testWidgets('home shows greeting, subjects, and daily challenge', (tester) async {
    await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/'); // app opens on the welcome screen; enter the home
    await tester.pumpAndSettle();

    expect(find.text('Hello, Amani!'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expectXp(tester, 0);
    await scrollToSubjects(tester, find.text('Math'));
    expect(find.text('Math'), findsOneWidget);
  });

  testWidgets('parent zone is PIN-gated', (tester) async {
    await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/'); // app opens on the welcome screen; enter the home
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Parent Zone'));
    await tester.pumpAndSettle();
    expect(find.text('Grown-ups only'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong PIN, try again'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Children'), findsOneWidget);
    // The dashboard names the child in both the weekly snapshot and the
    // children list, so more than one match is expected here.
    expect(find.text('Amani'), findsWidgets);
  });

  testWidgets('locale switches to Swahili', (tester) async {
    await seedOnboarded();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    goTo(tester, '/'); // app opens on the welcome screen; enter the home
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose your language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();

    expect(find.text('Changamoto ya Leo'), findsOneWidget); // dailyChallenge
    expect(find.text('Jambo, Amani!'), findsOneWidget); // localized greeting
    // Note: subject tile names come from the curriculum content (English in the
    // source deck), so they are not localized yet — only UI chrome is.
  });

  /// Watoto keeps no session between launches: the email is remembered, the
  /// password or PIN is not. These run with the real gate in place.
  group('login gate', () {
    setUp(() => debugSkipLoginGate = false);
    tearDown(() => debugSkipLoginGate = true);

    Future<void> pumpTall(WidgetTester tester) async {
      // The login card plus its recovery links overflow a short viewport.
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
    }

    Future<void> tapLetsGo(WidgetTester tester) async {
      final letsGo = find.text("Let's go! 🚀");
      await tester.ensureVisible(letsGo);
      await tester.pump();
      await tester.tap(letsGo);
      await tester.pumpAndSettle();
    }

    testWidgets('"Let\'s go" leads to the login page, not the home',
        (tester) async {
      await seedOnboarded(); // PIN 1234
      await pumpTall(tester);

      // A returning family lands on the welcome screen, signed out.
      expect(find.text('Choose your language'), findsOneWidget);
      await tapLetsGo(tester);

      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Hello, Amani!'), findsNothing);
    });

    testWidgets('a stored account is remembered but its password is not',
        (tester) async {
      await store.completeOnboarding(
        consent: const ConsentRecord(
            coreData: true,
            aiFeatures: false,
            voiceRecording: false,
            recordedAt: null),
        accountEmail: 'mom@example.com',
        accountPassword: 'secret123',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: 2019,
      );
      // Onboarding logged them in; a relaunch must not inherit that session.
      await store.signOut();
      await pumpTall(tester);
      await tapLetsGo(tester);

      // Email prefilled, password demanded.
      expect(find.text('mom@example.com'), findsOneWidget);
      final password = find.byType(TextField).at(1);

      await tester.enterText(password, 'wrong-one');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong password, try again'), findsOneWidget);
      expect(find.text('Hello, Amani!'), findsNothing);

      await tester.enterText(password, 'secret123');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Amani!'), findsOneWidget);
    });

    testWidgets('a PIN family gets in with the PIN', (tester) async {
      await seedOnboarded(); // PIN 1234
      await pumpTall(tester);
      await tapLetsGo(tester);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Amani!'), findsOneWidget);
    });

    testWidgets('deep links are held at the gate, then handed back',
        (tester) async {
      await seedOnboarded();
      await pumpTall(tester);

      goTo(tester, '/curriculum');
      await tester.pumpAndSettle();
      // Gate first...
      expect(find.text('Welcome back!'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      // ...then the place they were actually going.
      expect(find.text('Welcome back!'), findsNothing);
      expect(find.textContaining('Curriculum'), findsWidgets);
    });

    testWidgets('someone locked out can still reach recovery', (tester) async {
      await seedOnboarded();
      await pumpTall(tester);
      await tapLetsGo(tester);

      final forgot = find.text('Forgot your PIN?');
      expect(forgot, findsOneWidget);
      await tester.ensureVisible(forgot);
      await tester.tap(forgot);
      await tester.pumpAndSettle();
      expect(find.text('Set new PIN'), findsOneWidget);
    });
  });
}
