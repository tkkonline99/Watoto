/// Turns a step that only *tells* the child something into a question they can
/// answer and be marked on.
///
/// A step like "23 × 4 … 20×4=80, 3×4=12." used to end in a passive "Got it!",
/// which teaches nothing and shows nobody whether the child is improving. The
/// content already carries the answer in its `feedback` ("Partial products: 80
/// and 12."), and sibling steps in the same lesson supply honest distractors
/// ("Solid!" / "Liquid!" / "Gas!"), so a real multiple choice can be built from
/// the material itself — no invented facts.
///
/// Returns null when the step gives nothing checkable; the caller then keeps
/// the plain continue button rather than inventing a question.
library;

import 'library_models.dart';

class StepCheck {
  const StepCheck({
    required this.options,
    required this.answerIndex,
    this.prompt,
  });

  /// Question line. Null when the caption above already asks it.
  final String? prompt;
  final List<String> options;
  final int answerIndex;

  String get answer => options[answerIndex];
}

/// Longest an option may be before it stops being tappable on a phone.
const int _maxOptionChars = 22;

/// An answer extracted from one step: what it is, and what was being asked.
class _Extracted {
  const _Extracted(this.answer, this.question);
  final String answer;

  /// The left-hand side ("1/5 + 2/5", "Perimeter"), or null.
  final String? question;
}

/// The right-hand side must run to the end of its clause: without the
/// lookahead the length bound matched a prefix, so "Theme = the message behind
/// the story." yielded the truncated "the message behind th".
final _equation = RegExp(
  r'([0-9][0-9\s/.,+\-×x*÷()]{0,18}?|[A-Za-z][A-Za-z\s]{1,14}?)'
  r'\s*=\s*'
  r'([0-9]+(?:\.[0-9]+)?(?:/[0-9]+)?[a-z]*|[a-z][a-z\s-]{1,20}(?=[.!?,;]|$))',
);
final _colon = RegExp(r'^([A-Za-z][A-Za-z\s]{2,20}):\s*(.{1,22}?)\.?$');
final _quoted = RegExp(r"'([^']{1,22})'");

/// A concept the content SHOUTS because it is the thing being taught
/// ("That is a SIMILE." / "…a METAPHOR.").
final _capsTerm = RegExp(r'\b([A-Z]{3,}(?:\s+[A-Z]{3,})?)\b');

/// Guards against regex debris. An answer is either a number-ish phrase
/// ("92", "3/5", "80 and 12") or a short run of words ("Solid", "SIMILE") —
/// never a mixture like "s 9" scraped out of "it's 9!".
bool _isPlausibleAnswer(String s) {
  if (s.isEmpty || s.length > _maxOptionChars) return false;
  if (s.split(RegExp(r'\s+')).length > 4) return false;
  final numeric = RegExp(r'^[0-9][0-9\s./+\-×x÷,]*(and\s*[0-9./]+)?$');
  final words = RegExp(r"^[A-Za-z][A-Za-z\s'’-]*$");
  return numeric.hasMatch(s) || words.hasMatch(s);
}
final _leadingNumber = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?(?:/[0-9]+)?)\s*[!.]');
final _numbers = RegExp(r'\d+(?:\.\d+)?(?:/\d+)?');

/// Strips the noise content authors put around an answer.
String _tidy(String s) => s
    .replaceAll(RegExp(r'^[\s….]+|[\s…]+$'), '')
    .replaceAll(RegExp(r"^'|['!.]+$"), '')
    .trim();

/// The answer this step teaches, or null when it teaches no crisp fact.
_Extracted? _extract(String narration, String feedback) {
  for (final source in [feedback, narration]) {
    final text = source.trim();
    if (text.isEmpty) continue;

    // "1/5 + 2/5 = 3/5." / "Perimeter = 16 units."
    final eq = _equation.firstMatch(text);
    if (eq != null) {
      final lhs = _tidy(eq.group(1)!);
      final rhs = _tidy(eq.group(2)!);
      if (_isPlausibleAnswer(rhs)) {
        return _Extracted(rhs, lhs.isEmpty ? null : lhs);
      }
    }

    // "Partial products: 80 and 12."
    final colon = _colon.firstMatch(text);
    if (colon != null) {
      final rhs = _tidy(colon.group(2)!);
      if (_isPlausibleAnswer(rhs)) {
        return _Extracted(rhs, _tidy(colon.group(1)!));
      }
    }

    // "That is a SIMILE." — the concept being taught.
    final caps = _capsTerm.firstMatch(text);
    if (caps != null) {
      final term = _tidy(caps.group(1)!);
      if (_isPlausibleAnswer(term)) return _Extracted(term, null);
    }

    // "'Solid!'" / "Swirl... 'Purple!'"
    final quoted = _quoted.firstMatch(text);
    if (quoted != null) {
      final inner = _tidy(quoted.group(1)!);
      if (_isPlausibleAnswer(inner)) return _Extracted(inner, null);
      // "'Green! You found the pattern.'" — the shout is the answer, the rest
      // is praise.
      final shout = RegExp(r'^([A-Za-z0-9/.]{2,})!').firstMatch(inner);
      if (shout != null) {
        final word = _tidy(shout.group(1)!);
        if (_isPlausibleAnswer(word)) return _Extracted(word, null);
      }
    }

    // "It floats on top!" / "It sinks to the bottom." — the verb is the
    // answer, and the sibling step supplies the opposite.
    final itVerb = RegExp(r'^It\s+([a-z]{3,})\b').firstMatch(text);
    if (itVerb != null) {
      final verb = itVerb.group(1)!;
      return _Extracted('${verb[0].toUpperCase()}${verb.substring(1)}', null);
    }

    // "'1 and 1 is 2!'" / "'That's 3!'" — the number the child should land on.
    final trailing =
        RegExp(r"(\d+(?:\.\d+)?(?:/\d+)?)\s*[!.]*['\)]*\s*$").firstMatch(text);
    if (trailing != null) {
      final n = _tidy(trailing.group(1)!);
      if (_isPlausibleAnswer(n)) return _Extracted(n, null);
    }

    // "24! Six groups of four."
    final lead = _leadingNumber.firstMatch(text);
    if (lead != null) return _Extracted(_tidy(lead.group(1)!), null);
  }
  return null;
}

