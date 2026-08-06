/// The one skeleton every question, check, activity and story page renders on
/// (docs/26 §26.2).
///
/// Six parts, always in this order: chrome, progress, stage, prompt, response
/// zone, assist line. A screen may shrink the stage; it may never remove it.
/// That fixed reservation is the point — before it, a screen with little
/// content collapsed into a void at the top and a screen with a lot of content
/// crowded, because the column was centred in whatever space was left over.
///
/// Vertical slack collects *between the prompt and the response zone*, so a
/// sparse screen breathes in the middle rather than leaving a hole above.
///
/// The scaffold owns parts 1–3 and 6. Stage widgets supply only the prompt and
/// the response zone; that split is what keeps the skeleton honest, because a
/// stage widget has no way to move the chrome or drop the stage.
library;

import 'package:flutter/material.dart';

import '../../theme/watoto_theme.dart';
import 'question_band.dart';

/// Progress along an activity — dots for lesson steps, "n of m" for quizzes.
class QuestionProgress {
  const QuestionProgress({
    required this.index,
    required this.total,
    this.asCount = false,
    this.streak,
  });

  final int index;
  final int total;

  /// Quizzes count ("3 of 8"); lessons show dots.
  final bool asCount;

  /// Shown as a chip on the right when a streak is running.
  final int? streak;
}

class QuestionScaffold extends StatelessWidget {
  const QuestionScaffold({
    super.key,
    required this.stage,
    required this.stageVisual,
    required this.prompt,
    required this.response,
    this.progress,
    this.assist,
    this.textHeavy = false,
    this.stageSemanticLabel,
    this.stageFitsContent = false,
  });

  /// Curriculum stage 1–10; selects the band (§26.4).
  final int stage;

  /// Part 3. Never null — §26.3 allows no empty stage.
  final Widget stageVisual;

  /// Part 4. One sentence naming what the stage shows.
  final String prompt;

  /// Part 5. Tiles, bins, an ordering rail, or a single pill.
  final Widget response;

  /// Part 2. Omitted on screens with nothing to count.
  final QuestionProgress? progress;

  /// Part 6. What to do next, or the audio-repeat offer. Never a scold.
  final Widget? assist;

  /// Comprehension and story screens shrink the stage to 180dp so the text has
  /// room; everything else keeps the full 300dp.
  final bool textHeavy;

  /// The visual's `alt`, announced in place of the artwork.
  final String? stageSemanticLabel;

  /// Let the stage size to its content instead of the banded height.
  ///
  /// For the code editor and the circuit board the workspace *is* the stage,
  /// and those are taller than 300dp — the circuit board alone overflowed by
  /// 317 pixels when it was forced into the fixed reservation. §26.2 says a
  /// screen may shrink the stage and may never remove it; it does not require
  /// a workspace to be clipped, so these grow instead and the scaffold's
  /// scroll view takes up the slack.
  final bool stageFitsContent;

  double get _stageHeight => textHeavy ? 180 : 300;

  @override
  Widget build(BuildContext context) {
    final band = bandForStage(stage);
    // A canvas-owning stage (the code editor, the circuit board) has no slack
    // to distribute — the workspace is what fills the screen — so it simply
    // scrolls. It also cannot go through IntrinsicHeight: those workspaces
    // build with a LayoutBuilder, and asking a LayoutBuilder for its intrinsic
    // height throws.
    if (stageFitsContent) {
      return SafeArea(
        child: SingleChildScrollView(child: _body(band, slack: false)),
      );
    }
    // Otherwise the stage is a fixed reservation, so on a short viewport the
    // six parts can exceed the height available. Rather than clip or overflow,
    // the whole column scrolls — and because the inner column is still forced
    // to at least the viewport height, the Spacer keeps collecting slack in
    // the middle whenever there *is* room. Shrinking the stage instead would
    // break the one rule §26.2 states outright.
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: _body(band, slack: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(QuestionBand band, {required bool slack}) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (progress case final p?) ...[
              _Progress(progress: p),
              const SizedBox(height: 12),
            ],
            _Stage(
              height: stageFitsContent ? null : _stageHeight,
              label: stageSemanticLabel,
              child: stageVisual,
            ),
            const SizedBox(height: 20),
            // liveRegion so a screen reader announces the new sentence when
            // the step advances. Without it the prompt changes silently and a
            // child using TalkBack is left on the previous question.
            Semantics(
              liveRegion: true,
              child: Text(
                prompt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: band.promptSize,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: WatotoColors.deep,
                ),
              ),
            ),
            // The slack lives here, between prompt and response — see the
            // library docstring.
            if (slack) const Spacer() else const SizedBox(height: 24),
            response,
            if (assist case final a?) ...[
              const SizedBox(height: 12),
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: WatotoColors.sky,
                ),
                child: a,
              ),
            ],
          ],
        ),
      );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.height, required this.child, this.label});

  /// Null lets the stage size to its content (see `stageFitsContent`).
  final double? height;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final stage = SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: Colors.white,
          child: Center(child: child),
        ),
      ),
    );
    if (label == null || label!.isEmpty) return stage;
    // The stage is not tappable, so the short form is safe here — see the
    // note in subject_island.dart about never using it on a tap target.
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: stage,
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress});

  final QuestionProgress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: p.asCount
                ? Text(
                    '${p.index + 1} of ${p.total}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < p.total; i++)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= p.index
                                ? WatotoColors.sun
                                : WatotoColors.sun.withValues(alpha: 0.28),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        if (p.streak case final s? when s > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: WatotoColors.sun.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '🔥 $s',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}
