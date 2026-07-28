/// "What did we learn?" — a short recap quiz at the end of a lesson.
///
/// A child finishes an activity and moves straight to the celebration, so
/// nothing ever asks them to *retrieve* what they just saw. Retrieval is the
/// part that makes it stick, and it is also the only honest signal of whether
/// the lesson landed: tapping the right picture once proves very little.
///
/// The questions are built from the lesson's own steps via
/// [comprehensionCheck], so nothing is invented — every answer and distractor
/// comes from the authored content. Lessons that teach no crisp, checkable
/// fact (most of the audio-first 0–5 band) yield nothing and are left alone.
library;

import 'comprehension_check.dart';
import 'library_models.dart';

/// One recap question, and the step it came from.
class RecapQuestion {
  const RecapQuestion({
    required this.stepIndex,
    required this.check,
    required this.prompt,
  });

  final int stepIndex;
  final StepCheck check;

  /// What the child is asked. Falls back to the step's own prompt when the
  /// check does not carry one of its own.
  final String prompt;

  List<String> get options => check.options;
  int get answerIndex => check.answerIndex;
}

/// Blank left where the answer was removed from a prompt.
const String recapBlank = '___';

/// Rewrites a prompt so it does not hand over its own answer.
///
/// Mid-lesson these lines are *teaching* ("That is a SIMILE.") and stating the
/// answer is the point. Asked again afterwards, out of context, the same line
/// is a giveaway — the child reads the answer straight out of the question. So
/// the answer is blanked out, turning the statement back into a question.
///
/// Returns null when nothing useful survives.
String? redactAnswer(String prompt, String answer) {
  final trimmedAnswer = answer.trim();
  if (trimmedAnswer.isEmpty) return prompt.trim();

  final pattern = RegExp(RegExp.escape(trimmedAnswer), caseSensitive: false);
  var out = prompt.replaceAll(pattern, recapBlank);

  // A prompt that opened with the answer ("13. 8 + 5 = ?") is left with a
  // dangling blank; drop it rather than ask "___. 8 + 5 = ?".
  out = out.replaceFirst(RegExp('^\\s*$recapBlank\\s*[.!,:;-]*\\s*'), '');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Nothing but punctuation and a blank left — not a question any more.
  if (out.replaceAll(recapBlank, '').replaceAll(RegExp(r'[^\w]'), '').isEmpty) {
    return null;
  }
  if (out.length < 6) return null;
  return out;
}

/// Fewest questions worth interrupting the celebration for.
const int minRecapQuestions = 2;

/// Most questions to ask. Three is enough to be a real check and short enough
/// that a six-year-old does not experience it as a punishment for finishing.
const int maxRecapQuestions = 3;

/// Builds the recap for [item], or an empty list when the lesson does not
/// teach enough checkable facts to make one worth asking.
///
/// Deliberately conservative: a recap that asks vague or repeated questions is
/// worse than no recap, so questions with duplicate answers are dropped and
/// anything under [minRecapQuestions] is abandoned entirely.
List<RecapQuestion> buildLessonRecap(
  LibraryItem item, {
  int max = maxRecapQuestions,
}) {
  if (item.type != LibraryType.lesson) return const [];
  // Pre-readers get spoken play, not a written quiz. The content marks this.
  if (!item.reading) return const [];

  // Authored questions win. Most short lessons teach by doing and state no
  // extractable fact, so the content carries their recap directly; extraction
  // stays as the path for lessons that do state one.
  final authored = <RecapQuestion>[];
  for (var i = 0; i < item.recap.length && authored.length < max; i++) {
    final r = item.recap[i];
    if (!r.isValid) continue;
    authored.add(
      RecapQuestion(
        stepIndex: i,
        check: StepCheck(options: r.options, answerIndex: r.answer),
        prompt: r.prompt.trim(),
      ),
    );
  }
  if (authored.length >= minRecapQuestions) return authored;

  final out = <RecapQuestion>[];
  final seenAnswers = <String>{};

  for (var i = 0; i < item.steps.length; i++) {
    final check = comprehensionCheck(item: item, stepIndex: i);
    if (check == null) continue;

    // Two steps that teach the same fact make for a repetitive recap.
    final key = check.answer.toLowerCase();
    if (!seenAnswers.add(key)) continue;

    final step = item.steps[i];
    // check.prompt is the cleanest form ("8 + 5 = ?"); the step's own text is
    // the fallback, and always needs the answer blanked out of it.
    final raw = check.prompt ?? step.prompt ?? step.narration;
    if (raw.trim().isEmpty) continue;
    final prompt = redactAnswer(raw, check.answer);
    if (prompt == null) continue;

    out.add(RecapQuestion(stepIndex: i, check: check, prompt: prompt));
    if (out.length >= max) break;
  }

  return out.length >= minRecapQuestions ? out : const [];
}

/// Whether [item] can offer a recap at all.
bool hasLessonRecap(LibraryItem item) => buildLessonRecap(item).isNotEmpty;

/// Percentage score for a recap run, used for the star rating and to feed the
/// adaptive engine a signal about whether the lesson actually landed.
int recapScorePct({required int correct, required int total}) {
  if (total <= 0) return 100;
  return ((correct / total) * 100).round().clamp(0, 100);
}
