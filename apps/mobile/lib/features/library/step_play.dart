/// Resolves what the child should *do* on a lesson step — never a dead prompt.
///
/// Content often says "write", "type", or "how many?" while the item-level
/// interaction is only `tap`. This planner reads narration + action + feedback
/// and produces a concrete mechanic (number answer, multi-choice, array build,
/// or a real gesture).
library;

import 'comprehension_check.dart';
import 'library_models.dart';

/// Mechanics the player can render for one step.
enum StepMechanic {
  /// Big picture tap (default).
  tap,

  /// Tap N objects to count them.
  count,

  /// Drag into basket.
  drag,

  /// Enter a number (pad or big digit buttons).
  numberAnswer,

  /// Pick among emoji/word options (lexicon choice).
  multiChoice,

  /// Build an m×n array of dots.
  buildArray,

  /// Watch/celebrate — animated beat then one big "Go!" tap.
  celebrate,

  /// Fake code editor + RUN button.
  codeRun,

  /// Nothing to hunt for: the step explains, demonstrates or celebrates, and
  /// the child reads/listens then continues. Gets a plain "Got it!" button —
  /// pretending an emoji is a puzzle would be dishonest here.
  explain,
}

class StepPlayPlan {
  const StepPlayPlan({
    required this.mechanic,
    this.answer,
    this.choices = const [],
    this.choiceIndex = 0,
    this.count = 3,
    this.rows = 0,
    this.cols = 0,
    this.promptHint,
    this.workspace,
    this.codeLine,
    this.outputLine,
    this.codeTokens = const [],
    this.messageChoices = const [],
    this.codeChallenge,
  });

  final StepMechanic mechanic;

  /// Correct numeric answer when [mechanic] is [StepMechanic.numberAnswer].
  final int? answer;

  /// Labels for multi-choice (digits as strings or words).
  final List<String> choices;
  final int choiceIndex;

  final int count;
  final int rows;
  final int cols;

  /// Short kid-facing hint under the prompt ("Type the number").
  final String? promptHint;

  /// Optional math workspace (long division / equation).
  final MathWorkspace? workspace;

  /// Coding mini-game: full line, printed output, tokens to assemble.
  final String? codeLine;
  final String? outputLine;
  final List<String> codeTokens;
  final List<String> messageChoices;
  final String? codeChallenge; // 'print' | 'variable' | 'loop' | 'if' | 'fix'
}

/// Visual scaffold for place-value / division problems.
class MathWorkspace {
  const MathWorkspace({
    required this.dividend,
    required this.divisor,
    this.quotientSlots = 2,
  });

  final int dividend;
  final int divisor;
  final int quotientSlots;
}

