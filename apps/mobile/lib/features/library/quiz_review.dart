/// Tops a short quiz up with review questions from the lessons beside it.
///
/// 140 of the 166 quizzes in the library ask exactly **one** question. A quiz
/// that ends after a single tap is not a check on anything: it cannot separate
/// a child who knows the material from one who guessed, it gives the adaptive
/// engine a single noisy sample, and it is over before it has begun.
///
/// Nothing here is invented. The extra questions are the *authored recap*
/// questions belonging to lessons in the same stage and subject — content a
/// child in this quiz has been taught or will be, already written by hand and
/// already translated into Swahili and French (`assets/i18n/*.json` carries
/// 408 recap prompts). Reviewing a subject's lessons at the end of that
/// subject's quiz is what the quiz was for.
library;

import 'content_i18n.dart';
import 'library_models.dart';

/// How many questions a quiz should end up with when material allows.
///
/// Four is a real check without turning a two-minute activity into homework;
/// past roughly five, completion rates fall off a cliff in this age band.
const int targetQuizQuestions = 4;

/// Quizzes for the youngest band are deliberately left alone.
///
/// `parent-led` covers ages 0–2, where the design is a grown-up and a child
/// sharing one delighted moment ("Tap the cup Teddy is under"). Stretching
/// that into a four-question round would break the thing that makes it work.
bool canExpandQuiz(LibraryItem quiz) =>
    quiz.type == LibraryType.quiz && quiz.designTier != 'parent-led';

/// The full question list to play for [quiz], localized into [lang].
///
/// Every string is resolved up front — the quiz's own questions through their
/// own i18n keys, borrowed ones through *their source lesson's* keys — so the
/// player can render the list directly without knowing where each question
/// came from. Borrowed questions look up under the wrong id otherwise and
/// would silently appear in English inside a Swahili session.
///
/// [correctFeedback] and [retryFeedback] supply the praise lines for borrowed
/// questions, which authored recaps do not carry; pass localized UI strings.
List<LibQuestion> localizedQuizQuestions({
  required LibraryItem quiz,
  required List<LibraryItem> library,
  required ContentI18n? i18n,
  required String lang,
  required String correctFeedback,
  required String retryFeedback,
  int target = targetQuizQuestions,
}) {
  final own = _localizedOwnQuestions(quiz, i18n, lang);
  if (!canExpandQuiz(quiz) || own.length >= target) return own;

  final taken = <String>{
    for (final q in own) _normalize(q.prompt),
  };
  final out = [...own];

  for (final source in _reviewSources(quiz, library)) {
    if (out.length >= target) break;
    final loc = LocalizedItem(source, i18n, lang);
    for (var i = 0; i < source.recap.length; i++) {
      if (out.length >= target) break;
      final recap = source.recap[i];
      if (!recap.isValid) continue;

      final prompt = loc.recapPrompt(i).trim();
      if (prompt.isEmpty) continue;
      // Two lessons in a subject often teach the same fact; asking it twice in
      // one quiz reads as a bug to a child.
      if (!taken.add(_normalize(prompt))) continue;

      final options = loc.recapOptions(i);
      if (options.length < 2 || recap.answer >= options.length) continue;
      if (options.any((o) => o.trim().isEmpty)) continue;

      out.add(
        LibQuestion(
          prompt: prompt,
          options: [for (final o in options) LibOption(label: o)],
          answer: recap.answer,
          correctFeedback: correctFeedback,
          retryFeedback: retryFeedback,
        ),
      );
    }
  }
  return out;
}

/// The quiz's own questions, with their translations already applied.
List<LibQuestion> _localizedOwnQuestions(
  LibraryItem quiz,
  ContentI18n? i18n,
  String lang,
) {
  final loc = LocalizedItem(quiz, i18n, lang);
  return [
    for (var i = 0; i < quiz.questions.length; i++)
      LibQuestion(
        prompt: loc.questionPrompt(i),
        options: [
          for (var o = 0; o < quiz.questions[i].options.length; o++)
            LibOption(
              label: loc.optionLabel(i, o),
              asset: quiz.questions[i].options[o].asset,
            ),
        ],
        answer: quiz.questions[i].answer,
        correctFeedback: loc.questionCorrect(i),
        retryFeedback: loc.questionRetry(i),
      ),
  ];
}

/// Lessons whose recaps may be borrowed, nearest first.
///
/// Same stage and subject only: a Stage 7 fractions question inside a Stage 3
/// counting quiz would be a wall, not a review. Ordering is deterministic and
/// derived from the quiz id, so a child meets the same quiz on a second run —
/// predictability matters at this age, and a quiz that reshuffles itself makes
/// the adaptive difficulty signal meaningless.
List<LibraryItem> _reviewSources(LibraryItem quiz, List<LibraryItem> library) {
  final pool = [
    for (final item in library)
      if (item.type == LibraryType.lesson &&
          item.stage == quiz.stage &&
          item.subject == quiz.subject &&
          item.recap.isNotEmpty)
        item,
  ]..sort((a, b) => a.id.compareTo(b.id));
  if (pool.length < 2) return pool;

  // Rotate the pool by a stable hash of the quiz id so the three quizzes in a
  // subject draw from different lessons instead of all reusing lesson 01.
  final offset = _stableHash(quiz.id) % pool.length;
  return [...pool.sublist(offset), ...pool.sublist(0, offset)];
}

/// Small deterministic hash — `String.hashCode` is not stable across runs.
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9À-ɏ ]'), '').trim();
