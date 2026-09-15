library;

/// The last English a Swahili or French family could meet outside the lessons,
/// each pinned below:
/// - the free/Premium line on the Parent Dashboard and the paywall;
/// - `Not found: <id>` when a lesson id no longer exists (the guides screen
///   printed the same line);
/// - go_router's own "Page Not Found" for a link that matches no route.
/// Neither not-found page offered a way back, either.
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
import 'package:watoto_mobile/core/widgets/watoto_status_views.dart';
import 'package:watoto_mobile/features/auth/entitlements.dart';
import 'package:watoto_mobile/features/library/content_i18n.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
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
  group('free and Premium line', () {
    final en = lookupAppLocalizations(const Locale('en'));

    for (final lang in ['sw', 'fr']) {
      test('is not English for a $lang family', () {
        final l10n = lookupAppLocalizations(Locale(lang));
        for (final premium in [false, true]) {
          for (final freeOnly in [false, true]) {
            final local = freePremiumMapSummary(
              l10n,
              isPremium: premium,
              freeOnly: freeOnly,
            );
            final english = freePremiumMapSummary(
              en,
              isPremium: premium,
              freeOnly: freeOnly,
            );
            expect(local, isNot(english));
            expect(local, isNot(contains('stages')));
          }
        }
      });
    }

    test('a paid build names where the free stages end', () {
      final s = freePremiumMapSummary(en, isPremium: false, freeOnly: false);
      expect(s, contains('1–$freeStageMax'));
      expect(s, contains('${freeStageMax + 1}–10'));
    });

    test('the free-only launch says so whatever the plan', () {
      for (final premium in [false, true]) {
        expect(
          freePremiumMapSummary(en, isPremium: premium, freeOnly: true),
          en.premiumMapFreeLaunch,
        );
      }
    });
  });

  group('not found', () {
    late OfflineStore store;

    setUpAll(() {
      Hive.init(Directory.systemTemp.path);
      debugDisableSavannaAmbient = true;
      debugDisableMascotAnimation = true;
      debugSkipLoginGate = true;
    });

    setUp(() async => store = await OfflineStore.open(inMemory: true));
    tearDown(() async => await store.close());

    Widget buildApp({List<Override> extra = const []}) => ProviderScope(
          overrides: [
            offlineStoreProvider.overrideWithValue(store),
            syncApiProvider.overrideWithValue(_Offline()),
            ...extra,
          ],
          child: const WatotoApp(),
        );

    void goTo(WidgetTester tester, String location) =>
        ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
            .read(appRouterProvider)
            .go(location);

    Future<void> seedFamily() => store.completeOnboarding(
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

    testWidgets('speaks the family language and offers the way home',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            locale: Locale('sw'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WatotoNotFoundScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sw = lookupAppLocalizations(const Locale('sw'));
      expect(find.text(sw.notFoundTitle), findsOneWidget);
      expect(find.text(sw.goHome), findsOneWidget);
      expect(find.textContaining('Not found'), findsNothing);
    });

    testWidgets('a link that matches no route lands on the Watoto page',
        (tester) async {
      await seedFamily();
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      goTo(tester, '/no-such-place');
      await tester.pumpAndSettle();

      expect(find.byType(WatotoNotFoundScreen), findsOneWidget);
      expect(find.textContaining('Page Not Found'), findsNothing);
    });

    testWidgets('a lesson that no longer exists lands on the Watoto page',
        (tester) async {
      await seedFamily();
      await tester.pumpWidget(buildApp(extra: [
        libraryProvider.overrideWith((ref) async => LibraryRepository(const [])),
        contentI18nProvider.overrideWith((ref) async => ContentI18n(const {})),
      ]));
      await tester.pumpAndSettle();

      goTo(tester, '/play/s99.gone.lesson.01');
      await tester.pumpAndSettle();

      expect(find.byType(WatotoNotFoundScreen), findsOneWidget);
      expect(find.textContaining('Not found'), findsNothing);
    });
  });
}
