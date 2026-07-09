/// Turns lesson narration into concrete visuals: a word→emoji lexicon built
/// from an analysis of all 747 lesson steps in the content library, plus the
/// planners the player uses to stage each step.
///
/// Two tiers:
///  - directive steps ("Tap the ball…") become a real multiple-choice stage:
///    the named object plus look-alike distractors from the same category;
///  - other steps that mention a known word get that word's illustration
///    instead of a generic subject icon.
///
/// Scanning always runs on the English source narration (the content file's
/// authoring language); emoji are language-neutral, so the same stage works
/// under the FR/SW overlays.
library;

class LexEntry {
  const LexEntry(this.emoji, this.category, {this.choice = true});

  final String emoji;
  final String category;

  /// Whether this word can be a multiple-choice target. Concepts and actions
  /// ("letter", "clap") illustrate a step but are not tappable answers.
  final bool choice;
}

const _animal = 'animal';
const _food = 'food';
const _object = 'object';
const _nature = 'nature';
const _people = 'people';
const _color = 'color';
const _shape = 'shape';
const _digit = 'digit';
const _concept = 'concept';

const Map<String, LexEntry> lexicon = {
  // Animals
  'dog': LexEntry('🐶', _animal), 'puppy': LexEntry('🐶', _animal),
  'cat': LexEntry('🐱', _animal), 'kitten': LexEntry('🐱', _animal),
  'fish': LexEntry('🐟', _animal), 'bird': LexEntry('🐦', _animal),
  'duck': LexEntry('🦆', _animal), 'rabbit': LexEntry('🐰', _animal),
  'bunny': LexEntry('🐰', _animal), 'bear': LexEntry('🐻', _animal),
  'lion': LexEntry('🦁', _animal), 'elephant': LexEntry('🐘', _animal),
  'cow': LexEntry('🐮', _animal), 'horse': LexEntry('🐴', _animal),
  'pig': LexEntry('🐷', _animal), 'sheep': LexEntry('🐑', _animal),
  'goat': LexEntry('🐐', _animal), 'chicken': LexEntry('🐔', _animal),
  'frog': LexEntry('🐸', _animal), 'bee': LexEntry('🐝', _animal),
  'butterfly': LexEntry('🦋', _animal), 'snake': LexEntry('🐍', _animal),
  'monkey': LexEntry('🐵', _animal), 'mouse': LexEntry('🐭', _animal),
  'turtle': LexEntry('🐢', _animal), 'bug': LexEntry('🐛', _animal),
  'ant': LexEntry('🐜', _animal), 'spider': LexEntry('🕷️', _animal),
  'crab': LexEntry('🦀', _animal), 'whale': LexEntry('🐋', _animal),
  'shark': LexEntry('🦈', _animal), 'octopus': LexEntry('🐙', _animal),
  'giraffe': LexEntry('🦒', _animal), 'zebra': LexEntry('🦓', _animal),
  'penguin': LexEntry('🐧', _animal), 'owl': LexEntry('🦉', _animal),
  'fox': LexEntry('🦊', _animal), 'deer': LexEntry('🦌', _animal),
  'wolf': LexEntry('🐺', _animal), 'tiger': LexEntry('🐯', _animal),
  'hippo': LexEntry('🦛', _animal), 'snail': LexEntry('🐌', _animal),
  'worm': LexEntry('🪱', _animal), 'kangaroo': LexEntry('🦘', _animal),
  // Food
  'apple': LexEntry('🍎', _food), 'apples': LexEntry('🍎', _food),
  'banana': LexEntry('🍌', _food), 'mango': LexEntry('🥭', _food),
  'bread': LexEntry('🍞', _food), 'egg': LexEntry('🥚', _food),
  'milk': LexEntry('🥛', _food), 'cake': LexEntry('🍰', _food),
  'cookie': LexEntry('🍪', _food), 'pizza': LexEntry('🍕', _food),
  'carrot': LexEntry('🥕', _food), 'corn': LexEntry('🌽', _food),
  // Objects & vehicles
  'ball': LexEntry('⚽', _object), 'balloon': LexEntry('🎈', _object),
  'box': LexEntry('📦', _object), 'cup': LexEntry('🥤', _object),
  'spoon': LexEntry('🥄', _object), 'book': LexEntry('📖', _object),
  'books': LexEntry('📚', _object), 'pencil': LexEntry('✏️', _object),
  'crayon': LexEntry('🖍️', _object), 'drum': LexEntry('🥁', _object),
  'bell': LexEntry('🔔', _object), 'hat': LexEntry('🎩', _object),
  'shoe': LexEntry('👟', _object), 'shirt': LexEntry('👕', _object),
  'sock': LexEntry('🧦', _object), 'robot': LexEntry('🤖', _object),
  'computer': LexEntry('💻', _object), 'phone': LexEntry('📱', _object),
  'clock': LexEntry('🕐', _object), 'key': LexEntry('🔑', _object),
  'door': LexEntry('🚪', _object), 'bed': LexEntry('🛏️', _object),
  'chair': LexEntry('🪑', _object), 'toy': LexEntry('🧸', _object),
  'doll': LexEntry('🧸', _object), 'block': LexEntry('🧱', _object),
  'blocks': LexEntry('🧱', _object), 'rattle': LexEntry('🪇', _object),
  'kite': LexEntry('🪁', _object), 'umbrella': LexEntry('☂️', _object),
  'magnet': LexEntry('🧲', _object), 'coin': LexEntry('🪙', _object),
  'coins': LexEntry('🪙', _object), 'flag': LexEntry('🚩', _object),
  'map': LexEntry('🗺️', _object), 'car': LexEntry('🚗', _object),
  'bus': LexEntry('🚌', _object), 'train': LexEntry('🚆', _object),
  'boat': LexEntry('⛵', _object), 'plane': LexEntry('✈️', _object),
  'bike': LexEntry('🚲', _object), 'wheel': LexEntry('🛞', _object),
  'bubble': LexEntry('🫧', _object), 'bubbles': LexEntry('🫧', _object),
  'cube': LexEntry('🎲', _object), 'curtains': LexEntry('🪟', _object),
  'puzzle': LexEntry('🧩', _object), 'hug': LexEntry('🤗', _people),
  // Nature
  'sun': LexEntry('☀️', _nature), 'moon': LexEntry('🌙', _nature),
  'star': LexEntry('⭐', _nature), 'stars': LexEntry('⭐', _nature),
  'tree': LexEntry('🌳', _nature), 'flower': LexEntry('🌸', _nature),
  'grass': LexEntry('🌿', _nature), 'leaf': LexEntry('🍃', _nature),
  'rain': LexEntry('🌧️', _nature), 'cloud': LexEntry('☁️', _nature),
  'snow': LexEntry('❄️', _nature), 'ice': LexEntry('🧊', _nature),
  'water': LexEntry('💧', _nature), 'fire': LexEntry('🔥', _nature),
  'rock': LexEntry('🪨', _nature), 'mountain': LexEntry('⛰️', _nature),
  'river': LexEntry('🏞️', _nature), 'ocean': LexEntry('🌊', _nature),
  'earth': LexEntry('🌍', _nature), 'plant': LexEntry('🪴', _nature),
  'seed': LexEntry('🌱', _nature), 'rainbow': LexEntry('🌈', _nature),
  'sky': LexEntry('🌌', _nature), 'night': LexEntry('🌃', _nature),
  'shell': LexEntry('🐚', _nature),
  // Places & people
  'house': LexEntry('🏠', _object), 'home': LexEntry('🏠', _object),
  'school': LexEntry('🏫', _object), 'farm': LexEntry('🚜', _object),
  'garden': LexEntry('🌷', _nature), 'jungle': LexEntry('🌴', _nature),
  'beach': LexEntry('🏖️', _nature), 'zoo': LexEntry('🦓', _object),
  'store': LexEntry('🏪', _object), 'street': LexEntry('🛣️', _object),
  'doctor': LexEntry('🧑‍⚕️', _people),
  'firefighter': LexEntry('🧑‍🚒', _people),
  'teacher': LexEntry('🧑‍🏫', _people), 'farmer': LexEntry('🧑‍🌾', _people),
  'baby': LexEntry('👶', _people), 'family': LexEntry('👨‍👩‍👧', _people),
  'friend': LexEntry('🧒', _people), 'friends': LexEntry('🧒', _people),
  'mom': LexEntry('👩', _people), 'mama': LexEntry('👩', _people),
  'dad': LexEntry('👨', _people), 'dada': LexEntry('👨', _people),
  'grown': LexEntry('🧑', _people),
  // Faces & body
  'face': LexEntry('😊', _people, choice: false),
  'happy': LexEntry('😊', _people), 'smiling': LexEntry('😊', _people),
  'sad': LexEntry('😢', _people), 'angry': LexEntry('😠', _people),
  'eyes': LexEntry('👀', _people), 'eye': LexEntry('👁️', _people),
  'nose': LexEntry('👃', _people), 'mouth': LexEntry('👄', _people),
  'ear': LexEntry('👂', _people), 'hand': LexEntry('✋', _people),
  'hands': LexEntry('👐', _people), 'foot': LexEntry('🦶', _people),
  'heart': LexEntry('❤️', _shape), 'teeth': LexEntry('🦷', _people),
  // Colors (choice pool of coloured dots)
  'red': LexEntry('🔴', _color), 'blue': LexEntry('🔵', _color),
  'yellow': LexEntry('🟡', _color), 'green': LexEntry('🟢', _color),
  'orange': LexEntry('🟠', _color), 'purple': LexEntry('🟣', _color),
  // Shapes
  'circle': LexEntry('⭕', _shape), 'square': LexEntry('🟦', _shape),
  'triangle': LexEntry('🔺', _shape), 'diamond': LexEntry('🔶', _shape),
  // Numbers (choice-eligible but never preferred over an object — see planner)
  'two': LexEntry('2️⃣', _digit), 'three': LexEntry('3️⃣', _digit),
  'four': LexEntry('4️⃣', _digit), 'five': LexEntry('5️⃣', _digit),
  'six': LexEntry('6️⃣', _digit), 'seven': LexEntry('7️⃣', _digit),
  'eight': LexEntry('8️⃣', _digit), 'nine': LexEntry('9️⃣', _digit),
  'ten': LexEntry('🔟', _digit),
  // Actions & concepts — illustrate, never a tappable answer
  'clap': LexEntry('👏', _concept, choice: false),
  'claps': LexEntry('👏', _concept, choice: false),
  'clapping': LexEntry('👏', _concept, choice: false),
  'wave': LexEntry('👋', _concept, choice: false),
  'stomp': LexEntry('🦶', _concept, choice: false),
  'jump': LexEntry('🤸', _concept, choice: false),
  'run': LexEntry('🏃', _concept, choice: false),
  'walk': LexEntry('🚶', _concept, choice: false),
  'sing': LexEntry('🎤', _concept, choice: false),
  'song': LexEntry('🎵', _concept, choice: false),
  'music': LexEntry('🎵', _concept, choice: false),
  'dance': LexEntry('💃', _concept, choice: false),
  'sleep': LexEntry('😴', _concept, choice: false),
  'bath': LexEntry('🛁', _concept, choice: false),
  'wash': LexEntry('🧼', _concept, choice: false),
  'brush': LexEntry('🪥', _concept, choice: false),
  'peekaboo': LexEntry('🙈', _concept, choice: false),
  'hide': LexEntry('🙈', _concept, choice: false),
  'hidden': LexEntry('🙈', _concept, choice: false),
  'swirl': LexEntry('🌀', _concept, choice: false),
  'swirls': LexEntry('🌀', _concept, choice: false),
  'light': LexEntry('💡', _concept, choice: false),
  'hot': LexEntry('🔥', _concept, choice: false),
  'cold': LexEntry('🧊', _concept, choice: false),
  // Literacy concepts
  'letter': LexEntry('🔤', _concept, choice: false),
  'word': LexEntry('🔡', _concept, choice: false),
  'sentence': LexEntry('📝', _concept, choice: false),
  'story': LexEntry('📖', _concept, choice: false),
  'stories': LexEntry('📖', _concept, choice: false),
  'writing': LexEntry('✍️', _concept, choice: false),
  'write': LexEntry('✍️', _concept, choice: false),
  'idea': LexEntry('💡', _concept, choice: false),
  'summary': LexEntry('📋', _concept, choice: false),
  'quotation': LexEntry('💬', _concept, choice: false),
  'paragraph': LexEntry('📄', _concept, choice: false),
  'read': LexEntry('📖', _concept, choice: false),
  'reading': LexEntry('📖', _concept, choice: false),
  'clue': LexEntry('🔍', _concept, choice: false),
  'sound': LexEntry('🔊', _concept, choice: false),
  // Math concepts
  'number': LexEntry('🔢', _concept, choice: false),
  'add': LexEntry('➕', _concept, choice: false),
  'plus': LexEntry('➕', _concept, choice: false),
  'subtract': LexEntry('➖', _concept, choice: false),
  'minus': LexEntry('➖', _concept, choice: false),
  'multiply': LexEntry('✖️', _concept, choice: false),
  'divide': LexEntry('➗', _concept, choice: false),
  'equal': LexEntry('🟰', _concept, choice: false),
  'tens': LexEntry('🔟', _concept, choice: false),
  'dot': LexEntry('⚫', _concept, choice: false),
  'half': LexEntry('🌓', _concept, choice: false),
  'halves': LexEntry('🌓', _concept, choice: false),
  // Comparatives
  'big': LexEntry('🐘', _concept, choice: false),
  'bigger': LexEntry('🐘', _concept, choice: false),
  'small': LexEntry('🐭', _concept, choice: false),
  'smaller': LexEntry('🐭', _concept, choice: false),
  'tall': LexEntry('🦒', _concept, choice: false),
  'fast': LexEntry('🏎️', _concept, choice: false),
  'slow': LexEntry('🐢', _concept, choice: false),
  // Civics & community
  'law': LexEntry('⚖️', _concept, choice: false),
  'laws': LexEntry('⚖️', _concept, choice: false),
  'vote': LexEntry('🗳️', _concept, choice: false),
  'government': LexEntry('🏛️', _concept, choice: false),
  'community': LexEntry('🏘️', _concept, choice: false),
  'money': LexEntry('💰', _concept, choice: false),
  // More actions & misc
  'paint': LexEntry('🎨', _concept, choice: false),
  'color': LexEntry('🎨', _concept, choice: false),
  'draw': LexEntry('🖍️', _concept, choice: false),
  'trace': LexEntry('✏️', _concept, choice: false),
  'breath': LexEntry('🧘', _concept, choice: false),
  'breathe': LexEntry('🧘', _concept, choice: false),
  'morning': LexEntry('🌅', _concept, choice: false),
  'steam': LexEntry('♨️', _concept, choice: false),
  'kind': LexEntry('💗', _concept, choice: false),
  'message': LexEntry('💬', _concept, choice: false),
  'shake': LexEntry('🪇', _concept, choice: false),
};

