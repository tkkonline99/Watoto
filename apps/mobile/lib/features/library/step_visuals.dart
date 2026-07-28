/// Picks the picture a child sees on a lesson step — never a shrug.
///
/// Resolution runs narrowest → widest so the illustration is about *this step*
/// where possible, and still concrete when the step is abstract:
///
///  1. a lexicon word in the narration ("Tap the ball" → ⚽);
///  2. a topic keyword in the narration ("A VERB is an action" → 🏃);
///  3. a topic keyword in the item's title ("Sink or Float?" → 🪣);
///  4. the item's subject ("Social Studies" → 🌍).
///
/// Step 4 is a total map over every subject in the content library, so the old
/// meaningless ⭐ catch-all cannot be reached. [subjectEmoji] falls back to the
/// keyword rules and finally 📚 (a book — still a learning cue) for a subject
/// added later without a mapping here; [assertEverySubjectMapped] in the tests
/// keeps that from going unnoticed.
library;

import 'content_lexicon.dart';
import 'library_models.dart';

/// Every subject in `watoto_content_library.json`, mapped to a concrete image.
/// Keep in sync with the corpus — the coverage test fails if a subject appears
/// in content without an entry here.
const Map<String, String> subjectEmojis = {
  'Animals': '🐘',
  'Body Parts': '🖐️',
  'Cause & Effect': '🔔',
  'Colors & Shapes': '🔵',
  'Counting & Numbers': '🔢',
  'Creative Arts': '🎨',
  'Creativity & Coding': '🤖',
  'Creativity & Tech': '🤖',
  'Digital Literacy & Coding': '💻',
  'Early Language': '💬',
  'Emotions': '😊',
  'First Numbers': '1️⃣',
  'Health': '🍎',
  'Language & Literacy': '🔤',
  'Logic & Coding': '🧩',
  'Math': '🔢',
  'Math & Logic': '🔢',
  'Motor Imitation': '🙌',
  'Music & Routines': '🎵',
  'Object Permanence': '🫣',
  'Patterns & Opposites': '🔁',
  'Phonological Awareness': '👂',
  'Reading': '📖',
  'Reading & Writing': '📖',
  'Science': '🔬',
  'Science & Nature': '🌱',
  'Sensory Exploration': '🌀',
  'Simple Sorting': '🧺',
  'Social Studies': '🌍',
  'Social-Emotional': '❤️',
  'Technology & Logic': '💻',
  'Tracing & Stories': '✏️',
  'Vocabulary': '🗣️',
  'Writing': '✏️',
  'Writing & Grammar': '✏️',
};

