/// Quiz body model — `watoto.quiz/1.0`, shared by the API catalog and
/// offline packs. Grading is pure and identical client/server side; the
/// server remains authoritative when attempts sync (docs/04 §4.6).
library;

class QuizBody {
  const QuizBody({
    required this.id,
    required this.schema,
    required this.titleKey,
    required this.passPct,
    required this.xpByStars,
    required this.questions,
  });

  final String id;
  final String schema;
  final String titleKey;
  final int passPct;

  /// XP for 1, 2, and 3 stars (index = stars - 1).
  final List<int> xpByStars;
  final List<QuizQuestion> questions;

  factory QuizBody.fromJson(Map<String, dynamic> json) => QuizBody(
        id: json['id'] as String,
        schema: json['schema'] as String,
        titleKey: json['titleKey'] as String,
        passPct: json['passPct'] as int? ?? 70,
        xpByStars: (json['xpByStars'] as List<dynamic>? ?? const [10, 15, 20])
            .map((x) => x as int)
            .toList(),
        questions: (json['questions'] as List<dynamic>)
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );

  /// Grades one attempt; `selected[i]` is the chosen option index for
  /// question i. Star thresholds per docs/12-gamification.md: ≥70% = 1★,
  /// ≥90% = 2★, 100% = 3★.
  QuizGrade grade(List<int> selected) {
    var correct = 0;
    for (var i = 0; i < questions.length && i < selected.length; i++) {
      final options = questions[i].options;
      final pick = selected[i];
      if (pick >= 0 && pick < options.length && options[pick].correct) {
        correct++;
      }
    }
    final total = questions.length;
    final scorePct = total == 0 ? 0 : ((correct / total) * 100).round();
    final passed = scorePct >= passPct;
    final stars = scorePct >= 100
        ? 3
        : scorePct >= 90
            ? 2
            : passed
                ? 1
                : 0;
    return QuizGrade(
      correct: correct,
      total: total,
      scorePct: scorePct,
      passed: passed,
      stars: stars,
      xp: passed ? xpByStars[stars - 1] : 0,
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.promptKey,
    required this.emoji,
    required this.count,
    required this.options,
  });

  final String id;
  final String promptKey;

  /// Visual stimulus: [emoji] repeated [count] times.
  final String emoji;
  final int count;
  final List<QuizOption> options;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: json['id'] as String,
        promptKey: json['promptKey'] as String,
        emoji: json['emoji'] as String? ?? '⭐',
        count: json['count'] as int? ?? 1,
        options: (json['options'] as List<dynamic>)
            .map((o) => QuizOption.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

class QuizOption {
  const QuizOption({required this.text, required this.correct});

  final String text;
  final bool correct;

  factory QuizOption.fromJson(Map<String, dynamic> json) =>
      QuizOption(text: json['text'] as String, correct: json['correct'] as bool);
}

class QuizGrade {
  const QuizGrade({
    required this.correct,
    required this.total,
    required this.scorePct,
    required this.passed,
    required this.stars,
    required this.xp,
  });

  final int correct;
  final int total;
  final int scorePct;
  final bool passed;
  final int stars;
  final int xp;
}
