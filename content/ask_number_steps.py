"""Give the number/fraction `tap` steps options that match what they ask.

Why this exists
---------------
`choicePlanFor` stages a multiple choice for a directive step. When the step
names no lexicon noun it falls back to "tap the number N", pulling N out of
the narration with `\\b(\\d{1,3})\\b`. `\\b` treats `/`, `:` and `.` as word
boundaries, so that regex reads the **first digit of a compound number** and
stages a question about it:

  * s10.math.lesson.03 step 6 asks "Tap the fraction equal to 1/2: 3/6, 2/5,
    or 4/9" and staged **1** — the numerator of the fraction being matched
    against. The child was shown keycaps 8/2/1 and scored on tapping 1, while
    the three fractions the question actually offers went unstaged.
  * s10.math.lesson.05 step 4 ("Tap the larger number: 0.6 or 0.59") staged
    **0**; step 6 ("Tap what 0.25 means as a fraction") also staged **0**.
  * s08.math.lesson.06 step 0 ("... it's 2:15. Tap 2:15") staged **2**.

A companion defect: where the narration names a thing, the lexicon stages that
thing even when it is the *subject* rather than the answer. s09.math.lesson.03
step 4 ("Tap which is more: 3/4 of a pizza or 2/4 of the same pizza") staged
the **pizza**, and step 0 ("Which is bigger, 1/2 or 1/4?") staged big-vs-small
— neither asks what the lesson is teaching.

content_lexicon.dart now masks compound numbers before the bare-numeral scan
and refuses to invent distractors, so none of these can be mis-staged again;
they fall back to a plain tap. This script supplies what they should have had
all along: authored `choices` + `choiceIndex`, which `_planFromExplicit` reads
straight through.

Every answer here comes from the step's own `feedback`. Distractors are the
lesson's own material — the other fractions named in the narration, the
classic digit-reading slip (0.25 read as "2 and 5" → 2/5), the same time with
the hands swapped — never invented noise.

Options are numerals, so they are the same string in every language; the
i18n entries are written all the same on purpose, and `stepChoices` would fall
back to the library value regardless.

Answers are placed off slot 0 where the choice allows. Slot 0 already holds
the answer in 60% of the library's 199 comprehension checks, and
step_coverage_test caps any one slot at 70%.

Idempotent: re-running makes no further change.

    python content/ask_number_steps.py            # from the repo root
    python content/ask_number_steps.py --check    # verify only, exit 1 on drift
"""
from __future__ import annotations

import argparse
import json
import sys

from authoring import I18N_DIRS, LANGS, LIBRARIES

# Longest an option may be before it stops being tappable on a phone.
# step_coverage_test.dart enforces the same bound.
MAX_OPTION = 22

# item id -> step index -> (choices, answer index)
#
# The answer is stated in each step's feedback; it is repeated in the comment
# so a reviewer can check the pairing without opening the library.
STAGED: dict[str, dict[int, tuple[list[str], int]]] = {
    # "3/6. The bottom is exactly twice the top, which is what a half means."
    "s10.math.lesson.03": {6: (["2/5", "3/6", "4/9"], 1)},
    "s10.math.lesson.05": {
        # "0.6, because six tenths beats five tenths."
        4: (["0.59", "0.6"], 1),
        # "Twenty-five hundredths, which is also one quarter."
        # Both distractors are unit fractions like the answer, so the choice
        # is about size rather than shape: 0.25 mistaken for a half, or for
        # 1/5 (which is 0.2, the neighbouring decimal).
        6: (["1/2", "1/5", "1/4"], 2),
    },
    # "'Two-fifteen.'" — 3:15 swaps which hand is read, 2:45 mis-reads the
    # big hand as minutes-to rather than minutes-past.
    "s08.math.lesson.06": {0: (["3:15", "2:15", "2:45"], 1)},
    "s09.math.lesson.03": {
        # "'1/2 is bigger. Fewer pieces means bigger pieces.'"
        0: (["1/4", "1/2"], 1),
        # "Three quarters. When the bottoms match, just compare the tops."
        4: (["2/4", "3/4"], 1),
    },
}


def check_spec() -> None:
    """Fail loudly on a spec that the player or the tests would reject."""
    for item_id, steps in STAGED.items():
        for index, (choices, answer) in steps.items():
            where = f"{item_id} step{index}"
            if len(choices) < 2:
                sys.exit(f"{where}: needs at least two options")
            if len(set(c.lower() for c in choices)) != len(choices):
                sys.exit(f"{where}: duplicate options")
            if not 0 <= answer < len(choices):
                sys.exit(f"{where}: answer index {answer} out of range")
            for choice in choices:
                if not choice.strip():
                    sys.exit(f"{where}: blank option")
                if len(choice) > MAX_OPTION:
                    sys.exit(f"{where}: option '{choice}' is too long")


def stage(library: dict) -> tuple[int, dict[str, dict[str, str]]]:
    """Apply STAGED to [library]; return (steps changed, i18n wanted)."""
    by_id = {item["id"]: item for item in library["content"]}
    wanted: dict[str, dict[str, str]] = {lang: {} for lang in LANGS}
    changed = 0

    for item_id, steps in STAGED.items():
        item = by_id.get(item_id)
        if item is None:
            sys.exit(f"{item_id}: not in the library")
        for index, (choices, answer) in steps.items():
            if index >= len(item["steps"]):
                sys.exit(f"{item_id}: has no step{index}")
            step = item["steps"][index]
            before = (
                step.get("mechanic"),
                step.get("choices"),
                step.get("choiceIndex"),
            )
            step["mechanic"] = "multiChoice"
            step["choices"] = list(choices)
            step["choiceIndex"] = answer
            if before != ("multiChoice", list(choices), answer):
                changed += 1
            # Numerals read the same in every language, so all three overlays
            # carry the identical string rather than leaving sw/fr to the
            # English fallback.
            for option, text in enumerate(choices):
                key = f"{item_id}.steps.{index}.choices.{option}"
                for lang in LANGS:
                    wanted[lang][key] = text

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
        print("ok: every number/fraction tap step offers what it asks")
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