/// Topic cues for steps whose narration names no concrete object — grammar,
/// arithmetic, civics. Ordered: the first match wins, so put the specific
/// cues above the general ones.
const _topicRules = <(List<String>, String)>[
  // Language / grammar
  (['verb', 'action word'], '🏃'),
  (['adjective', 'describ'], '🌈'),
  (['noun', 'naming word'], '🏷️'),
  (['rhyme', 'rhyming', 'same way', 'sounds the same'], '🎶'),
  (['syllab', 'clap the word'], '👏'),
  (['capital', 'lowercase', 'little a', 'little b', 'little c'], '🔠'),
  (['letter', 'alphabet', 'a-b-c', 'abc'], '🔤'),
  (['spell', 'sound out', 'blend', 'c-a-t', 'm-a-p'], '🔤'),
  (['sentence', 'full stop', 'question mark', 'comma'], '📝'),
  (['story', 'once upon'], '📖'),
  (['please', 'thank you', 'sorry', 'polite'], '🙏'),
  // Making things — before the maths rules, so "Draw two eyes and a nose.
  // Tap to add them." is a drawing step, not an addition step.
  (['draw', 'paint', 'colour in', 'color in', 'scribble'], '🎨'),
  // Math. 'add'/'more' on their own are instruction language ("tap to add
  // them", "one more time"), so require arithmetic wording.
  (['×', 'times', 'multiply', 'array', 'rows of'], '✖️'),
  (['÷', 'divide', 'division', 'share equally'], '➗'),
  (['take away', 'subtract', 'minus', 'fewer'], '➖'),
  (['plus', 'altogether', 'add up', 'and 1 more', 'sum'], '➕'),
  (['number line', 'hop forward', 'hop backward'], '📏'),
  (['half', 'fraction', 'quarter'], '🍕'),
  (['how many', 'count'], '🔢'),
  (['pattern', 'comes next', 'keep the pattern'], '🔁'),
  (['order', 'first', 'next', 'last', 'sequence'], '🔢'),
  (['sort', 'match', 'matching', 'same', 'pair'], '🧺'),
  (['big', 'small', 'short', 'tall', 'size', 'long'], '📐'),
  // Science
  (['circuit', 'battery', 'wire', 'bulb', 'electric'], '🔋'),
  (['sink', 'float'], '🪣'),
  (['push', 'pull', 'force', 'move'], '🛒'),
  (['grow', 'seed', 'plant', 'sprout'], '🌱'),
  (['weather', 'rain', 'sun', 'cloud'], '⛅'),
  (['caterpillar', 'chrysalis', 'butterfly', 'life cycle'], '🦋'),
  (['float', 'balloon', 'air', 'blow'], '🎈'),
  // Social studies
  (['pyramid', 'ancient', 'long ago', 'history'], '🏛️'),
  (['map', 'country', 'flag', 'world', 'globe'], '🗺️'),
  (['turn', 'share', 'fair', 'rule', 'help'], '🤝'),
  (['family', 'neighbour', 'neighbor', 'community'], '🏘️'),
  (['market', 'money', 'buy', 'sell', 'trade'], '🪙'),
  // Body / feelings / routine
  (['breathe', 'calm', 'relax'], '🌬️'),
  (['clap', 'stomp', 'dance', 'wiggle', 'stretch'], '👏'),
  (['wave', 'bye-bye', 'hello'], '👋'),
  (['sleep', 'pajama', 'bedtime', 'snuggle'], '🌙'),
  (['wash', 'brush', 'teeth', 'clean'], '🪥'),
  (['happy', 'sad', 'angry', 'feel', 'emotion'], '😊'),
  // Sensory / cause & effect
  (['swirl', 'spiral', 'contrast', 'pattern of light'], '🌀'),
  (['bubble', 'bubbly', 'pop'], '🫧'),
  (['shake', 'rattle', 'noise'], '🔔'),
  (['peek', 'hide', 'hidden', 'inside', 'other side'], '🫣'),
  (['touch', 'soft', 'rough', 'smooth', 'feel it'], '🖐️'),
  // Tech. Deliberately no 'screen': "swipe across the screen" is device
  // chrome in the narration, not what the step is teaching.
  (['code', 'robot', 'program', 'loop', 'command'], '🤖'),
  (['tablet', 'computer', 'mouse', 'keyboard'], '💻'),
];

String? _topicEmoji(String text) {
  final s = text.toLowerCase();
  for (final (keys, emoji) in _topicRules) {
    if (keys.any(s.contains)) return emoji;
  }
  return null;
}

/// Subject → picture, with keyword and final-resort fallbacks so this is total.
String subjectEmoji(String subject) {
  final exact = subjectEmojis[subject];
  if (exact != null) return exact;
  return _topicEmoji(subject) ?? '📚';
}

/// The picture for one lesson step. Never returns an empty or placeholder
/// glyph: a child always sees something that belongs to what they are doing.
String stepIllustration({
  required LibraryItem item,
  required String narration,
}) {
  final word = lexiconEntryFor(narration);
  // A bare numeral is a weak picture when the step is about something else
  // ("Draw two eyes and a nose" is about drawing, not about 2), so let a topic
  // cue outrank it. Digits still win when nothing else describes the step.
  if (word != null && word.category != lexDigitCategory) return word.emoji;
  return _topicEmoji(narration) ??
      word?.emoji ??
      _topicEmoji(item.title) ??
      subjectEmoji(item.subject);
}

/// Item-level picture (celebration screens, subject tiles) — same ladder
/// without a step to look at.
String itemIllustration(LibraryItem item) =>
    _topicEmoji(item.title) ?? subjectEmoji(item.subject);
