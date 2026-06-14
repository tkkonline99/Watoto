/// Playable content library models — the schema from
/// content/watoto_content_library.json (lessons / quizzes / stories), the gate
/// after the curriculum plan. Validated by content/validate_content.py.
library;

enum LibraryType { lesson, quiz, story }

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
    );
  }
}

class LessonStep {
  const LessonStep({required this.narration, required this.action, required this.feedback});
  final String narration;
  final String action;
  final String feedback;
  factory LessonStep.fromJson(Map<String, dynamic> j) => LessonStep(
        narration: j['narration'] as String? ?? '',
        action: j['action'] as String? ?? '',
        feedback: j['feedback'] as String? ?? '',
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
  });
  final String prompt;
  final List<LibOption> options;
  final int answer;
  final String correctFeedback;
  final String retryFeedback;
  factory LibQuestion.fromJson(Map<String, dynamic> j) => LibQuestion(
        prompt: j['prompt'] as String? ?? '',
        options: ((j['options'] as List?) ?? const [])
            .map((o) => LibOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        answer: j['answer'] as int? ?? 0,
        correctFeedback: j['correctFeedback'] as String? ?? '',
        retryFeedback: j['retryFeedback'] as String? ?? '',
      );
}

class LibPage {
  const LibPage({required this.narration, this.illustration, this.interaction});
  final String narration;
  final String? illustration;
  final String? interaction;
  factory LibPage.fromJson(Map<String, dynamic> j) => LibPage(
        narration: j['narration'] as String? ?? '',
        illustration: j['illustration'] as String?,
        interaction: j['interaction'] as String?,
      );
}