/// Lexicon lookup with a simple plural fallback ("bears" → "bear").
LexEntry? lexiconLookup(String word) {
  final e = lexicon[word];
  if (e != null) return e;
  if (word.length > 3 && word.endsWith('s')) {
    return lexicon[word.substring(0, word.length - 1)];
  }
  return null;
}

final _wordSplit = RegExp(r'[^a-z]+');
final _directive = RegExp(
  r'\b(?:tap|touch|find|point to|pick|press|choose)\b([^.!?]*)',
  caseSensitive: false,
);

List<String> _words(String text) =>
    text.toLowerCase().split(_wordSplit).where((w) => w.isNotEmpty).toList();

/// Emoji for the first lexicon word mentioned in [text], or null. Concrete
/// words win over concepts ("Read the word cat" illustrates the cat, not
/// reading), so the picture matches what the step is actually about.
String? illustrationFor(String text) {
  String? concept;
  for (final w in _words(text)) {
    final e = lexiconLookup(w);
    if (e == null) continue;
    if (e.category != _concept) return e.emoji;
    concept ??= e.emoji;
  }
  return concept;
}

/// One tappable answer in a choice stage.
class ChoiceOption {
  const ChoiceOption(this.word, this.emoji);
  final String word;
  final String emoji;
}

/// A staged multiple-choice question: tap [options][targetIndex] to advance.
class ChoicePlan {
  const ChoicePlan(this.options, this.targetIndex);
  final List<ChoiceOption> options;
  final int targetIndex;
}

