/// Curriculum model — the 10-stage, birth-to-age-10 map from the product
/// curriculum deck (OneDrive/Watoto App/curriculum.pptx). Each stage covers a
/// one-year age span with subject topics and concrete example activities.
library;

class CurriculumStage {
  const CurriculumStage({
    required this.stage,
    required this.minAge,
    required this.maxAge,
    required this.ageRange,
    required this.band,
    this.grade,
    required this.title,
    required this.theme,
    required this.designTip,
    required this.topics,
  });

  final int stage; // 1..10
  final int minAge; // inclusive, years
  final int maxAge; // exclusive upper bound used for mapping
  final String ageRange; // e.g. "0–1"
  final String band; // "Babies & Toddlers" | "Preschool" | "Early Elementary" | "Upper Elementary"
  final String? grade; // "Kindergarten", "Grade 1", … (null for the youngest stages)
  final String title;
  final String theme;
  final String designTip;
  final List<CurriculumTopic> topics;
}

class CurriculumTopic {
  const CurriculumTopic({required this.name, required this.activities});

  final String name;
  final List<String> activities;

  /// Emoji icon chosen from the topic name so the UI needs no image assets.
  String get emoji => _iconForTopic(name);
}

String _iconForTopic(String name) {
  final n = name.toLowerCase();
  bool has(String s) => n.contains(s);
  if (has('read')) return '📖';
  if (has('writ') || has('grammar') || has('tracing')) return '✍️';
  if (has('math') || has('number') || has('count')) return '🔢';
  if (has('coding') || has('tech') || has('logic') || has('digital')) return '🤖';
  if (has('science') || has('nature')) return '🔬';
  if (has('social stud')) return '🌍';
  if (has('health')) return '❤️';
  if (has('art') || has('creativ') || has('music') || has('routine')) return '🎨';
  if (has('animal')) return '🐘';
  if (has('body')) return '🧒';
  if (has('color') || has('shape')) return '🔷';
  if (has('sort')) return '🧩';
  if (has('sensory')) return '✨';
  if (has('cause')) return '💡';
  if (has('object perman')) return '🔍';
  if (has('language') || has('vocab') || has('word') || has('phon')) return '🗣️';
  if (has('motor')) return '👏';
  if (has('pattern') || has('opposite')) return '🔁';
  if (has('emotion')) return '😊';
  if (has('stor')) return '📚';
  return '⭐';
}
