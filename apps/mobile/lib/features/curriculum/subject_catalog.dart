import 'curriculum_data.dart';
import 'curriculum_models.dart';

/// A stable, age-independent subject shown on the child home. The child picks
/// the subject first, then an age; each subject holds one or more curriculum
/// topics within the chosen stage (topic names vary by stage, e.g.
/// "Language & Literacy" → "Reading & Writing" → "Reading" and "Writing").
class SubjectCategory {
  const SubjectCategory({
    required this.key,
    required this.englishLabel,
    required this.emoji,
  });

  final String key;

  /// Canonical English label — also keys [localizedSubject] for translation.
  final String englishLabel;
  final String emoji;

  /// Every topic of [stage] this subject holds, in the curriculum's order.
  ///
  /// Each topic belongs to exactly one subject ([homeSubjectKeyFor]). This used
  /// to be a keyword match that kept only the *first* hit, which left 18 of the
  /// 57 topics — Cause & Effect, Body Parts, Emotions, Health, Writing and
  /// more — with no way in from the home screen.
  List<String> topicNamesFor(CurriculumStage stage) => [
    for (final t in stage.topics)
      if (homeSubjectKeyFor(t.name) == key) t.name,
  ];

  /// Where a tap on the home tile lands: the first of [topicNamesFor], or null
  /// when this subject is not part of that stage's curriculum.
  String? topicNameFor(CurriculumStage stage) {
    final names = topicNamesFor(stage);
    return names.isEmpty ? null : names.first;
  }

  /// Every published stage (age band) whose curriculum includes this subject.
  ///
  /// Published, not every stage: this list is the age picker a child taps
  /// through on the home screen, so an unshipped stage here is a dead end.
  List<CurriculumStage> stagesAvailable() => [
    for (final s in publishedCurriculumStages)
      if (topicNamesFor(s).isNotEmpty) s,
  ];
}

/// The subjects offered on the home grid, independent of the child's age.
const subjectCatalog = <SubjectCategory>[
  SubjectCategory(key: 'literacy', englishLabel: 'Reading & Writing', emoji: '📖'),
  SubjectCategory(key: 'math', englishLabel: 'Math', emoji: '🔢'),
  SubjectCategory(key: 'science', englishLabel: 'Science', emoji: '🔬'),
  SubjectCategory(key: 'social', englishLabel: 'Social Studies', emoji: '🌍'),
  SubjectCategory(key: 'tech', englishLabel: 'Technology & Logic', emoji: '🤖'),
];

/// Which home subject holds each curriculum topic, by [SubjectCategory.key].
///
/// Explicit rather than derived from the names: the keywords it replaced
/// could match two subjects ("Math & Logic" was both Math and Technology) or
/// none ("Motor Imitation", "Emotions", "Health", "Creative Arts").
/// The less obvious homes: imitating and waving bye-bye, feelings, and
/// routines are the social learning of the youngest stages; health sits with
/// the body in science; and creative arts go with technology, which is where
/// the curriculum itself puts creativity from age 4 ("Creativity & Coding").
const _topicSubjects = <String, String>{
  // Stage 1
  'Sensory Exploration': 'science',
  'Cause & Effect': 'science',
  'Object Permanence': 'science',
  'Early Language': 'literacy',
  'Motor Imitation': 'social',
  // Stage 2
  'Animals': 'science',
  'Body Parts': 'science',
  'Colors & Shapes': 'math',
  'Simple Sorting': 'math',
  'First Numbers': 'math',
  'Music & Routines': 'social',
  // Stage 3
  'Vocabulary': 'literacy',
  'Phonological Awareness': 'literacy',
  'Counting & Numbers': 'math',
  'Patterns & Opposites': 'math',
  'Emotions': 'social',
  'Tracing & Stories': 'literacy',
  // Stage 4
  'Language & Literacy': 'literacy',
  'Math & Logic': 'math',
  'Science & Nature': 'science',
  'Social Studies': 'social',
  'Creative Arts': 'tech',
  'Social-Emotional': 'social',
  // Stages 5–10
  'Reading & Writing': 'literacy',
  'Reading': 'literacy',
  'Writing & Grammar': 'literacy',
  'Writing': 'literacy',
  'Math': 'math',
  'Science': 'science',
  'Health': 'science',
  'Creativity & Coding': 'tech',
  'Technology & Logic': 'tech',
  'Creativity & Tech': 'tech',
  'Logic & Coding': 'tech',
  'Digital Literacy & Coding': 'tech',
};

/// The [SubjectCategory.key] of the home subject holding [topicName], or null
/// for a name that is not a curriculum topic.
String? homeSubjectKeyFor(String topicName) => _topicSubjects[topicName];

/// The home subject holding [topicName], or null.
SubjectCategory? homeSubjectFor(String topicName) {
  final key = homeSubjectKeyFor(topicName);
  for (final s in subjectCatalog) {
    if (s.key == key) return s;
  }
  return null;
}

/// The subject featured as today's Daily Challenge. It rotates through the
/// catalogue by calendar day so the challenge feels fresh each morning while
/// staying stable within a single day.
SubjectCategory dailyChallengeSubjectFor(DateTime date) {
  // Counted in UTC so a daylight-saving hour cannot shift the rotation: from
  // local midnight, spring-forward leaves `inDays` one short until 01:00.
  final dayOfYear = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(date.year))
      .inDays;
  return subjectCatalog[dayOfYear % subjectCatalog.length];
}
