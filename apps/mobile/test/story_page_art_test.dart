/// The story reader must show each page's own drawn picture.
///
/// Every story page in the library names an `illustration` and every one of
/// those PNGs is bundled, but `LibPage.illustration` was parsed and then read
/// by nothing: the reader guessed an emoji from the narration instead, so all
/// six pages of "Ten Apples on Top" showed the same bear while six distinct
/// drawings sat unused in the bundle.
///
/// media_assets_test.dart checks the art is bundled and that the reader still
/// mentions the resolver. This checks the thing a child actually gets: the
/// widget on screen points at *this* page's file, and changes when the page
/// turns.
library;

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
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';
import 'package:watoto_mobile/features/library/step_motion.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/features/onboarding/savanna_background.dart';
import 'package:watoto_mobile/router/app_router.dart';

class _UnreachableApi implements SyncApi {
  @override
  Future<Map<String, String>> syncBatch(List<SyncOp> ops) async =>
      throw SyncApiException('offline');
}

/// Two pages naming two different bundled pictures. Real paths, so a rename
/// in the asset tree fails this rather than passing on a stub.
final _story = LibraryItem(
  id: 'test.story.art',
  stage: 6,
  ages: '6-8',
  subject: 'Math',
  type: LibraryType.story,
  title: 'Ten Apples on Top',
  objective: '',
  designTier: 'encourage-effort',
  reading: true,
  interaction: 'read',
  pages: const [
    LibPage(
      narration: 'A bear balances 3 apples on top of his head.',
      illustration: 'img/s06/bear_apples.png',
    ),
    LibPage(
      narration: 'Three and two is five apples. Wobble, wobble!',
      illustration: 'img/s06/five_apples.png',
    ),
  ],
);

void main() {
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
    debugDisableStepMotion = true;
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
          syncApiProvider.overrideWithValue(_UnreachableApi()),
          libraryProvider.overrideWith(
            (ref) async => LibraryRepository([_story]),
          ),
        ],
        child: const WatotoApp(),
      );

  /// The asset path of every AssetImage currently on screen.
  Set<String> assetsOnScreen(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .map((i) => i.image)
      .whereType<AssetImage>()
      .map((a) => a.assetName)
      .toSet();

  testWidgets('each page renders its own bundled illustration', (tester) async {
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
      birthYear: 2018,
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    ProviderScope.containerOf(tester.element(find.byType(WatotoApp)))
        .read(appRouterProvider)
        .go('/play/${_story.id}');
    await tester.pumpAndSettle();

    expect(find.text(_story.pages[0].narration), findsOneWidget);
    expect(
      assetsOnScreen(tester),
      contains('assets/images/img/s06/bear_apples.png'),
      reason: 'page 1 is not showing its own picture',
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text(_story.pages[1].narration), findsOneWidget);
    final second = assetsOnScreen(tester);
    expect(
      second,
      contains('assets/images/img/s06/five_apples.png'),
      reason: 'page 2 is not showing its own picture',
    );
    expect(
      second,
      isNot(contains('assets/images/img/s06/bear_apples.png')),
      reason: 'the picture did not change when the page turned',
    );
  });
}
