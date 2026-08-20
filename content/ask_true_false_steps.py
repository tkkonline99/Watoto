"""Give the true/false `tap` steps options that match what they ask.

Why this exists
---------------
`choicePlanFor` used to stage a two-card true/false pair whenever the tap
directive contained the word "true" or "false", taking whichever literal it
saw **first** as the correct answer. Word order is not an answer key:

  * s09.coding.lesson.05 step 4 asks "Tap true or false: 7 is greater than
    10." The phrase "true or false" names true first, so the step scored
    **true** — and the child who worked out that 7 is not greater than 10 and
    tapped false was told they were wrong. Its own feedback reads "False."
  * Four more steps only *mention* truth while asking something else: "Tap
    **why** that cannot be true", "Tap **what** is actually true", "Tap **what
    happens** on a false test", "Tap the **best way** to check whether
    something online is true". Each was handed two cards that cannot answer a
    why, a what, or a how, and one of them was scored correct.
  * Only s09.coding.lesson.05 step 3 ("a spider has eight legs") came out
    right, and only because the answer happened to be the first literal.

One step here was not the planner's doing at all: s09.coding.lesson.05 step 1
shipped the *authored* options ["False", "3"]. No numeral appears anywhere in
that step, so the child chose between an answer and a stray digit. It is
staged with the same pair as the rest of the lesson.

There was a second defect in the same branch: the pair was built as
`ChoiceOption('true', 'true')`, which makes word and glyph identical, so the
card face was the raw English word. A Swahili or French child read "true" and
"false" — against the app's own UI-localization rule.

content_lexicon.dart now refuses any directive naming a truth value, so none
of these can be mis-staged again; they fall back to a plain tap. This script
supplies what they should have had all along: authored `choices` +
`choiceIndex`, which `_planFromExplicit` reads straight through.

Every answer here comes from the step's own `feedback`. Distractors are the
lesson's own material — the misconception the step is correcting, or a claim
an earlier step in the same lesson makes ("the sun drives the cycle" becomes
"the sun makes water") — never invented noise.

Unlike the numerals in ask_number_steps.py these options are prose, so each
carries a real translation. **The Swahili and French are mine and have not
been reviewed by a native speaker**, in common with the rest of the app's
non-English copy.

Answers are placed off slot 0 where the choice allows; step_coverage_test
caps any one slot at 70% of all comprehension checks. The two genuine
true/false questions keep the conventional True-then-False order, which puts
one answer in each slot.

Idempotent: re-running makes no further change.

    python content/ask_true_false_steps.py            # from the repo root
    python content/ask_true_false_steps.py --check    # verify, exit 1 on drift
"""
from __future__ import annotations

import argparse
import json
import sys

from authoring import I18N_DIRS, LANGS, LIBRARIES

# Longest an option may be before it stops being tappable on a phone.
# step_coverage_test.dart enforces the same bound.
MAX_OPTION = 22

# An option in all three languages, in LANGS order (en, sw, fr).
Option = tuple[str, str, str]

# The true/false card pair, shared by every step that offers it so a child
# meets the same two words each time they are asked.
#
# `Uongo` rather than `si kweli`: step 0 of s09.coding.lesson.05 already ships
# an authored Kweli/Uongo pair, and matching it matters more on the cards —
# which are what the child taps — than matching each narration, since the
# narrations themselves alternate ("kweli au uongo" on step 0, "kweli au si
# kweli" on steps 3 and 4). **That alternation is one for a native speaker to
# settle**; this only makes the buttons agree with each other.
TRUE_FALSE: list[Option] = [
    ("True", "Kweli", "Vrai"),
    ("False", "Uongo", "Faux"),
]

