import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/app.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_models.dart';
import 'package:watoto_mobile/features/lesson_player/lesson_repository.dart';

const _lesson = LessonBody(
  schema: 'watoto.lesson/1.0',
  titleKey: 'lessonCountingTitle',
  blocks: [
    ConceptBlock(textKey: 'lessonCountingTitle', emoji: '🥭'),
    TapToCountBlock(items: 3),
    CheckBlock(
      promptKey: 'checkAnswerPrompt',
      options: [
        CheckOption(text: '2', correct: false),
        CheckOption(text: '3', correct: true),
      ],
    ),
  ],
  completion: LessonCompletion(xp: 10, stars: 1, skills: ['counting.1-10']),
);

Widget buildApp() {
  return ProviderScope(
    overrides: [
      lessonProvider.overrideWith((ref, slug) async => _lesson),
    ],
    child: const WatotoApp(),
  );
}

void main() {
  testWidgets('home shows greeting, subjects, and daily challenge', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Jambo, Amani!'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
  });

  testWidgets('child completes the counting lesson and earns XP', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Enter the lesson from the Math island.
    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    expect(find.text('Counting 1 to 3'), findsWidgets);

    // Block 1: concept → Next.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Block 2: tap all three mangoes, then Next.
    expect(find.text('Tap each mango to count it!'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('🥭').at(i));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Block 3: wrong answer is forgiving, correct answer completes.
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('So close! Try again!'), findsOneWidget);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);

    // Done → home, with XP banked.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('10 XP'), findsOneWidget);
  });

  testWidgets('locale switches to Swahili', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose your language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();

    expect(find.text('Changamoto ya Leo'), findsOneWidget);
    expect(find.text('Hesabu'), findsOneWidget);
  });
}
