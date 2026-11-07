import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/widgets/stages/question_band.dart';
import 'package:watoto_mobile/core/widgets/stages/question_scaffold.dart';
import 'package:watoto_mobile/core/widgets/stages/stage_scenes.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/step_visuals.dart';
import 'package:watoto_mobile/features/library/visual_stage.dart';

/// The question screen system (docs/26).
///
/// The design exists because the picture a child saw was guessed from the
/// narration text, and the guess was sometimes plainly wrong. These tests hold
/// the two halves of the fix: content declares what the stage shows, and the
/// player prefers what was declared over anything it could infer.
List<LibraryItem> _load() {
  final raw = File('assets/content/watoto_content_library.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return (json['content'] as List)
      .map((c) => LibraryItem.fromJson(c as Map<String, dynamic>))
      .toList();
}

void main() {
  // Loaded once, synchronously, and shared. Reading it inside a testWidgets
  // body would hang: that runs in a fake-async zone, so an awaited real file
  // read never completes and the test times out with no useful message.
  late final List<LibraryItem> items;
  setUpAll(() => items = _load());

  group('the visual contract', () {
    test('every rendered part declares a visual', () {
      final missing = <String>[];
      var parts = 0;
      for (final item in items) {
        void check(String where, Visual? v) {
          parts++;
          if (v == null) missing.add('${item.id} $where');
        }

        for (var i = 0; i < item.steps.length; i++) {
          check('step $i', item.steps[i].visual);
        }
        for (var i = 0; i < item.questions.length; i++) {
          check('question $i', item.questions[i].visual);
        }
        for (var i = 0; i < item.pages.length; i++) {
          check('page $i', item.pages[i].visual);
        }
      }
      expect(parts, 3556, reason: 'the library changed size — update this');
      expect(missing, isEmpty,
          reason: 'parts with no declared visual: ${missing.take(5)}');
    });

    test('every declared scene has a builder behind it', () {
      // Each scene is built with the data the *player* will hand it, not an
      // empty SceneData. `arithmetic.number-sentence` reads its two numbers
      // out of that text, so building it bare would prove nothing about the
      // parts that actually declare it — and this is what catches a part
      // whose sum sits in a field the player never passes through.
      final refs = <String>{};
      final blank = <String>[];

      for (final item in items) {
        for (var i = 0; i < item.steps.length; i++) {
          final s = item.steps[i];
          final v = s.visual;
          if (v is! SceneVisual) continue;
          refs.add(v.ref);
          final built = buildScene(v.ref,
              data: SceneData(
                count: s.count,
                rows: s.rows,
                cols: s.cols,
                text: s.sceneText,
              ));
          if (built == null) blank.add('${item.id} step $i (${v.ref})');
        }
        for (var i = 0; i < item.questions.length; i++) {
          final q = item.questions[i];
          final v = q.visual;
          if (v is! SceneVisual) continue;
          refs.add(v.ref);
          // count is left null: the player derives it from the answer, and no
          // scene's *existence* depends on it — only its numbers do.
          final built = buildScene(v.ref, data: SceneData(text: q.prompt));
          if (built == null) blank.add('${item.id} question $i (${v.ref})');
        }
      }

      expect(refs, isNotEmpty);
      expect(blank, isEmpty,
          reason: 'authored a scene that core/widgets/stages builds nothing '
              'for, given that part\'s own data — the stage falls back to a '
              'glyph instead of the scene chosen for it: ${blank.take(5)}');
    });

    test('alt text is a real description everywhere', () {
      final thin = <String>[];
      for (final item in items) {
        for (final v in [
          ...item.steps.map((s) => s.visual),
          ...item.questions.map((q) => q.visual),
          ...item.pages.map((p) => p.visual),
        ]) {
          if (v != null && v.alt.trim().split(RegExp(r'\s+')).length < 4) {
            thin.add('${item.id}: "${v.alt}"');
          }
        }
      }
      // alt is the screen-reader label and the art brief at once; one word is
      // useless as either.
      expect(thin, isEmpty, reason: 'alt too thin: ${thin.take(5)}');
    });
  });

  group('a declared visual beats the guess', () {
    // The whole design in one case. "Put a lid on a pan of hot water and watch
    // where the drops form" is s10.science.lesson.05 step 7. The lexicon
    // ladder takes the first noun it recognises, that noun is `lid`, and the
    // lexicon maps lid to a tin of food — so a condensation activity rendered
    // a tin, deterministically, in all three languages.
    const narration =
        'Put a lid on a pan of hot water and watch where the drops form.';

    testWidgets('the condensation step no longer shows a tin of food',
        (tester) async {
      final item = items.firstWhere((i) => i.id == 's10.science.lesson.05');
      final step = item.steps[7];
      expect(step.narration, narration,
          reason: 'this test is pinned to that step; the content moved');

      // The ladder has not been "fixed" — it still produces the tin, and it
      // still would for any step that declares nothing. It has been outranked.
      final guessed = stepIllustrationDetail(item: item, narration: narration);
      expect(guessed.emoji, '🥫');
      expect(guessed.tier, IllustrationTier.lexicon);

      // The step declares a slot, so what a child actually sees is the brief,
      // not the glyph the ladder would have picked. Asserting on the rendered
      // stage rather than on the emoji is the point: for a slot the emoji is
      // computed and then never used.
      expect(step.visual, isA<SlotVisual>());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VisualStage(visual: step.visual, fallbackEmoji: guessed.emoji),
        ),
      ));
      await tester.pump();
      expect(find.text('🥫'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    test('a declared token outranks the narration', () {
      final item = items.firstWhere((i) => i.id == 's10.science.lesson.05');
      // `ice` is registered for science.matter and is a lexicon key, so the
      // declared token resolves to its glyph rather than to whatever the
      // sentence happens to name first.
      final detail = stepIllustrationDetail(
        item: item,
        narration: narration,
        visual: const TokenVisual(ref: 'ice', alt: 'A block of ice melting'),
      );
      expect(detail.emoji, '🧊');
      expect(detail.tier, IllustrationTier.declared);
    });
  });

  group('the skeleton', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('reserves the stage even when the content is sparse',
        (tester) async {
      await tester.pumpWidget(host(const QuestionScaffold(
        stage: 4,
        stageVisual: SizedBox.shrink(),
        prompt: 'Which one is a map?',
        response: SizedBox(height: 40),
      )));
      // §26.2: the stage is a fixed reservation. An empty visual must still
      // occupy it, or a sparse screen collapses into the void the design was
      // written to remove.
      final box = tester.getSize(find.byType(QuestionScaffold));
      expect(box.height, greaterThan(300));
    });

    testWidgets('a brief-only slot shows the striped placeholder',
        (tester) async {
      await tester.pumpWidget(host(const VisualStage(
        visual: SlotVisual(
          ref: 'img/s10/unrendered_slot_fixture.png',
          alt: 'A lid on a pan of hot water, drops forming underneath',
        ),
        fallbackEmoji: '🥫',
      )));
      await tester.pump();
      // Nothing is drawn at that path, so the brief must be on screen rather
      // than the fallback glyph — an unfinished picture should look unfinished.
      expect(find.byType(StripedPlaceholder), findsOneWidget);
      expect(
        find.text('A lid on a pan of hot water, drops forming underneath'),
        findsOneWidget,
      );
      expect(find.text('🥫'), findsNothing);
    });

    testWidgets('the prompt is announced when it changes', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const QuestionScaffold(
        stage: 7,
        stageVisual: SizedBox.shrink(),
        prompt: 'What is 12 × 6?',
        response: SizedBox(height: 40),
      )));
      // A step advance replaces the prompt in place; without a live region a
      // reader stays on the previous question.
      expect(
        tester.getSemantics(find.text('What is 12 × 6?')),
        matchesSemantics(label: 'What is 12 × 6?', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('the stage stays silent when its alt only repeats the prompt',
        (tester) async {
      final handle = tester.ensureSemantics();
      // 478 parts give the picture the same words as the question, because for
      // a question there is often nothing truer to say about it. Announcing
      // both made a reader say the question twice before the answers.
      await tester.pumpWidget(host(const QuestionScaffold(
        stage: 2,
        stageVisual: SizedBox.shrink(),
        stageSemanticLabel: "Which animal says 'moo'?",
        prompt: "Which animal says 'moo'?",
        response: SizedBox(height: 40),
      )));
      expect(
        find.bySemanticsLabel("Which animal says 'moo'?"),
        findsOneWidget,
        reason: 'the prompt should still be announced, exactly once',
      );

      // An alt that says something the prompt does not still gets announced.
      await tester.pumpWidget(host(const QuestionScaffold(
        stage: 2,
        stageVisual: SizedBox.shrink(),
        stageSemanticLabel: 'A cow standing in a green field',
        prompt: "Which animal says 'moo'?",
        response: SizedBox(height: 40),
      )));
      expect(find.bySemanticsLabel('A cow standing in a green field'),
          findsOneWidget);
      handle.dispose();
    });
  });

  group('bands', () {
    test('map stages onto the four bands', () {
      expect(bandForStage(1), QuestionBand.discover);
      expect(bandForStage(2), QuestionBand.discover);
      expect(bandForStage(3), QuestionBand.explore);
      expect(bandForStage(5), QuestionBand.explore);
      expect(bandForStage(6), QuestionBand.build);
      expect(bandForStage(8), QuestionBand.build);
      expect(bandForStage(9), QuestionBand.master);
      expect(bandForStage(10), QuestionBand.master);
    });

    test('the youngest band has no fail state and the fewest choices', () {
      // §26.4: for 0-2 every tap is acknowledged, so nothing can be wrong.
      expect(QuestionBand.discover.hasFailState, isFalse);
      expect(QuestionBand.discover.maxChoices, 2);
      expect(QuestionBand.master.hasFailState, isTrue);
      expect(QuestionBand.discover.targetSize,
          greaterThan(QuestionBand.master.targetSize));
    });
  });
}
