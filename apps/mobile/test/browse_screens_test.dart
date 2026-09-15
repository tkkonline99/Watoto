library;

/// The screens a family browses between activities, each checked for the way
/// it used to fail:
/// - Storybooks listed all 114 stories — every age — in one column, with each
///   story's subject in English;
/// - a screen whose data failed to load printed the exception;
/// - five tile lists wrapped `ExcludeSemantics` *around* their InkWell, which
///   drops the tap action along with the noise, so a screen reader announced
///   a lesson, an age, a child or an avatar and could not open it;
/// - the curriculum browser was linked from nowhere.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/core/offline/offline_providers.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/features/curriculum/age_picker.dart';
import 'package:watoto_mobile/features/curriculum/curriculum_data.dart';
import 'package:watoto_mobile/features/library/content_i18n.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
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

LibraryItem _item(String id, int stage, String subject, LibraryType type) =>
    LibraryItem(
      id: id,
      stage: stage,
      ages: '',
      subject: subject,
      type: type,
      title: id,
      objective: '',
      designTier: 'parent-led',
      reading: false,
      interaction: 'tap',
      steps: const [
        LessonStep(narration: 'Tap it.', action: 'tap', feedback: 'Yes!'),
      ],
    );

final _library = LibraryRepository([
  _item('baby-story', 1, 'Sensory Exploration', LibraryType.story),
  _item('helper-story', 4, 'Social Studies', LibraryType.story),
  _item('big-story', 9, 'Reading', LibraryType.story),
  _item('read-1', 9, 'Reading', LibraryType.lesson),
]);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  late OfflineStore store;

  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
    debugDisableSavannaAmbient = true;
    debugDisableMascotAnimation = true;
    debugSkipLoginGate = true;
  });

  setUp(() async => store = await OfflineStore.open(inMemory: true));
  tearDown(() async => await store.close());

  Widget buildApp({bool failingLibrary = false}) => ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          syncApiProvider.overrideWithValue(_Offline()),
          libraryProvider.overrideWith((ref) async {
            if (failingLibrary) {
              throw StateError('watoto_content_library.json is corrupt');
            }
            return _library;
          }),
          contentI18nProvider.overrideWith((ref) async => ContentI18n(const {})),
        ],
        child: const WatotoApp(),
      );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(WatotoApp)));

  void goTo(WidgetTester tester, String location) =>
      container(tester).read(appRouterProvider).go(location);

  Future<void> seed({required int age}) => store.completeOnboarding(
        consent: const ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: null,
        ),
        pin: '1234',
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: DateTime.now().year - age,
      );

  /// Room for a whole screen of tiles, so nothing under test sits outside the
  /// lazily built part of a list.
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> open(WidgetTester tester, String location,
      {bool failingLibrary = false}) async {
    await tester.pumpWidget(buildApp(failingLibrary: failingLibrary));
    await tester.pumpAndSettle();
    goTo(tester, location);
    await tester.pumpAndSettle();
  }

  /// The node a screen reader lands on for [label] must be one it can press.
  void expectActivatable(WidgetTester tester, Pattern label) {
    final finder = find.bySemanticsLabel(label);
    expect(finder, findsWidgets, reason: 'nothing announces "$label"');
    final node = tester.getSemantics(finder.first);
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'a screen reader hears "$label" but cannot activate it',
    );
  }

  group('storybooks', () {
    testWidgets('open on the child\'s age, with the others a chip away',
        (tester) async {
      await seed(age: 3); // stage 4
      await open(tester, '/stories');

      expect(find.text('helper-story'), findsOneWidget);
      expect(find.text('baby-story'), findsNothing);
      expect(find.text('big-story'), findsNothing);

      // The row opens centred on the child's own age, so the youngest chip
      // starts off to the left — swipe to it, as a child would.
      final babies = find.widgetWithText(ChoiceChip, en.ageBandLabel('0–1'));
      await tester.ensureVisible(babies);
      await tester.pumpAndSettle();
      await tester.tap(babies);
      await tester.pumpAndSettle();

      expect(find.text('baby-story'), findsOneWidget);
      expect(find.text('helper-story'), findsNothing);
    });

    testWidgets('name the subject in the family\'s language', (tester) async {
      await seed(age: 3);
      await store.setLocaleCode('sw');
      await open(tester, '/stories');

      expect(find.text('Maarifa ya Jamii'), findsOneWidget);
      expect(find.text('Social Studies'), findsNothing);
    });
  });

  group('a library that fails to load', () {
    for (final location in ['/stories', '/play/read-1']) {
      testWidgets('explains itself on $location and offers a retry',
          (tester) async {
        await seed(age: 3);
        await open(tester, location, failingLibrary: true);

        expect(find.text(en.loadErrorTitle), findsOneWidget);
        expect(find.text(en.retry), findsOneWidget);
        expect(find.textContaining('corrupt'), findsNothing);
      });
    }
  });

  group('a screen reader can open what it hears', () {
    testWidgets('a story', (tester) async {
      final semantics = tester.ensureSemantics();
      tallView(tester);
      await seed(age: 3);
      await open(tester, '/stories');
      expectActivatable(tester, RegExp(r'^helper-story\. '));
      semantics.dispose();
    });

    testWidgets('a lesson on the subject screen', (tester) async {
      final semantics = tester.ensureSemantics();
      tallView(tester);
      await seed(age: 8);
      await open(tester, '/subject/9/Reading');
      expectActivatable(tester, RegExp(r'^read-1\. Lesson\. '));
      semantics.dispose();
    });

    testWidgets('a lesson in the curriculum browser', (tester) async {
      final semantics = tester.ensureSemantics();
      tallView(tester);
      await seed(age: 8); // opens on stage 9, where read-1 lives
      await open(tester, '/curriculum');
      expectActivatable(tester, RegExp(r'^read-1\. Lesson\. '));
      semantics.dispose();
    });

    testWidgets('a child on the profile picker', (tester) async {
      final semantics = tester.ensureSemantics();
      tallView(tester);
      await seed(age: 8);
      await open(tester, '/profiles');
      expectActivatable(tester, 'Amani. ${en.whoIsLearning}');
      semantics.dispose();
    });

    testWidgets('a decoration in the shop', (tester) async {
      final semantics = tester.ensureSemantics();
      tallView(tester);
      await seed(age: 8);
      await open(tester, '/shop');
      await tester.scrollUntilVisible(
        find.bySemanticsLabel(RegExp('🪙')).first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expectActivatable(tester, RegExp('🪙'));
      semantics.dispose();
    });

    testWidgets('an age in the age picker', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAgePicker(
                  context,
                  stages: publishedCurriculumStages,
                ),
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      expectActivatable(tester, RegExp('^${en.ageBandLabel('0–1')}\\. '));
      semantics.dispose();
    });
  });

  testWidgets('the Parent Zone links to the curriculum browser, and back',
      (tester) async {
    await seed(age: 8);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    container(tester).read(sessionProvider.notifier).unlockParent();
    goTo(tester, '/parent');
    await tester.pumpAndSettle();

    final link = find.widgetWithText(ListTile, en.curriculum);
    await tester.scrollUntilVisible(
      link,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text(en.forGrownups), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text(en.forGrownups), findsNothing);
    expect(find.widgetWithText(ListTile, en.curriculumGuides), findsOneWidget);
  });
}