/// Stable hash so a step's distractors don't change between visits.
int _seed(String itemId, int step) {
  var h = step + 1;
  for (final c in itemId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

int _next(int s) => (s * 1103515245 + 12345) & 0x7fffffff;

/// Plans a multiple-choice stage for a directive step ("Tap the ball…"),
/// or null when the step names nothing tappable. The target is the first
/// choice-eligible word after the directive verb (objects beat digits, so
/// "tap the two dogs" targets the dog); distractors come from the same
/// category so the choice is a fair look-alike question.
ChoicePlan? choicePlanFor(String itemId, int step, String narration) {
  final clause = _directive.firstMatch(narration)?.group(1);
  if (clause == null) return null;

  // "Tap the letter A" — stage the letter against two other letters.
  final lm = RegExp(r'letter ([a-z])\b').firstMatch(clause.toLowerCase());
  if (lm != null) {
    return _symbolPlan(
      itemId,
      step,
      target: lm.group(1)!.toUpperCase(),
      pool: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''),
      wordFor: (s) => 'letter $s',
    );
  }

  // "Tap 'cap'" — reading steps quote the word itself: stage it as tappable
  // TEXT against minimal-pair distractors (the other quoted words in the
  // step, then silent-e / vowel-swap mutations — 'cap' vs 'cape' vs 'cop').
  // A directive with only a pronoun ("This word is 'the'. Tap it.") falls
  // back to the word quoted elsewhere in the narration.
  final quoted =
      RegExp(r"'([A-Za-z]+)'").firstMatch(clause) ??
      (_isTrivialClause(clause)
          ? RegExp(r"'([A-Za-z]+)'").firstMatch(narration)
          : null);
  if (quoted != null) {
    final word = quoted.group(1)!.toLowerCase();
    return _wordPlan(itemId, step, word, narration);
  }

  String? target;
  String? digitFallback;
  for (final w in _words(clause)) {
    final e = lexiconLookup(w);
    if (e == null || !e.choice) continue;
    if (e.category == _digit) {
      digitFallback ??= w;
    } else {
      target = w;
      break;
    }
  }
  target ??= digitFallback;

  if (target == null) {
    // "Tap the number 3" — stage the numeral against two other numerals.
    final nm = RegExp(r'\b(10|[1-9])\b').firstMatch(clause);
    if (nm != null) {
      const keycaps = [
        '1️⃣',
        '2️⃣',
        '3️⃣',
        '4️⃣',
        '5️⃣',
        '6️⃣',
        '7️⃣',
        '8️⃣',
        '9️⃣',
        '🔟',
      ];
      final n = int.parse(nm.group(1)!);
      return _symbolPlan(
        itemId,
        step,
        target: keycaps[n - 1],
        pool: keycaps,
        wordFor: (s) => 'number ${keycaps.indexOf(s) + 1}',
      );
    }
    return null;
  }

  final targetEntry = lexiconLookup(target)!;
  // Same-category pool, deduped by emoji, excluding the target's emoji.
  final seen = <String>{targetEntry.emoji};
  final pool = <ChoiceOption>[];
  for (final w in lexicon.keys.toList()..sort()) {
    final e = lexicon[w]!;
    if (e.category == targetEntry.category && e.choice && seen.add(e.emoji)) {
      pool.add(ChoiceOption(w, e.emoji));
    }
  }
  if (pool.length < 2) return null;

  var s = _seed(itemId, step);
  final distractors = <ChoiceOption>[];
  while (distractors.length < 2 && pool.isNotEmpty) {
    s = _next(s);
    distractors.add(pool.removeAt(s % pool.length));
  }

  s = _next(s);
  final targetIndex = s % 3;
  final options = List.of(distractors)
    ..insert(targetIndex, ChoiceOption(target, targetEntry.emoji));
  return ChoicePlan(options, targetIndex);
}

/// A clause that names nothing itself ("Tap it."): only glue words remain.
bool _isTrivialClause(String clause) {
  const glue = {
    'it',
    'them',
    'the',
    'a',
    'to',
    'now',
    'again',
    'here',
    'and',
    'then',
    'one',
    'word',
  };
  final ws = _words(clause);
  return ws.isNotEmpty && ws.every(glue.contains);
}

const _vowels = ['a', 'e', 'i', 'o', 'u'];

/// A reading choice: the quoted [word] as text, against minimal-pair
/// distractors. Prefers the step's other quoted words (the contrast the
/// narration is actually teaching), then a silent-e toggle, then seeded
/// vowel swaps.
ChoicePlan _wordPlan(String itemId, int step, String word, String narration) {
  final distractors = <String>[];
  void add(String w) {
    final c = w.toLowerCase();
    if (c != word && c.isNotEmpty && !distractors.contains(c)) {
      distractors.add(c);
    }
  }

  for (final m in RegExp(r"'([A-Za-z]+)'").allMatches(narration)) {
    add(m.group(1)!);
  }
  // Silent-e toggle: cap ↔ cape.
  add(word.endsWith('e') ? word.substring(0, word.length - 1) : '${word}e');
  // Seeded vowel swaps on the first vowel: cap → cop / cup…
  var s = _seed(itemId, step);
  final vi = word.split('').indexWhere(_vowels.contains);
  if (vi >= 0) {
    for (var i = 0; i < _vowels.length && distractors.length < 4; i++) {
      s = _next(s);
      final v = _vowels[s % _vowels.length];
      add(word.replaceRange(vi, vi + 1, v));
    }
  }
  while (distractors.length < 2) {
    add('$word${distractors.length + 1}'); // unreachable for real words
  }

  s = _next(s);
  final targetIndex = s % 3;
  final options = [for (final d in distractors.take(2)) ChoiceOption(d, d)]
    ..insert(targetIndex, ChoiceOption(word, word));
  return ChoicePlan(options, targetIndex);
}

/// A choice among symbols (letters, numerals): [target] plus two seeded
/// distractors from [pool]; [wordFor] supplies the accessibility label.
ChoicePlan _symbolPlan(
  String itemId,
  int step, {
  required String target,
  required List<String> pool,
  required String Function(String) wordFor,
}) {
  final rest = pool.where((c) => c != target).toList();
  var s = _seed(itemId, step);
  final options = <ChoiceOption>[];
  while (options.length < 2 && rest.isNotEmpty) {
    s = _next(s);
    final c = rest.removeAt(s % rest.length);
    options.add(ChoiceOption(wordFor(c), c));
  }
  s = _next(s);
  final targetIndex = s % 3;
  options.insert(targetIndex, ChoiceOption(wordFor(target), target));
  return ChoicePlan(options, targetIndex);
}
