import 'curriculum_data.dart';
import 'curriculum_models.dart';

/// A stable, age-independent subject shown on the child home. The child picks
/// the subject first, then an age; each subject resolves to the best-matching
/// curriculum topic within the chosen stage (subject names vary by stage, e.g.
/// "Reading & Writing" → "Reading" → "Language & Literacy").
class SubjectCategory {
  const SubjectCategory({
    required this.key,
    required this.englishLabel,
    required this.emoji,
    required this.keywords,
  });

  final String key;

  /// Canonical English label — also keys [localizedSubject] for translation.
  final String englishLabel;
  final String emoji;

  /// Lower-case substrings; the first stage topic that contains any of them is
  /// this subject's topic for that stage.
  final List<String> keywords;

  /// The matching curriculum topic name for [stage], or null when this subject
  /// is not part of that stage's curriculum.
  String? topicNameFor(CurriculumStage stage) {
    for (final t in stage.topics) {
      final n = t.name.toLowerCase();
      if (keywords.any(n.contains)) return t.name;
    }
    return null;
  }

  /// Every published stage (age band) whose curriculum includes this subject.
  ///
  /// Published, not every stage: this list is the age picker a child taps
  /// through on the home screen, so an unshipped stage here is a dead end.
  List<CurriculumStage> stagesAvailable() => [
    for (final s in publishedCurriculumStages)
      if (topicNameFor(s) != null) s,
  ];
}

/// The subjects offered on the home grid, independent of the child's age.
const subjectCatalog = <SubjectCategory>[
  SubjectCategory(
    key: 'literacy',
    englishLabel: 'Reading & Writing',
    emoji: '📖',
    keywords: [
      'read',
      'writ',
      'literacy',
      'language',
      'vocab',
      'phon',
      'tracing',
    ],
  ),
  SubjectCategory(
    key: 'math',
    englishLabel: 'Math',
    emoji: '🔢',
    keywords: ['math', 'number', 'count', 'sorting', 'pattern'],
  ),
  SubjectCategory(
    key: 'science',
    englishLabel: 'Science',
    emoji: '🔬',
    keywords: [
      'science',
      'nature',
      'sensory',
      'animal',
      'body',
      'object perman',
      'cause',
    ],
  ),
  SubjectCategory(
    key: 'social',
    englishLabel: 'Social Studies',
    emoji: '🌍',
    keywords: ['social stud'],
  ),
  SubjectCategory(
    key: 'tech',
    englishLabel: 'Technology & Logic',
    emoji: '🤖',
    keywords: ['tech', 'logic', 'coding', 'digital'],
  ),
];

/// The subject featured as today's Daily Challenge. It rotates through the
/// catalogue by calendar day so the challenge feels fresh each morning while
/// staying stable within a single day.
SubjectCategory dailyChallengeSubjectFor(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year)).inDays;
  return subjectCatalog[dayOfYear % subjectCatalog.length];
}