# item id -> step index -> (options, answer index)
#
# The answer is stated in each step's feedback; it is quoted in the comment so
# a reviewer can check the pairing without opening the library.
STAGED: dict[str, dict[int, tuple[list[Option], int]]] = {
    # "It is the same water going round. Nothing new is made, only moved."
    # Distractors: the misconception the step names ("rain is new water",
    # relocated to the clouds), and step 4's "the sun drives the cycle"
    # misread as the sun *making* the water.
    "s08.science.lesson.05": {
        6: (
            [
                ("Clouds make new water", "Mawingu hutengeneza maji mapya",
                 "Les nuages font de l'eau"),
                ("It is the same water", "Ni maji yaleyale",
                 "C'est la même eau"),
                ("The sun makes water", "Jua hutengeneza maji",
                 "Le soleil fabrique l'eau"),
            ],
            1,
        ),
    },
    "s09.coding.lesson.05": {
        # Not a planner mistake: this step was *authored* with the options
        # ["False", "3"], and the 3 is nothing — no numeral appears anywhere in
        # the step, and the child was picking between an answer and a digit.
        # The narration states the answer ("'A cat has wings' is false"), so
        # this is a confirm-what-you-heard beat; it keeps the same two cards as
        # the rest of the lesson instead of a stray number.
        1: (TRUE_FALSE, 1),
        # "True, and checkable. That is what makes it a condition."
        3: (TRUE_FALSE, 0),
        # "False. The computer does not argue, it just takes the else branch."
        4: (TRUE_FALSE, 1),
    },
    # "Same work, spread thinner. Machines make it possible, not free."
    # Distractors: the claim being corrected, and the stronger version of it
    # that the feedback's "not free" exists to deny.
    "s09.science.lesson.05": {
        6: (
            [
                ("Less work in total", "Kazi kidogo kwa jumla",
                 "Moins de travail en tout"),
                ("Same work, less push", "Kazi ileile, nguvu kidogo",
                 "Même travail, moins de force"),
                ("No work at all", "Hakuna kazi kabisa",
                 "Aucun travail du tout"),
            ],
            1,
        ),
    },
    # "Nothing at all — which is sometimes right, and sometimes the whole bug."
    # Distractors: the else branch that the step says is not there (step 3:
    # "skipped entirely, not run quietly in the background"), and the guess
    # that a missing branch is an error.
    "s10.coding.lesson.04": {
        5: (
            [
                ("The else branch runs", "Tawi la else hufanya kazi",
                 "La branche else s'exécute"),
                ("Nothing happens", "Hakuna kinachotokea",
                 "Il ne se passe rien"),
                ("It shows an error", "Huonyesha hitilafu",
                 "Une erreur s'affiche"),
            ],
            1,
        ),
    },
    # "Find it somewhere else that has no reason to copy the first one."
    # Distractors: judging by appearance, and by popularity — which step 7's
    # "two sources that copied each other are still only one source" answers.
    "s10.coding.lesson.06": {
        6: (
            [
                ("See if it looks real", "Angalia kama inaonekana halisi",
                 "Voir si ça a l'air vrai"),
                ("Check a second source", "Angalia chanzo cha pili",
                 "Vérifier une autre source"),
                ("Count who shares it", "Hesabu wanaoishiriki",
                 "Compter ceux qui partagent"),
            ],
            1,
        ),
    },
}


def check_spec() -> None:
    """Fail loudly on a spec that the player or the tests would reject."""
    for item_id, steps in STAGED.items():
        for index, (options, answer) in steps.items():
            where = f"{item_id} step{index}"
            english = [o[0] for o in options]
            if len(options) < 2:
                sys.exit(f"{where}: needs at least two options")
            if len(set(e.lower() for e in english)) != len(english):
                sys.exit(f"{where}: duplicate options")
            if not 0 <= answer < len(options):
                sys.exit(f"{where}: answer index {answer} out of range")
            for option in options:
                if len(option) != len(LANGS):
                    sys.exit(f"{where}: '{option[0]}' needs one string per "
                             f"language {LANGS}")
                for text in option:
                    if not text.strip():
                        sys.exit(f"{where}: blank option")
                if len(option[0]) > MAX_OPTION:
                    sys.exit(f"{where}: option '{option[0]}' is too long")
                # lesson_depth_test requires sw/fr to differ from en; an
                # untranslated option would also put English in front of a
                # Swahili child, which is the half of the bug this fixes.
                if option[1] == option[0] or option[2] == option[0]:
                    sys.exit(f"{where}: '{option[0]}' is not translated")


def stage(library: dict) -> tuple[int, dict[str, dict[str, str]]]:
    """Apply STAGED to [library]; return (steps changed, i18n wanted)."""
    by_id = {item["id"]: item for item in library["content"]}
    wanted: dict[str, dict[str, str]] = {lang: {} for lang in LANGS}
    changed = 0

    for item_id, steps in STAGED.items():
        item = by_id.get(item_id)
        if item is None:
            sys.exit(f"{item_id}: not in the library")
        for index, (options, answer) in steps.items():
            if index >= len(item["steps"]):
                sys.exit(f"{item_id}: has no step{index}")
            step = item["steps"][index]
            english = [o[0] for o in options]
            before = (
                step.get("mechanic"),
                step.get("choices"),
                step.get("choiceIndex"),
            )
            step["mechanic"] = "multiChoice"
            step["choices"] = list(english)
            step["choiceIndex"] = answer
            if before != ("multiChoice", list(english), answer):
                changed += 1
            for position, option in enumerate(options):
                key = f"{item_id}.steps.{index}.choices.{position}"
                for lang_index, lang in enumerate(LANGS):
                    wanted[lang][key] = option[lang_index]

    return changed, wanted


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    check_spec()
    library = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    changed, wanted = stage(library)

    missing = 0
    for directory in I18N_DIRS:
        for lang in LANGS:
            path = directory / f"{lang}.json"
            if not path.exists():
                continue
            overlay = json.loads(path.read_text(encoding="utf-8"))
            missing += sum(
                1 for k, v in wanted[lang].items() if overlay.get(k) != v
            )

    if args.check:
        if changed or missing:
            print(f"drift: {changed} step(s) unstaged, "
                  f"{missing} missing translation(s)")
            return 1
        print("ok: every true/false step offers what it asks")
        return 0

    for path in LIBRARIES:
        path.write_text(
            json.dumps(library, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    for directory in I18N_DIRS:
        for lang in LANGS:
            path = directory / f"{lang}.json"
            if not path.exists():
                continue
            overlay = json.loads(path.read_text(encoding="utf-8"))
            overlay.update(wanted[lang])
            path.write_text(
                json.dumps(dict(sorted(overlay.items())), indent=2,
                           ensure_ascii=False) + "\n",
                encoding="utf-8",
            )

    print(f"{changed} step(s) staged; {missing} translation(s) written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
