/// Lesson body model — mirrors the `watoto.lesson/1.0` JSON schema served by
/// the API (`lessons.body`) and bundled in offline packs.
library;

class LessonBody {
  const LessonBody({
    required this.schema,
    required this.titleKey,
    required this.blocks,
    required this.completion,
  });

  final String schema;
  final String titleKey;
  final List<LessonBlock> blocks;
  final LessonCompletion completion;

  factory LessonBody.fromJson(Map<String, dynamic> json) {
    return LessonBody(
      schema: json['schema'] as String,
      titleKey: json['titleKey'] as String,
      blocks: (json['blocks'] as List<dynamic>)
          .map((b) => LessonBlock.fromJson(b as Map<String, dynamic>))
          .toList(),
      completion:
          LessonCompletion.fromJson(json['completion'] as Map<String, dynamic>),
    );
  }
}

sealed class LessonBlock {
  const LessonBlock();

  factory LessonBlock.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'concept' => ConceptBlock(
          textKey: json['textKey'] as String,
          emoji: json['emoji'] as String? ?? '⭐',
        ),
      'tap_to_count' => TapToCountBlock(items: json['items'] as int),
      'check' => CheckBlock(
          promptKey: json['promptKey'] as String,
          options: (json['options'] as List<dynamic>)
              .map((o) => CheckOption.fromJson(o as Map<String, dynamic>))
              .toList(),
        ),
      final unknown => throw FormatException('Unknown block type: $unknown'),
    };
  }
}

class ConceptBlock extends LessonBlock {
  const ConceptBlock({required this.textKey, required this.emoji});

  final String textKey;
  final String emoji;
}

class TapToCountBlock extends LessonBlock {
  const TapToCountBlock({required this.items});

  final int items;
}

class CheckBlock extends LessonBlock {
  const CheckBlock({required this.promptKey, required this.options});

  final String promptKey;
  final List<CheckOption> options;
}

class CheckOption {
  const CheckOption({required this.text, required this.correct});

  final String text;
  final bool correct;

  factory CheckOption.fromJson(Map<String, dynamic> json) =>
      CheckOption(text: json['text'] as String, correct: json['correct'] as bool);
}

class LessonCompletion {
  const LessonCompletion({
    required this.xp,
    required this.stars,
    required this.skills,
  });

  final int xp;
  final int stars;
  final List<String> skills;

  factory LessonCompletion.fromJson(Map<String, dynamic> json) {
    final rewards = json['rewards'] as Map<String, dynamic>? ?? const {};
    return LessonCompletion(
      xp: rewards['xp'] as int? ?? 0,
      stars: rewards['stars'] as int? ?? 0,
      skills: (json['skills'] as List<dynamic>? ?? const [])
          .map((s) => s as String)
          .toList(),
    );
  }
}
