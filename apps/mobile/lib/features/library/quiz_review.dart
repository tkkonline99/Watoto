/// Resolves a quiz's questions into the language the child is playing in.
///
/// This file used to do more. It was written when 140 of the library's 166
/// quizzes asked exactly **one** question, and it topped a short quiz up by
/// borrowing the authored recap questions from lessons in the same stage and
/// subject. A quiz that ends after a single tap is not a check on anything: it
/// cannot separate a child who knows the material from one who guessed, and it
/// hands the adaptive engine a single noisy sample.
///
/// The borrowing is gone, because the reason for it is gone. Authoring took
/// every stage to the question count its design tier calls for
/// (`content/author_stage{1..10}.py`), and the ratchets in
/// `test/lesson_depth_test.dart` now sit at zero. Not one quiz in the library
/// is short. The top-up had already stopped firing — it returned early for
/// every quiz — so removing it changed nothing a child plays.
///
/// It is worth recording why it went rather than staying dormant. A borrowed
/// recap was always the weaker question: it came from a lesson in the same
/// subject the child may not have played yet, so a wrong answer could mean
/// "never taught" rather than "not learned", and the adaptive resolver could
/// not tell those apart. Scaffolding that has done its job is not free to
/// keep; it is one more thing that has to be understood before the next change
/// can be made safely.
///
/// If a future stage or subject ever ships thin, the ratchet tests will fail
/// before anybody notices in the app. Author the questions — that is what this
/// file's whole history argues for.
library;

import 'content_i18n.dart';
import 'library_models.dart';

/// The authored depth each design tier calls for.
///
/// Keep in sync with `minQuestionsByTier` in test/lesson_depth_test.dart and
/// `MIN_QUESTIONS_BY_TIER` in content/worklist.js — the same table the content
/// is authored against. Nothing reads this to change what plays any more; it
/// is here so the test that guards the finished state has one definition to
/// check against.
const _targetByTier = <String, int>{
  'parent-led': 2, // ages 0-2
  'encourage-effort': 3, // ages 3-5
  'gamify-gently': 4, // ages 6-7
  'grant-autonomy': 4, // ages 8-10
};

/// How many questions [quiz] is authored to ask.
int targetQuestionsFor(LibraryItem quiz) => _targetByTier[quiz.designTier] ?? 4;

/// The full question list to play for [quiz], localized into [lang].
///
/// Every string is resolved up front so the player can render the list
/// directly. The overlay wins over the English embedded in the library, which
/// is what makes a Swahili or French session read as authored rather than
/// falling back a field at a time.
List<LibQuestion> localizedQuizQuestions({
  required LibraryItem quiz,
  required ContentI18n? i18n,
  required String lang,
}) {
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
        // Carried through explicitly. This rebuilds the question to localize
        // its text, so any field not named here is silently dropped — the
        // declared visual was, and every quiz fell back to a glyph guessed
        // from the prompt while its scene sat unused in the content.
        //
        // Localized rather than copied: the visual's `alt` is a sentence, and
        // it is both announced to a screen reader and printed on screen where
        // the art behind a slot has not been drawn.
        visual: loc.questionVisual(i),
      ),
  ];
}
