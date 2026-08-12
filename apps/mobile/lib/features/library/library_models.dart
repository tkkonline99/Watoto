/// Playable content library models — the schema from
/// content/watoto_content_library.json (lessons / quizzes / stories), the gate
/// after the curriculum plan. Validated by content/validate_content.py.
library;

enum LibraryType { lesson, quiz, story }

/// What fills the stage on one rendered part (docs/26 §26.3).
///
/// Before this existed the picture was guessed from the narration text by the
/// ladder in step_visuals.dart, which is how "Put a lid on a pan of hot water"
/// came to show a tin of food: `lid` is the first noun the lexicon knows. A
/// declared visual is the author saying what the stage shows, so the guess is
/// only consulted when nothing was declared.
sealed class Visual {
  const Visual({required this.alt});

  /// Screen-reader label and art brief at once — never empty, and required by
  /// `validate_content.py` to be a real description rather than one word.
  final String alt;

  /// The scene/token/slot id. Kept on the base class because every caller that
  /// wants to key off a visual wants this.
  String get ref;

  static Visual? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final ref = j['ref'] as String?;
    final alt = j['alt'] as String? ?? '';
    if (ref == null || ref.isEmpty) return null;
    return switch (j['mode'] as String?) {
      'token' => TokenVisual(ref: ref, alt: alt),
      'scene' => SceneVisual(ref: ref, alt: alt),
      'slot' => SlotVisual(ref: ref, alt: alt),
      // An unknown mode is content from a newer schema than this build. Falling
      // back to the ladder shows *something* rather than an empty stage.
      _ => null,
    };
  }
}

/// A vetted glyph on a tinted disc. [ref] is a key in `visual_tokens.json`,
/// which is generated from the lexicon — so the glyph resolves through
/// `lexiconLookup` and the two cannot disagree.
class TokenVisual extends Visual {
  const TokenVisual({required this.ref, required super.alt});
  @override
  final String ref;
}

/// Composed shapes that encode the maths or the structure. [ref] names a
/// builder in `core/widgets/stages/`; `validate_content.py` rejects a ref with
/// no builder behind it.
class SceneVisual extends Visual {
  const SceneVisual({required this.ref, required super.alt});
  @override
  final String ref;
}

/// Commissioned art, or a brief for art not yet drawn. [ref] is a path under
/// `assets/images/`. A missing file is the normal case for a brief and renders
/// as the striped placeholder carrying [alt] — an unfinished asset should look
/// unfinished rather than silently resolve to something wrong.
class SlotVisual extends Visual {
  const SlotVisual({required this.ref, required super.alt});
  @override
  final String ref;

  String get assetPath => 'assets/images/$ref';
}