/// Extract the first sensible integer answer from feedback or narration.
///
/// Content authors often put the *step* answer first ("1. So 84 ÷ 4 = 21") and
/// the final quotient later — prefer the leading pedagogical token so kids
/// aren't stuck typing a number that only appears later in the sentence.
int? extractNumericAnswer(String feedback, String narration) {
  // "2. Write it…" / "1. So 84 ÷ 4 = 21" / "6! Multiplication…"
  final lead = RegExp(r'^\s*(\d+)\s*[.!]').firstMatch(feedback);
  if (lead != null) return int.tryParse(lead.group(1)!);

  // Equation in *narration* for the current ask ("Divide 4 ÷ 4") before feedback
  // spoilers like the full quotient.
  final narrDiv = RegExp(
    r'(\d+)\s*[÷/]\s*(\d+)',
  ).firstMatch(narration);
  if (narrDiv != null &&
      !narration.contains('?') &&
      RegExp(r'divide|÷|/', caseSensitive: false).hasMatch(narration)) {
    final a = int.tryParse(narrDiv.group(1)!);
    final b = int.tryParse(narrDiv.group(2)!);
    if (a != null && b != null && b != 0 && a % b == 0) {
      // Prefer this only when feedback also starts with that quotient later.
      final q = a ~/ b;
      if (feedback.contains('$q') || feedback.isEmpty) return q;
    }
  }

  // "8 - 8 = 0" → last equation result when no leading "N." token.
  final eqAll = RegExp(r'=\s*(\d+)').allMatches(feedback).toList();
  if (eqAll.isNotEmpty) {
    return int.tryParse(eqAll.last.group(1)!);
  }

  final leadLoose = RegExp(r'^\s*(\d+)\b').firstMatch(feedback.trim());
  if (leadLoose != null) return int.tryParse(leadLoose.group(1)!);

  // "how many Xs in Y?" → Y ~/ X
  final howMany = RegExp(
    r'how many\s+(\d+)\s*\w*\s+in\s+(\d+)',
    caseSensitive: false,
  ).firstMatch(narration);
  if (howMany != null) {
    final a = int.tryParse(howMany.group(1)!);
    final b = int.tryParse(howMany.group(2)!);
    if (a != null && b != null && a > 0) return b ~/ a;
  }

  // "N × M = ?" → product
  final mul = RegExp(r'(\d+)\s*[×x*]\s*(\d+)\s*=\s*\?').firstMatch(narration);
  if (mul != null) {
    final a = int.tryParse(mul.group(1)!);
    final b = int.tryParse(mul.group(2)!);
    if (a != null && b != null) return a * b;
  }

  final div = RegExp(r'(\d+)\s*[÷/]\s*(\d+)\s*=\s*\?').firstMatch(narration);
  if (div != null) {
    final a = int.tryParse(div.group(1)!);
    final b = int.tryParse(div.group(2)!);
    if (a != null && b != null && b != 0) return a ~/ b;
  }

  // Bare "4 ÷ 4" / "4 / 4" in the prompt (no ?)
  if (narrDiv != null) {
    final a = int.tryParse(narrDiv.group(1)!);
    final b = int.tryParse(narrDiv.group(2)!);
    if (a != null && b != null && b != 0 && a % b == 0) return a ~/ b;
  }

  final eqNarr = RegExp(r'=\s*(\d+)').allMatches(narration).toList();
  if (eqNarr.isNotEmpty) {
    return int.tryParse(eqNarr.last.group(1)!);
  }

  return null;
}

MathWorkspace? _workspaceFrom(String narration) {
  final m = RegExp(r'(\d+)\s*[÷/]\s*(\d+)').firstMatch(narration);
  if (m == null) return null;
  final dividend = int.tryParse(m.group(1)!);
  final divisor = int.tryParse(m.group(2)!);
  if (dividend == null || divisor == null) return null;
  return MathWorkspace(dividend: dividend, divisor: divisor);
}