bool _isNumeric(String s) => _numbers.hasMatch(s);

/// Plausible wrong answers for a numeric answer: the mistakes a child actually
/// makes — off by one, off by ten, the wrong part of a fraction.
List<String> _numericDistractors(String answer, int seed) {
  final out = <String>[];
  void add(String s) {
    if (s != answer && !out.contains(s) && s.length <= _maxOptionChars) {
      out.add(s);
    }
  }

  final matches = _numbers.allMatches(answer).toList();
  if (matches.isEmpty) return out;

  // Perturb one number at a time, keeping the rest of the phrase intact.
  for (final delta in [1, -1, 10, -10, 2]) {
    for (var m = matches.length - 1; m >= 0; m--) {
      final raw = matches[m].group(0)!;
      final replaced = _perturb(raw, delta);
      if (replaced == null) continue;
      add(answer.replaceRange(matches[m].start, matches[m].end, replaced));
      if (out.length >= 4) break;
    }
    if (out.length >= 4) break;
  }
  // Deterministic order so a child sees the same options on every visit.
  out.sort((a, b) => ((a.hashCode ^ seed) - (b.hashCode ^ seed)));
  return out;
}

String? _perturb(String number, int delta) {
  if (number.contains('/')) {
    final parts = number.split('/');
    final top = int.tryParse(parts[0]);
    final bottom = int.tryParse(parts[1]);
    if (top == null || bottom == null) return null;
    // Change the numerator, then the denominator: both are real mistakes.
    final t = top + (delta.isNegative ? -1 : 1);
    if (t > 0 && t != top) return '$t/$bottom';
    return null;
  }
  if (number.contains('.')) {
    final v = double.tryParse(number);
    if (v == null) return null;
    final n = v + delta / 10;
    if (n <= 0) return null;
    return n.toStringAsFixed(number.split('.').last.length);
  }
  final v = int.tryParse(number);
  if (v == null) return null;
  final n = v + delta;
  return n <= 0 ? null : '$n';
}

/// Builds a checkable question for [stepIndex], or null when the step offers
/// nothing to check.
StepCheck? comprehensionCheck({
  required LibraryItem item,
  required int stepIndex,
}) {
  if (stepIndex < 0 || stepIndex >= item.steps.length) return null;
  final step = item.steps[stepIndex];
  final found = _extract(step.narration, step.feedback);
  if (found == null) return null;
  final answer = found.answer;
  if (!_isPlausibleAnswer(answer)) return null;

  final seed = item.id.hashCode ^ (stepIndex * 7919);
  final distractors = <String>[];

  void offer(String? candidate) {
    if (candidate == null) return;
    final c = _tidy(candidate);
    if (c.isEmpty || c.length > _maxOptionChars) return;
    if (c.toLowerCase() == answer.toLowerCase()) return;
    if (distractors.any((d) => d.toLowerCase() == c.toLowerCase())) return;
    distractors.add(c);
  }

  if (_isNumeric(answer)) {
    _numericDistractors(answer, seed).forEach(offer);
  }

  // "Now red, blue, green, red, blue... what's next?" — the other items in the
  // list the child is looking at are the fairest wrong answers there are.
  if (distractors.length < 2) {
    for (final word in step.narration.split(RegExp(r'[,.\s]+'))) {
      final w = _tidy(word);
      if (w.length < 3 || !_isPlausibleAnswer(w)) continue;
      if (w.toLowerCase() == answer.toLowerCase()) continue;
      // Only words that keep company with the answer in the same sentence.
      if (!step.narration.toLowerCase().contains('$w,'.toLowerCase())) continue;
      offer('${w[0].toUpperCase()}${w.substring(1)}');
      if (distractors.length >= 2) break;
    }
  }

  // Sibling steps are the most honest distractors there are: same lesson, same
  // shape of answer, genuinely confusable ("Solid" / "Liquid" / "Gas").
  for (var i = 0; i < item.steps.length && distractors.length < 2; i++) {  // ignore: unused_local_variable
    if (i == stepIndex) continue;
    final other = _extract(item.steps[i].narration, item.steps[i].feedback);
    offer(other?.answer);
  }

  if (distractors.isEmpty) return null;

  final options = [answer, ...distractors.take(2)];
  // Stable shuffle: the answer must not always sit in the same slot.
  final answerSlot = (seed.abs()) % options.length;
  final ordered = List<String>.from(options);
  ordered
    ..removeAt(0)
    ..insert(answerSlot, answer);

  final question = found.question;
  return StepCheck(
    options: ordered,
    answerIndex: answerSlot,
    prompt: question == null || question.isEmpty ? null : '$question = ?',
  );
}
