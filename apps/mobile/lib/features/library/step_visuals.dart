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

/// Cues that a plain substring cannot express.
///
/// Arithmetic is the main reason these exist: the content writes sums as
/// "6 + 3 = 9" and "15 - 6", so the word-based rules above never fired and
/// nearly every calculation step fell through to the generic subject picture.
/// A bare '-' cannot be matched as a substring either — "bye-bye" and "ma-ma"
/// are not subtraction. Checked before the word rules, because they are the
/// more specific statement about what the step is doing.
final _topicPatterns = <(RegExp, String)>[
  // Arithmetic written as symbols.
  (RegExp(r'\d\s*\+\s*\d'), '➕'),
  (RegExp(r'\d\s*[-−]\s*\d'), '➖'),
  (RegExp(r'\d\s*[×x*]\s*\d'), '✖️'),
  (RegExp(r'\d\s*[÷/]\s*\d'), '➗'),
  // Arithmetic written as words.
  (RegExp(r'\d+\s+and\s+\d+\s+make'), '➕'),
  (RegExp(r'count on|and \d+ more|\d+ more\.'), '➕'),
  (RegExp(r'count back|take \d+ away'), '➖'),
  (RegExp(r'count by \d|count in \d'), '🔢'),
  (RegExp(r'\bmake \d+'), '🔢'),
  // Place value and rounding.
  (RegExp(r'nearest (10|100|1000|ten|hundred|thousand)|round \d'), '🎯'),
  (RegExp(r'\b(ones|tens|hundreds|thousands)\b|place value'), '🧮'),
  (RegExp(r'\btenths?\b|\bhundredths?\b|\d\.\d'), '🍕'),
  // Reading comprehension vocabulary.
  (RegExp(r'\bheading\b|\bsection\b|\bcaption\b'), '📰'),
  (RegExp(r'\binfer|smart guess|from evidence|figure it out'), '🔍'),
  (RegExp(r'\btheme\b|character learn|lesson of the story'), '💭'),
  (RegExp(r'\bretell|\bsummar'), '🗣️'),
  (RegExp(r'\bauthors?\b|\bwriters?\b'), '✍️'),
  (RegExp(r'\bprefix\b|\bsuffix\b|root word|.re. means'), '🔤'),
  // Writing craft.
  (RegExp(r'apostrophe|contraction|\w+n.t\b'), '✂️'),
  (RegExp(r'\bedit\b|reread|revise|improve their work'), '📝'),
  (RegExp(r'new person speaks|dialogue|quotation|speech marks'), '💬'),
  // Civics and money.
  (RegExp(r'\brights?\b|\bfreedom|\bcitizen'), '⚖️'),
  (RegExp(r'\bbudget\b|spend and save|\bsave\b'), '🪙'),
  (RegExp(r'timeline|happened later|further right|\border of events'), '📅'),
  // Science.
  (RegExp(r'\bdesert\b|\bhabitat\b|lives in the'), '🏜️'),
  (RegExp(r'food (web|chain)|ecosystem|whole web'), '🕸️'),
  // Digital literacy — trust and code alike.
  (RegExp(r'website|online|who wrote it|backed up'), '🌐'),
  (RegExp(r'variable|\bprint\b|holds \d|true or false'), '🤖'),
  // Letters and phonics written as quoted fragments ("'ch' says ch").
  (RegExp("'[a-z]{1,3}' says|tap '[a-z]+'|keep going to z"), '🔤'),
  // Tracing praise lines name the shape that was traced, not the skill.
  (RegExp(r'zigzag|stayed on the (road|line|path)|followed the'), '✏️'),
];

String? _topicEmoji(String text) {
  final s = text.toLowerCase();
  for (final (pattern, emoji) in _topicPatterns) {
    if (pattern.hasMatch(s)) return emoji;
  }
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

/// Which rung of the ladder produced a step's picture.
///
/// Exposed so coverage can be measured honestly: an emoji chosen by the
/// subject fallback and one chosen by a word in the narration can be the same
/// glyph, and counting them together hides how much art is actually generic.
enum IllustrationTier {
  /// The author said what the stage shows (docs/26 §26.3). Outranks every
  /// guess below it — that is the entire point of the visual contract.
  declared,

  /// A concrete word in the narration ("Tap the ball" → ⚽).
  lexicon,

  /// A topic cue in the narration ("A VERB is an action" → 🏃).
  topic,

  /// A topic cue in the item's title, when the step itself is abstract.
  title,

  /// Nothing specific matched; the subject's own picture stands in.
  subject,
}

/// The picture for one lesson step, with the rung it came from.
({String emoji, IllustrationTier tier}) stepIllustrationDetail({
  required LibraryItem item,
  required String narration,
  Visual? visual,
}) {
  // A declared token names the glyph outright. Token ids are lexicon keys by
  // construction — visual_tokens.json is generated from the same map — so this
  // lookup cannot disagree with the registry the validator enforces.
  if (visual is TokenVisual) {
    final declared = lexiconLookup(visual.ref);
    if (declared != null) {
      return (emoji: declared.emoji, tier: IllustrationTier.declared);
    }
  }

  final word = lexiconEntryFor(narration);
  // A bare numeral is a weak picture when the step is about something else
  // ("Draw two eyes and a nose" is about drawing, not about 2), so let a topic
  // cue outrank it. Digits still win when nothing else describes the step.
  if (word != null && word.category != lexDigitCategory) {
    return (emoji: word.emoji, tier: IllustrationTier.lexicon);
  }
  final topic = _topicEmoji(narration);
  if (topic != null) return (emoji: topic, tier: IllustrationTier.topic);
  if (word != null) {
    return (emoji: word.emoji, tier: IllustrationTier.lexicon);
  }
  final fromTitle = _topicEmoji(item.title);
  if (fromTitle != null) {
    return (emoji: fromTitle, tier: IllustrationTier.title);
  }
  return (emoji: subjectEmoji(item.subject), tier: IllustrationTier.subject);
}

/// The picture for one lesson step. Never returns an empty or placeholder
/// glyph: a child always sees something that belongs to what they are doing.
String stepIllustration({
  required LibraryItem item,
  required String narration,
  Visual? visual,
}) =>
    stepIllustrationDetail(item: item, narration: narration, visual: visual)
        .emoji;

/// Item-level picture (celebration screens, subject tiles) — same ladder
/// without a step to look at.
String itemIllustration(LibraryItem item) =>
    _topicEmoji(item.title) ?? subjectEmoji(item.subject);