(int, int)? _arrayDims(String narration) {
  // "3 rows of 4" / "3 rows × 4"
  final m = RegExp(
    r'(\d+)\s*rows?\s*(?:of|×|x|\*)\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(narration);
  if (m != null) {
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }
  final m2 = RegExp(r'(\d+)\s*[×x*]\s*(\d+)').firstMatch(narration);
  if (m2 != null) {
    return (int.parse(m2.group(1)!), int.parse(m2.group(2)!));
  }
  return null;
}

List<String> _digitChoices(int answer, {required int seed}) {
  final set = <int>{answer};
  var s = seed;
  final deltas = [1, -1, 2, -2, 3, 5, 10, answer + 1];
  for (final d in deltas) {
    final v = answer + d;
    if (v >= 0 && v <= 99 && v != answer) set.add(v);
    if (set.length >= 4) break;
    s = (s * 1103515245 + 12345) & 0x7fffffff;
  }
  while (set.length < 4) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    set.add(s % 20);
  }
  final list = set.toList();
  s = seed;
  for (var i = list.length - 1; i > 0; i--) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    final j = s % (i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  // Ensure answer present
  if (!list.contains(answer)) {
    list[0] = answer;
  }
  return list.map((e) => '$e').toList();
}

/// Pull a print("…") string or Output: line from content text.
String? extractPrintedText(String text) {
  final q = RegExp(r'print\s*\(\s*"([^"]*)"\s*\)').firstMatch(text);
  if (q != null) return q.group(1);
  final out = RegExp(
    r'(?:output(?:\s*box)?\s*shows?|output:|prints?:)\s*["“]?([^"”.\n]+)["”]?',
    caseSensitive: false,
  ).firstMatch(text);
  if (out != null) return out.group(1)!.trim();
  return null;
}

StepPlayPlan _codePlan(String narration, String feedback, int seed) {
  final lower = narration.toLowerCase();
  final printed = extractPrintedText(narration) ??
      extractPrintedText(feedback) ??
      'Hello, world!';

  // Order matters: more specific challenges first. ("your name AND your age"
  // must not fall into the generic "change the message" branch.)

  // Name + age on two lines.
  final wantsTwoLines = lower.contains('two lines') ||
      lower.contains('two line') ||
      (lower.contains('name') && lower.contains('age')) ||
      (lower.contains('name') && lower.contains('and') && lower.contains('age'));
  if (wantsTwoLines) {
    return const StepPlayPlan(
      mechanic: StepMechanic.codeRun,
      codeLine: 'print("Amani")\nprint(8)',
      outputLine: 'Amani\n8',
      codeChallenge: 'twoLines',
      messageChoices: ['Amani', 'Sam', 'Ada', 'Kibo', 'Zuri', 'Leo'],
      promptHint: '1) Pick your name  2) Set your age  3) Press RUN!',
    );
  }

  // Customize message inside quotes (not name+age).
  if (lower.contains('your own message') ||
      lower.contains('change the words') ||
      lower.contains('inside the quotes') ||
      (lower.contains('message') && lower.contains('run'))) {
    const msgs = [
      'Hello, world!',
      'Hi friend!',
      'I code!',
      'Yay robots!',
      'Be kind!',
    ];
    return StepPlayPlan(
      mechanic: StepMechanic.codeRun,
      codeLine: 'print("$printed")',
      outputLine: printed,
      messageChoices: msgs,
      codeChallenge: 'message',
      promptHint: 'Pick what the computer should say, then RUN!',
    );
  }

  // Variable lessons.
  if (lower.contains('name =') ||
      lower.contains('variable') ||
      lower.contains('age =') ||
      RegExp(r'\b\w+\s*=\s*"').hasMatch(narration) ||
      RegExp(r'\b\w+\s*=\s*\d+').hasMatch(narration)) {
    final name = RegExp(r'=\s*"([^"]+)"').firstMatch(narration)?.group(1) ??
        'Sam';
    return StepPlayPlan(
      mechanic: StepMechanic.codeRun,
      codeLine: 'name = "$name"\nprint(name)',
      outputLine: name,
      codeChallenge: 'variable',
      messageChoices: [name, 'Ada', 'Sam', 'Zuri', 'Kibo'],
      promptHint: 'Choose what the box remembers, then RUN!',
    );
  }

  // Loops.
  if (lower.contains('for ') ||
      lower.contains('range') ||
      lower.contains('loop') ||
      lower.contains('times')) {
    final n = int.tryParse(
          RegExp(r'range\s*\(\s*(\d+)\s*\)').firstMatch(narration)?.group(1) ??
              '',
        ) ??
        3;
    final line = List.filled(n, 'Hi').join('\n');
    return StepPlayPlan(
      mechanic: StepMechanic.codeRun,
      codeLine: 'for i in range($n):\n  print("Hi")',
      outputLine: line,
      codeChallenge: 'loop',
      answer: n,
      promptHint: 'Set how many times — then RUN the loop!',
    );
  }

  // If / else.
  if (lower.contains('if ') || lower.contains('else') || lower.contains('score')) {
    final win = !lower.contains('score to 4') && !lower.contains('score = 4');
    return StepPlayPlan(
      mechanic: StepMechanic.codeRun,
      codeLine: win
          ? 'score = 12\nif score >= 10:\n  print("You win!")'
          : 'score = 4\nif score >= 10:\n  print("You win!")\nelse:\n  print("Try again")',
      outputLine: win ? 'You win!' : 'Try again',
      codeChallenge: 'if',
      promptHint: 'Set the score, then RUN to see the decision!',
    );
  }

  // Default first print() lesson — assemble tokens then run.
  final tokens = <String>['print', '(', '"$printed"', ')'];
  return StepPlayPlan(
    mechanic: StepMechanic.codeRun,
    codeLine: 'print("$printed")',
    outputLine: printed,
    codeTokens: tokens,
    codeChallenge: 'print',
    promptHint: 'Tap the blocks in order, then smash RUN!',
  );
}

/// Build the play plan for one step of a library lesson.
StepPlayPlan planStep({
  required LibraryItem item,
  required int stepIndex,
  required LessonStep step,
}) {
  final action = step.action.toLowerCase();
  final narration = step.narration;
  final feedback = step.feedback;
  final interaction = item.interaction.toLowerCase();
  final seed = item.id.hashCode ^ (stepIndex * 9973);

  // --- Explicit schema fields (locale-safe; preferred over EN heuristics) ---
  final explicit =
      _planFromExplicit(step, interaction: interaction, seed: seed);
  if (explicit != null) return explicit;

  // --- Explicit code-run (kid mini-game, not a vague RUN button) ---
  if (action.contains('code') || interaction.contains('code-run')) {
    return _codePlan(narration, feedback, seed);
  }

  // --- Build array ---
  if (action.contains('build-array') ||
      action.contains('array') ||
      narration.toLowerCase().contains('rows of') ||
      narration.toLowerCase().contains('build the array')) {
    final dims = _arrayDims(narration) ?? (3, 4);
    return StepPlayPlan(
      mechanic: StepMechanic.buildArray,
      rows: dims.$1,
      cols: dims.$2,
      answer: dims.$1 * dims.$2,
      promptHint: 'Tap to place every dot!',
    );
  }

  // --- Numeric input (write / type / how many / = ?) ---
  final wantsNumber = action == 'input' ||
      action.contains('input') ||
      narration.contains('?') ||
      RegExp(r'\b(how many|write|type|enter|fill)\b', caseSensitive: false)
          .hasMatch(narration) ||
      RegExp(r'=\s*\?').hasMatch(narration);

  final answer = extractNumericAnswer(feedback, narration);
  if (wantsNumber && answer != null) {
    final workspace = _workspaceFrom(narration) ??
        (item.title.toLowerCase().contains('division')
            ? _workspaceFrom('${item.title} $narration')
            : null);

    // Small answers → big tappable digits (more fun for little kids).
    // Larger → pad so multi-digit works.
    if (answer <= 12) {
      final choices = _digitChoices(answer, seed: seed);
      final idx = choices.indexOf('$answer');
      return StepPlayPlan(
        mechanic: StepMechanic.numberAnswer,
        answer: answer,
        choices: choices,
        choiceIndex: idx < 0 ? 0 : idx,
        promptHint: 'Tap the number!',
        workspace: workspace,
      );
    }
    return StepPlayPlan(
      mechanic: StepMechanic.numberAnswer,
      answer: answer,
      promptHint: 'Type your answer',
      workspace: workspace,
    );
  }

  // --- Count family ---
  if (action.contains('count') ||
      interaction.contains('count') ||
      interaction.contains('number-line')) {
    final n = answer ?? (2 + (stepIndex % 3));
    return StepPlayPlan(
      mechanic: StepMechanic.count,
      count: n.clamp(2, 6),
      promptHint: 'Tap each one to count!',
    );
  }

  // --- Drag family ---
  if (action.startsWith('drag') ||
      interaction.startsWith('drag') ||
      action.contains('order') ||
      action.contains('trace') ||
      interaction.contains('trace')) {
    final tracing = action.contains('trace') ||
        interaction.contains('trace') ||
        RegExp(r'\btrace\b', caseSensitive: false).hasMatch(narration);
    return StepPlayPlan(
      mechanic: StepMechanic.drag,
      promptHint: tracing ? 'Trace it with your finger!' : 'Drag it in!',
    );
  }

  // --- On-screen finger gestures ---
  // The narration promises a swipe / slide / drawn line; a plain tap would be
  // telling the child one thing and accepting another. The drag stage takes a
  // real finger movement (and still completes on a tap, so it stays doable for
  // the youngest hands).
  final gesture = _gesturePrompt(action, interaction, narration);
  if (gesture != null) {
    return StepPlayPlan(
      mechanic: StepMechanic.drag,
      promptHint: gesture,
    );
  }

  // --- Off-screen actions (shake, clap, wave, breathe, sing) ---
  // These happen in the room, not on the glass. Staging them as "do it, then
  // tap when you're ready" is honest; a bare tap is not.
  final physical = _physicalPrompt(action, interaction, narration);
  if (physical != null) {
    return StepPlayPlan(
      mechanic: StepMechanic.celebrate,
      promptHint: physical,
    );
  }

  // --- Celebrate / watch ---
  // Only once the gesture and body-action checks above have had their say:
  // a "watch" step that tells the child to clap is a clapping step, not a
  // watching one. What is left really is exposition, and gets an honest
  // "Got it!" rather than an anonymous picture to poke at.
  if (action.contains('celebrate') ||
      action.contains('watch') ||
      action == 'real-world') {
    return const StepPlayPlan(mechanic: StepMechanic.explain);
  }

  // --- Rhythm / along: tap N times with the beat ---
  if (action.contains('rhythm') ||
      action.contains('along') ||
      interaction.contains('rhythm') ||
      interaction.contains('along')) {
    return StepPlayPlan(
      mechanic: StepMechanic.count,
      count: (answer ?? 3).clamp(2, 6),
      promptHint: 'Tap along with the beat!',
    );
  }

  // A tap step only makes sense when the narration actually asks for one.
  if (_hasDirective(narration)) {
    return StepPlayPlan(
      mechanic: StepMechanic.tap,
      promptHint: _tapPrompt(narration),
    );
  }

  // Everything left either asks a question ("Ice is hard. What state is it?")
  // or teaches a fact ("23 × 4 … 20×4=80, 3×4=12."). Both become a real
  // multiple choice built from the step's own answer plus honest distractors,
  // so the child answers and finds out whether they were right.
  final check = comprehensionCheck(item: item, stepIndex: stepIndex);
  if (check != null) {
    return StepPlayPlan(
      mechanic: StepMechanic.multiChoice,
      choices: check.options,
      choiceIndex: check.answerIndex,
      promptHint: check.prompt,
    );
  }

  // Only when the step offers nothing checkable (a pure celebration, a
  // sound-effect beat) does it fall back to a continue button.
  return const StepPlayPlan(mechanic: StepMechanic.explain);
}

/// Verbs that ask the child to act on something on screen. Kept wide — the
/// content says "Pop the bubble", "Mix RED and BLUE", "Read the word" as often
/// as it says "Tap" — but only counted in *imperative* position.
///
/// Position matters more than the word: "The bottoms match, so add the tops"
/// and "Maps use a key to help us read them" are statements, and staging them
/// as something to tap is exactly the fake exercise this planner avoids. So the
/// verb must open a sentence or follow a connector ("Now open a gap…").
/// The verb alternation on its own, without the position rule.
///
/// Public because `step_coverage_test.dart` enforces a deliberately weaker
/// version of this rule (verb anywhere, not just in imperative position) and
/// used to keep its own hand-copied duplicate of the list. The two drifted the
/// moment a verb was added here, and the test failed on content that was
/// correct. One list, two rules built from it.
const directiveVerbs =
    r'tap|touch|press|find|point to|pick|choose|show me|can you find'
    r'|pop|mix|pour|push|pull|roll|ring|knock|squeeze|stack|build|match'
    r'|sort|read|open|close|feed|wash|catch|put|place|move'
    // Peekaboo verbs. Stage 1 spends six lessons hiding and revealing things,
    // and "lift the box" is as much an on-screen instruction as "pop it".
    r'|lift|cover|uncover|reach|shut|peek';

final _directiveVerb = RegExp(
  r'(?:^|[.!?]\s+|\b(?:and|then|now|next|first|also)\s+)'
  '($directiveVerbs)'
  r'\b',
  caseSensitive: false,
);

/// Whether the narration asks the child to do something on screen.
bool _hasDirective(String narration) =>
    _directiveVerb.hasMatch(narration.trimLeft());


/// A prompt naming the on-screen gesture the narration asks for, or null.
String? _gesturePrompt(String action, String interaction, String narration) {
  final n = narration.toLowerCase();
  final a = '$action $interaction';
  if (a.contains('swipe') || RegExp(r'\bswipe\b').hasMatch(n)) {
    return 'Swipe across the picture!';
  }
  if (a.contains('slide') || RegExp(r'\bslide\b').hasMatch(n)) {
    return 'Slide them together!';
  }
  if (a.contains('draw') || RegExp(r'\bdraw|paint\b').hasMatch(n)) {
    return 'Drag your finger to draw!';
  }
  if (RegExp(r'\broll\b').hasMatch(n)) return 'Swipe to roll it!';
  return null;
}

/// A prompt for an action the child does with their body, or null.
String? _physicalPrompt(String action, String interaction, String narration) {
  final n = narration.toLowerCase();
  final a = '$action $interaction';
  if (a.contains('shake') || RegExp(r'\bshake\b').hasMatch(n)) {
    return 'Shake it — then tap!';
  }
  if (a.contains('wave') || RegExp(r'\bwave\b').hasMatch(n)) {
    return 'Wave — then tap!';
  }
  if (a.contains('breathe') || RegExp(r'\bbreathe|blow\b').hasMatch(n)) {
    return 'Breathe with me — then tap!';
  }
  if (RegExp(r'\bclap|stomp|dance|wiggle|stretch\b').hasMatch(n)) {
    return 'Do it with me — then tap!';
  }
  if (RegExp(r'\bsing|hum\b').hasMatch(n)) return 'Sing along — then tap!';
  // "real-world" steps send the child away from the glass ("Now touch YOUR
  // nose!"). Echo the instruction so the tap clearly means "I did it".
  if (a.contains('real-world')) {
    final clause = _instructionClause(narration);
    return clause == null ? 'Do it for real — then tap!' : '$clause — then tap!';
  }
  return null;
}

/// "Now touch YOUR nose!" -> "Touch YOUR nose". Null when no instruction is
/// recognisable.
String? _instructionClause(String narration) {
  final m = RegExp(
    r'\b(tap|touch|press|find|point to|pick|choose|hold|clap|wave|shake)\b'
    r'([^.!?]{2,32})',
    caseSensitive: false,
  ).firstMatch(narration);
  if (m == null) return null;
  final verb = m.group(1)!;
  final tail = m.group(2)!.trim();
  if (tail.isEmpty) return null;
  return '${verb[0].toUpperCase()}${verb.substring(1).toLowerCase()} $tail';
}

/// "Tap the little a." → "Tap the little a!" — echo what the child was asked
/// to find. Falls back to a friendly generic only when the sentence names no
/// target at all.
/// The prompt under the picture, or **null** when the caption above already
/// carries the instruction.
///
/// "Tap the cow." needs no second line: repeating it is noise, and replacing
/// it with an anonymous "Tap the picture!" is worse — it throws away the one
/// word the child needs. Only a directive buried inside a longer sentence
/// earns its own prompt.
String? _tapPrompt(String narration) {
  final match = RegExp(
    r'\b(?:tap|touch|press|find|point to|pick|choose)\b([^.!?]{2,40})',
    caseSensitive: false,
  ).firstMatch(narration);
  var tail = match?.group(1)?.trim() ?? '';
  // Keep the first clause only: "east (right), then south, then west" would be
  // a mouthful under a picture.
  final comma = tail.indexOf(',');
  if (comma > 1) tail = tail.substring(0, comma).trim();
  if (tail.isEmpty ||
      tail.toLowerCase().startsWith('to ') ||
      tail.length > 24) {
    return null;
  }
  // "A VERB is an action. Tap it." — "it" names nothing on its own. The
  // content marks the target with CAPS or quotes earlier in the sentence, so
  // say that instead: "Tap VERB!".
  if (_pronoun.hasMatch(tail)) {
    final referent = _referentIn(narration);
    return referent == null ? null : 'Tap $referent!';
  }

  final prompt = 'Tap $tail!';
  return _same(prompt, narration) ? null : prompt;
}

final _pronoun = RegExp(
  r'^(it|them|they|one|each|all|these|those)$',
  caseSensitive: false,
);

/// The thing an instruction like "Tap it" is pointing at: a quoted word, or a
/// SHOUTED concept the content is teaching. Null when the sentence names
/// neither — better a silent picture than a meaningless prompt.
String? _referentIn(String narration) {
  final quoted = RegExp("'([^']{1,20})'").firstMatch(narration);
  if (quoted != null) return "'${quoted.group(1)}'";
  final shouted = RegExp(r'\b([A-Z]{2,}(?:\s+[A-Z]{2,})?)\b').firstMatch(
    // Drop a leading capitalised sentence start so "HOT" wins over "The".
    narration,
  );
  final caps = shouted?.group(1);
  if (caps != null && caps.length > 1) return caps;
  return null;
}

final _punctuation = RegExp(r'[^a-z0-9]+');

bool _same(String a, String b) =>
    a.toLowerCase().replaceAll(_punctuation, '') ==
    b.toLowerCase().replaceAll(_punctuation, '');

/// Prefer author-supplied mechanic / answer / choices when present.
///
/// [interaction] is the item-level mechanic string. It is only ever used to
/// pick the *wording* of a prompt, never the mechanic itself: an explicitly
/// declared mechanic is authoritative. Prompts still read the English
/// narration, so a translated step falls back to the generic hint exactly as
/// it does today — but it now stages the right mechanic while doing so.
StepPlayPlan? _planFromExplicit(
  LessonStep step, {
  required String interaction,
  required int seed,
}) {
  final raw = step.mechanic?.trim().toLowerCase();
  if (raw == null || raw.isEmpty) {
    // Partial explicit: answer alone still beats EN heuristics for numbers.
    if (step.answer != null) {
      final answer = step.answer!;
      if (step.choices.isNotEmpty) {
        final idx = step.choiceIndex ?? step.choices.indexOf('$answer');
        return StepPlayPlan(
          mechanic: StepMechanic.numberAnswer,
          answer: answer,
          choices: step.choices,
          choiceIndex: idx < 0 ? 0 : idx,
          promptHint: 'Tap the number!',
        );
      }
      if (answer <= 12) {
        final choices = _digitChoices(answer, seed: seed);
        final idx = choices.indexOf('$answer');
        return StepPlayPlan(
          mechanic: StepMechanic.numberAnswer,
          answer: answer,
          choices: choices,
          choiceIndex: idx < 0 ? 0 : idx,
          promptHint: 'Tap the number!',
        );
      }
      return StepPlayPlan(
        mechanic: StepMechanic.numberAnswer,
        answer: answer,
        promptHint: 'Type your answer',
      );
    }
    return null;
  }

  StepMechanic? mech;
  for (final m in StepMechanic.values) {
    if (m.name.toLowerCase() == raw ||
        m.name.toLowerCase() == raw.replaceAll('-', '').replaceAll('_', '')) {
      mech = m;
      break;
    }
  }
  // Aliases
  mech ??= switch (raw) {
    'number' || 'input' || 'number_answer' || 'number-answer' =>
      StepMechanic.numberAnswer,
    'multi' || 'choice' || 'multi_choice' || 'multi-choice' =>
      StepMechanic.multiChoice,
    'array' || 'build_array' || 'build-array' => StepMechanic.buildArray,
    'code' || 'code_run' || 'code-run' => StepMechanic.codeRun,
    'real-world' || 'watch' => StepMechanic.celebrate,
    _ => null,
  };
  if (mech == null) return null;

  switch (mech) {
    case StepMechanic.numberAnswer:
      final answer = step.answer ?? extractNumericAnswer(step.feedback, step.narration);
      if (answer == null) {
        return const StepPlayPlan(
          mechanic: StepMechanic.numberAnswer,
          promptHint: 'Type your answer',
        );
      }
      // The workspace is the visual the child works the sum out on. The
      // heuristic path derives it from the narration; an explicit mechanic
      // must not cost them it.
      final workspace = _workspaceFrom(step.narration);
      if (step.choices.isNotEmpty) {
        final idx = step.choiceIndex ?? step.choices.indexOf('$answer');
        return StepPlayPlan(
          mechanic: StepMechanic.numberAnswer,
          answer: answer,
          choices: step.choices,
          choiceIndex: idx < 0 ? 0 : idx,
          promptHint: 'Tap the number!',
          workspace: workspace,
        );
      }
      if (answer <= 12) {
        final choices = _digitChoices(answer, seed: seed);
        final idx = choices.indexOf('$answer');
        return StepPlayPlan(
          mechanic: StepMechanic.numberAnswer,
          answer: answer,
          choices: choices,
          choiceIndex: idx < 0 ? 0 : idx,
          promptHint: 'Tap the number!',
          workspace: workspace,
        );
      }
      return StepPlayPlan(
        mechanic: StepMechanic.numberAnswer,
        answer: answer,
        promptHint: 'Type your answer',
        workspace: workspace,
      );
    case StepMechanic.multiChoice:
      return StepPlayPlan(
        mechanic: StepMechanic.multiChoice,
        choices: step.choices,
        choiceIndex: step.choiceIndex ?? 0,
        answer: step.answer,
        // The authored question, or nothing when the narration already asks it.
        promptHint: step.prompt,
      );
    case StepMechanic.count:
      final n = step.count ?? step.answer ?? 3;
      // Counting and keeping a beat are both "tap N times", but only one of
      // them is counting. The heuristic chain lets the count family answer
      // first and only reaches rhythm for what is left; mirror that, or a
      // clapping song starts telling the child to count.
      final a = step.action.toLowerCase();
      final counting = a.contains('count') ||
          interaction.contains('count') ||
          interaction.contains('number-line');
      final rhythmic = a.contains('rhythm') ||
          a.contains('along') ||
          interaction.contains('rhythm') ||
          interaction.contains('along');
      return StepPlayPlan(
        mechanic: StepMechanic.count,
        count: n.clamp(2, 8),
        promptHint: !counting && rhythmic
            ? 'Tap along with the beat!'
            : 'Tap each one to count!',
      );
    case StepMechanic.buildArray:
      final r = step.rows ?? 3;
      final c = step.cols ?? 4;
      return StepPlayPlan(
        mechanic: StepMechanic.buildArray,
        rows: r,
        cols: c,
        answer: step.answer ?? (r * c),
        promptHint: 'Tap to place every dot!',
      );
    case StepMechanic.drag:
      // "Swipe across the picture!" and "Trace it with your finger!" are very
      // different instructions to a child. Recover the specific one, in the
      // same order the heuristic chain would have: the drag family answers
      // first and never consults the gesture prompts, so a declared mechanic
      // must not either, or a tracing step starts saying "draw".
      final act = step.action.toLowerCase();
      final dragFamily = act.startsWith('drag') ||
          interaction.startsWith('drag') ||
          act.contains('order') ||
          act.contains('trace') ||
          interaction.contains('trace');
      if (dragFamily) {
        final tracing = act.contains('trace') ||
            interaction.contains('trace') ||
            RegExp(r'\btrace\b', caseSensitive: false).hasMatch(step.narration);
        return StepPlayPlan(
          mechanic: StepMechanic.drag,
          promptHint:
              tracing ? 'Trace it with your finger!' : 'Drag it in!',
        );
      }
      return StepPlayPlan(
        mechanic: StepMechanic.drag,
        promptHint: _gesturePrompt(step.action, interaction, step.narration) ??
            'Drag it in!',
      );
    case StepMechanic.celebrate:
      // A declared celebrate is a do-it-in-the-room step (clap, shake, wave).
      // Honour it whatever language the narration is in: `_physicalPrompt`
      // only supplies the *wording*, and it reads English, so consulting it
      // for the mechanic would turn every translated clapping step into a
      // silent "Got it!".
      return StepPlayPlan(
        mechanic: StepMechanic.celebrate,
        promptHint: _physicalPrompt(step.action, interaction, step.narration) ??
            'Do it together, then tap!',
      );
    case StepMechanic.explain:
      // Author-declared watch/explain: nothing to hunt for, so the child
      // gets the picture and a "Got it!" rather than a poke-the-emoji puzzle.
      return const StepPlayPlan(mechanic: StepMechanic.explain);
    case StepMechanic.codeRun:
      return _codePlan(step.narration, step.feedback, seed);
    case StepMechanic.tap:
      // The heuristic path checks `_hasDirective` before staging a tap, to
      // stop itself inventing a puzzle out of an expository line. A declared
      // tap has already had that decision made by an author (or by
      // tool/bake_mechanics.dart, which asked the same question of the
      // English text). Asking again here would re-run an English regex over
      // Swahili narration and quietly downgrade the step to "Got it!".
      return StepPlayPlan(
        mechanic: StepMechanic.tap,
        promptHint: _tapPrompt(step.narration),
      );
  }
}
