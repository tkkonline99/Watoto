import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/parent/guides_screen.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

/// The curriculum-guides library bundled from the "Subjects" drop
/// (tool/convert_guides.py): manifest integrity + the two screens render.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('manifest', () {
    test(
      'loads, ids are unique, and every asset exists and is non-empty',
      () async {
        final repo = await GuidesRepository.load();

        expect(repo.groups, hasLength(7)); // overview + early years + K–G4
        final docs = [for (final g in repo.groups) ...g.docs];
        expect(docs, hasLength(35));
        expect(repo.byId, hasLength(35)); // ids unique

        for (final doc in docs) {
          final md = await rootBundle.loadString(doc.asset);
          expect(md.trim(), isNotEmpty, reason: doc.id);
          expect(md, startsWith('# '), reason: '${doc.id} has a title heading');
        }
      },
    );

    test('every grade band ships the core subjects', () async {
      final repo = await GuidesRepository.load();
      for (final band in ['g1', 'g2', 'g3', 'g4']) {
        final group = repo.groups.singleWhere((g) => g.band == band);
        expect(group.docs.length, 6, reason: band);
      }
      // Known drop gap: Kindergarten has no Math package.
      final k = repo.groups.singleWhere((g) => g.band == 'k');
      expect(k.docs.length, 5);
      expect(k.docs.map((d) => d.id), isNot(contains('k-math')));
    });
  });

  Widget wrap(Widget child) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  /// Pumps [child] letting real asset I/O complete: rootBundle loads run on
  /// the real event loop, which the fake-async pump loop never services —
  /// without this the loading spinner animates until pumpAndSettle times out.
  /// Two rounds because the doc screen chains manifest → content loads.
  Future<void> pumpWithAssets(WidgetTester tester, Widget child) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(wrap(child));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('guides list renders groups and doc tiles', (tester) async {
    await pumpWithAssets(tester, const GuidesScreen());

    // Top of the (lazy) list: app bar, overview group, early years group.
    expect(find.text('Curriculum Guides'), findsOneWidget);
    expect(find.text('Overview — Ages 0–10'), findsOneWidget);
    expect(find.text('Early Years — Ages 0–5'), findsOneWidget);
    expect(find.text('Master Curriculum Overview'), findsOneWidget);

    // The last band is far below the fold; scroll it into view.
    await tester.scrollUntilVisible(
      find.text('Grade 4 — Ages 9–10'),
      400,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Grade 4 — Ages 9–10'), findsOneWidget);
  });

  testWidgets('a guide document renders its content', (tester) async {
    await pumpWithAssets(tester, const GuideDocScreen(id: 'g1-math'));

    expect(find.widgetWithText(AppBar, 'Math'), findsOneWidget);
    expect(find.text('MATH — GRADE 1 (AGES 6–7)'), findsOneWidget);
    expect(find.text('1. Program Overview'), findsOneWidget);
  });
}
