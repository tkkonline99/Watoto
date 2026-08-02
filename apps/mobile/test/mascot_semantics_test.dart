import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/widgets/mascot_widget.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

/// Six of the seven MascotWidget call sites pass no label, so the default is
/// what a child using a screen reader actually hears for the most prominent
/// thing on the home screen. It used to be the English literal "Kibo the lion
/// cub" in every language.

Widget _host(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MascotWidget()),
    );

void main() {
  setUp(() => debugDisableMascotAnimation = true);
  tearDown(() => debugDisableMascotAnimation = false);

  testWidgets('the mascot introduces itself in the child\'s language',
      (tester) async {
    const expected = {
      'en': 'Kibo the lion cub',
      'sw': 'Kibo mtoto wa simba',
      'fr': 'Kibo le lionceau',
    };
    final handle = tester.ensureSemantics();
    for (final entry in expected.entries) {
      await tester.pumpWidget(_host(Locale(entry.key)));
      await tester.pump();
      expect(
        find.bySemanticsLabel(entry.value),
        findsOneWidget,
        reason: 'mascot label wrong in ${entry.key}',
      );
    }
    handle.dispose();
  });

  testWidgets('an explicit label still wins', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MascotWidget(label: 'Bravo !')),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Bravo !'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('renders without a Localizations ancestor', (tester) async {
    // Loading and error states can build before localizations exist; a
    // semantic label must never be the thing that crashes them.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MascotWidget(),
      ),
    );
    await tester.pump();
    expect(find.byType(MascotWidget), findsOneWidget);
  });
}
