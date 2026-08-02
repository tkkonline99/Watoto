import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/play_stage_code.dart';
import 'package:watoto_mobile/features/library/step_play.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

/// The coding stage used to render its whole editor — RUN, OUTPUT, the
/// instructions, the win line — in hardcoded English, so a Swahili or French
/// child met a wall of English in the middle of a lesson. The play screen
/// deliberately suppresses English planner prompts outside `en`; these tests
/// hold the stage widgets to the same promise.

Widget _host(Locale locale, {bool reduceMotion = false}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
            ),
            child: const SingleChildScrollView(
              child: KidCodeStage(
                plan: StepPlayPlan(
                  mechanic: StepMechanic.codeRun,
                  codeLine: 'print("Hello, world!")',
                  outputLine: 'Hello, world!',
                  codeChallenge: 'message',
                  messageChoices: ['Hello, world!', 'Hi friend!'],
                ),
                onCompleted: _noop,
                onTapSound: _noop,
              ),
            ),
          ),
        ),
      ),
    );

void _noop() {}

/// Every English word the stage used to hardcode. None may survive into a
/// non-English locale.
const _englishOnly = <String>[
  'RUN',
  'OUTPUT',
  'Tap blocks in order!',
  'Ready — smash RUN!',
  'It worked!',
  'What should it say?',
  'What goes in the box?',
];

void main() {
  testWidgets('English still reads as English', (tester) async {
    await tester.pumpWidget(_host(const Locale('en')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('RUN'), findsOneWidget);
    expect(find.text('What should it say?'), findsOneWidget);
  });

  testWidgets('Swahili gets Swahili, not English', (tester) async {
    await tester.pumpWidget(_host(const Locale('sw')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ENDESHA'), findsOneWidget);
    expect(find.text('Iseme nini?'), findsOneWidget);
    for (final english in _englishOnly) {
      expect(
        find.text(english),
        findsNothing,
        reason: 'English "$english" leaked into the Swahili coding stage',
      );
    }
  });

  testWidgets('French gets French, not English', (tester) async {
    await tester.pumpWidget(_host(const Locale('fr')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('LANCER'), findsOneWidget);
    expect(find.text("Qu'est-ce qu'il doit dire ?"), findsOneWidget);
    for (final english in _englishOnly) {
      expect(
        find.text(english),
        findsNothing,
        reason: 'English "$english" leaked into the French coding stage',
      );
    }
  });

  testWidgets('the Python stays Python in every locale', (tester) async {
    // Translating `print` would teach a language that does not exist.
    for (final locale in const [Locale('en'), Locale('sw'), Locale('fr')]) {
      await tester.pumpWidget(_host(locale));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('print('),
        findsWidgets,
        reason: 'code sample should stay Python in $locale',
      );
    }
  });

  testWidgets('reduce-motion holds the RUN button still', (tester) async {
    await tester.pumpWidget(_host(const Locale('en'), reduceMotion: true));
    // The pulse used to repeat() forever regardless of the setting, which both
    // ignored the family's choice and hung pumpAndSettle.
    await tester.pumpAndSettle();

    expect(find.text('RUN'), findsOneWidget);
  });
}
