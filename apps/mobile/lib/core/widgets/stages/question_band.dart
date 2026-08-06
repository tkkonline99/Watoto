/// Band parameters for the question screen skeleton (docs/26 §26.4).
///
/// One skeleton renders every question in the app; what changes across the
/// age range is the size of things, how many choices fit, and whether the text
/// carries meaning at all. Those are collected here rather than spread through
/// the stage widgets, so "how big is a target for a three-year-old" has exactly
/// one answer.
///
/// The band names are the design's. Stages in this library run 1–10, so the
/// document's "0–2 Discover" band is stages 1–2, "3–5 Explore" is 3–5, and so
/// on.
library;

enum QuestionBand {
  /// Ages 0–2. Audio is the question; text is decorative. No fail state.
  discover,

  /// Ages 3–5. The prompt is narrated and answers may be glyphs.
  explore,

  /// Ages 6–8. Text carries meaning. Parent-led activities gain the step strip.
  build,

  /// Ages 9–10. Deeper palette, playful chrome recedes.
  master,
}

QuestionBand bandForStage(int stage) => switch (stage) {
      <= 2 => QuestionBand.discover,
      <= 5 => QuestionBand.explore,
      <= 8 => QuestionBand.build,
      _ => QuestionBand.master,
    };

extension QuestionBandStyle on QuestionBand {
  /// Tap target edge, in logical pixels.
  double get targetSize => switch (this) {
        QuestionBand.discover => 132,
        QuestionBand.explore => 88,
        QuestionBand.build => 88,
        QuestionBand.master => 88,
      };

  /// How many choices may be offered at once.
  int get maxChoices => switch (this) {
        QuestionBand.discover => 2,
        QuestionBand.explore => 3,
        QuestionBand.build => 4,
        QuestionBand.master => 4,
      };

  /// Prompt size. The design gives a 21–26sp range: the youngest band takes
  /// the top of it because the sentence is short and read aloud, the oldest
  /// the bottom because the sentence is doing the work.
  double get promptSize => switch (this) {
        QuestionBand.discover => 26,
        QuestionBand.explore => 24,
        QuestionBand.build => 22,
        QuestionBand.master => 21,
      };

  /// Answer rows go full-width once the text is what distinguishes them; below
  /// that, options are tiles a child can hit without reading.
  bool get fullWidthChoices => switch (this) {
        QuestionBand.discover => false,
        QuestionBand.explore => false,
        QuestionBand.build => true,
        QuestionBand.master => true,
      };

  /// Whether an answer can be wrong at all. The youngest band acknowledges
  /// every tap (§26.4) — there is no fail state to render.
  bool get hasFailState => this != QuestionBand.discover;
}
