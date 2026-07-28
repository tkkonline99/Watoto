import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/legal/legal_doc_screen.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

Widget _host(LegalDoc doc) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LegalDocScreen(doc: doc),
    );

void main() {
  testWidgets('privacy policy bundles and renders from assets', (tester) async {
    await tester.pumpWidget(_host(LegalDoc.privacy));
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsOneWidget); // app bar title
    expect(find.textContaining('Privacy Policy — Watoto'), findsOneWidget);
    // Production publish copy (not "working draft").
    expect(find.textContaining('working draft', findRichText: true), findsNothing);
    expect(find.textContaining('privacy@watoto.app', findRichText: true), findsWidgets);
  });

  testWidgets('terms of service bundles and renders from assets', (tester) async {
    await tester.pumpWidget(_host(LegalDoc.terms));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.textContaining('Terms of Service — Watoto'), findsOneWidget);
    expect(find.textContaining('DRAFT'), findsNothing);
  });
}