class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.stage,
    required this.ages,
    required this.subject,
    required this.type,
    required this.title,
    required this.objective,
    required this.designTier,
    required this.reading,
    required this.interaction,
    this.parentNote,
    this.steps = const [],
    this.questions = const [],
    this.pages = const [],
    this.recap = const [],
  });

  final String id;
  final int stage;
  final String ages;
  final String subject;
  final LibraryType type;
  final String title;
  final String objective;
  final String designTier;
  final bool reading;
  final String interaction;
  final String? parentNote;

  /// Authored recap questions, when the lesson carries its own.
  final List<RecapItem> recap;

  final List<LessonStep> steps; // lesson
  final List<LibQuestion> questions; // quiz
  final List<LibPage> pages; // story

  /// Base reward per content type (mirrors the in-app sample items).
  int get xp => switch (type) {
        LibraryType.lesson => 10,
        LibraryType.quiz => 15,
        LibraryType.story => 8,
      };

  factory LibraryItem.fromJson(Map<String, dynamic> j) {
    final type = LibraryType.values.byName(j['type'] as String);
    return LibraryItem(
      id: j['id'] as String,
      stage: j['stage'] as int,
      ages: j['ages'] as String? ?? '',
      subject: j['subject'] as String,
      type: type,
      title: j['title'] as String,
      objective: j['objective'] as String? ?? '',
      designTier: j['designTier'] as String? ?? '',
      reading: j['reading'] as bool? ?? false,
      interaction: j['interaction'] as String? ?? '',
      parentNote: j['parentNote'] as String?,
      steps: ((j['steps'] as List?) ?? const [])
          .map((s) => LessonStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      questions: ((j['questions'] as List?) ?? const [])
          .map((q) => LibQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      pages: ((j['pages'] as List?) ?? const [])
          .map((p) => LibPage.fromJson(p as Map<String, dynamic>))
          .toList(),
      recap: ((j['recap'] as List?) ?? const [])
          .map((r) => RecapItem.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// An authored end-of-lesson recap question.
///
/// Lessons that state a crisp fact can have their recap derived from their own
/// steps, but most short lessons ("Tap each sound: /c/ /a/ /t/") teach through
/// doing and state nothing extractable. Those carry their question here
/// instead, written against the lesson they belong to.
class RecapItem {
  const RecapItem({
    required this.prompt,
    required this.options,
    required this.answer,
  });

  final String prompt;
  final List<String> options;

  /// Index into [options].
  final int answer;

  factory RecapItem.fromJson(Map<String, dynamic> j) => RecapItem(
        prompt: j['prompt'] as String,
        options: ((j['options'] as List?) ?? const [])
            .map((o) => '$o')
            .toList(),
        answer: j['answer'] as int? ?? 0,
      );

  /// Guards against a malformed authored entry reaching a child.
  bool get isValid =>
      prompt.trim().isNotEmpty &&
      options.length >= 2 &&
      answer >= 0 &&
      answer < options.length &&
      options.every((o) => o.trim().isNotEmpty);
}

class LessonStep {
  const LessonStep({
    required this.narration,
    required this.action,
    required this.feedback,
    this.mechanic,
    this.prompt,
    this.answer,
    this.choices = const [],
    this.figures = const [],
    this.choiceIndex,
    this.count,
    this.rows,
    this.cols,
    this.visual,
  });

  final String narration;
  final String action;
  final String feedback;

  /// What fills this step's stage (docs/26 §26.3), or null on content authored
  /// before the contract — those fall back to the step_visuals ladder.
  final Visual? visual;

  /// Optional explicit mechanic (locale-safe). When set, the player prefers
  /// this over English-keyword heuristics in [planStep].
  /// Values: tap | count | drag | numberAnswer | multiChoice | buildArray |
  /// celebrate | codeRun
  final String? mechanic;

  /// The question put to the child when the step stages a choice. The
  /// narration is the teaching line; this is what they are actually being
  /// asked ("What does the bottom number tell us?").
  final String? prompt;
  final int? answer;
  final List<String> choices;

  /// Language-neutral picture ids, one per entry in [choices], when the
  /// options are drawn rather than written (see circuit_figures.dart). Kept
  /// separate from [choices] so the artwork never depends on the wording,
  /// which differs in all three languages.
  final List<String> figures;
  final int? choiceIndex;
  final int? count;
  final int? rows;
  final int? cols;

  /// Everything this step says, for a scene that reads its subject out of the
  /// words (see `_sumInText` in core/widgets/stages/stage_scenes.dart).
  ///
  /// Both halves, because content splits them either way: the "make ten" steps
  /// teach in [narration] and keep the sum in [prompt]. It lives here so the
  /// player and the contract test read a part the same way — when they each
  /// composed their own, three steps were assigned a scene the player could
  /// not build.
  String get sceneText => [narration, prompt ?? ''].join(' ').trim();

  factory LessonStep.fromJson(Map<String, dynamic> j) => LessonStep(
        narration: j['narration'] as String? ?? '',
        action: j['action'] as String? ?? '',
        feedback: j['feedback'] as String? ?? '',
        mechanic: j['mechanic'] as String?,
        prompt: j['prompt'] as String?,
        answer: (j['answer'] as num?)?.toInt(),
        choices: ((j['choices'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        figures: ((j['figures'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        choiceIndex: (j['choiceIndex'] as num?)?.toInt(),
        count: (j['count'] as num?)?.toInt(),
        rows: (j['rows'] as num?)?.toInt(),
        cols: (j['cols'] as num?)?.toInt(),
        visual: Visual.fromJson(j['visual'] as Map<String, dynamic>?),
      );
}

class LibOption {
  const LibOption({required this.label, this.asset});
  final String label;
  final String? asset;
  factory LibOption.fromJson(Map<String, dynamic> j) =>
      LibOption(label: j['label'] as String? ?? '', asset: j['asset'] as String?);
}

class LibQuestion {
  const LibQuestion({
    required this.prompt,
    required this.options,
    required this.answer,
    required this.correctFeedback,
    required this.retryFeedback,
    this.visual,
  });
  final String prompt;
  final List<LibOption> options;
  final int answer;
  final String correctFeedback;
  final String retryFeedback;
  final Visual? visual;
  factory LibQuestion.fromJson(Map<String, dynamic> j) => LibQuestion(
        prompt: j['prompt'] as String? ?? '',
        options: ((j['options'] as List?) ?? const [])
            .map((o) => LibOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        answer: j['answer'] as int? ?? 0,
        correctFeedback: j['correctFeedback'] as String? ?? '',
        retryFeedback: j['retryFeedback'] as String? ?? '',
        visual: Visual.fromJson(j['visual'] as Map<String, dynamic>?),
      );
}

class LibPage {
  const LibPage({
    required this.narration,
    this.illustration,
    this.interaction,
    this.visual,
  });
  final String narration;
  final String? illustration;
  final String? interaction;
  final Visual? visual;

  factory LibPage.fromJson(Map<String, dynamic> j) {
    final illustration = j['illustration'] as String?;
    // docs/26 §26.7: `illustration` is the existing slot field, so a page
    // without an explicit visual reads as a slot pointing at it. That is what
    // lets 594 story pages migrate without being retyped.
    final visual = Visual.fromJson(j['visual'] as Map<String, dynamic>?) ??
        (illustration != null && illustration.isNotEmpty
            ? SlotVisual(ref: illustration, alt: j['narration'] as String? ?? '')
            : null);
    return LibPage(
      narration: j['narration'] as String? ?? '',
      illustration: illustration,
      interaction: j['interaction'] as String?,
      visual: visual,
    );
  }
}
