"""Let the `build-circuit` steps be a circuit.

Why this exists
---------------
s10.science.lesson.01 opens with two steps whose `action` is `build-circuit`:
"Connect the battery, wire, and bulb to make a loop" and "Now open a gap in the
wire". The player had no such mechanic, so the content declared a stand-in:
step 0 carried `mechanic: multiChoice` with the options "A broken wire" /
"A complete loop", and step 1 fell back to a bare `tap`.

That stand-in asks a ten-year-old to *recall* the answer to the one thing the
step exists to let them *find out* — and it asks it twice, because the lesson's
own recap already poses the same question ("What makes the bulb light up?",
lesson_recaps.json). Nothing is lost by taking it off the step.

`StepMechanic.buildCircuit` now exists (play_stage_circuit.dart), so the steps
can declare what they always meant. `planStep` treats an authored `mechanic` as
authoritative, which is why the stand-in has to be removed here rather than
worked around in the player.

The mechanic is declared rather than left to the `action` heuristic for the
reason deepen_stage7.py gives: the heuristics read English, and a Swahili or
French child must play the same lesson.

Idempotent: re-running makes no further change.

    python content/wire_circuit_steps.py            # from the repo root
    python content/wire_circuit_steps.py --check    # verify only, exit 1 on drift
"""
from __future__ import annotations

import argparse
import json
import sys

from authoring import I18N_DIRS, LANGS, LIBRARIES

MECHANIC = "buildCircuit"

# The stand-in question lived on the step; these are the fields that carried it.
STANDIN_FIELDS = ("prompt", "choices", "choiceIndex")

# ---------------------------------------------------------------- questions
#
# The four steps after the builder each ask a real question and each was a bare
# `tap` on the item's emoji: the child tapped a picture of a battery to
# "answer" what happens to a bulb, and could not get it wrong.
#
# Every option below is already in the step's own `feedback` — "It goes out",
# "Metal. Wood, plastic and rubber all stop it", "A loop with no battery",
# "Beside it, it does nothing". Nothing here is invented, which is the rule
# comprehension_check.dart works to as well.
#
# `figures` are language-neutral picture ids drawn by circuit_figures.dart, in
# the same order as `choices`, so the artwork never depends on the wording.
QUESTIONS = {
    "s10.science.lesson.01": {
        3: {
            "question": (
                "What happens to the bulb when you cut the wire anywhere in "
                "the loop?",
                "Nini hutokea kwa balbu ukikata waya mahali popote kwenye "
                "mzunguko?",
                "Qu'arrive-t-il à l'ampoule si tu coupes le fil n'importe où "
                "dans la boucle ?",
            ),
            "choices": [
                (("The bulb stays lit.", "Balbu inaendelea kuwaka.",
                  "L'ampoule reste allumée."), "loop-lit"),
                (("The bulb goes out.", "Balbu inazimika.",
                  "L'ampoule s'éteint."), "loop-cut"),
            ],
            "answer": 1,
        },
        4: {
            "question": (
                "Which material will let the circuit work if you put it in "
                "the gap?",
                "Ni nyenzo gani itaruhusu mzunguko kufanya kazi ukiiweka "
                "kwenye pengo?",
                "Quel matériau refermera le circuit si tu le places dans "
                "l'ouverture ?",
            ),
            "choices": [
                (("Metal", "Chuma", "Le métal"), "gap-metal"),
                (("Wood", "Mbao", "Le bois"), "gap-wood"),
                (("Plastic", "Plastiki", "Le plastique"), "gap-plastic"),
            ],
            "answer": 0,
        },
        5: {
            "question": (
                "The bulb is in but the loop stays dark. What is missing?",
                "Balbu ipo lakini mzunguko unabaki giza. Nini kinakosekana?",
                "L'ampoule est en place mais la boucle reste éteinte. "
                "Que manque-t-il ?",
            ),
            "choices": [
                (("The battery", "Betri", "La pile"), "part-battery"),
                (("Another bulb", "Balbu nyingine", "Une autre ampoule"),
                 "part-bulb"),
                (("More wire", "Waya zaidi", "Plus de fil"), "part-wire"),
            ],
            "answer": 0,
        },
        6: {
            "question": (
                "Why is a switch put in the wire rather than beside it?",
                "Kwa nini swichi huwekwa ndani ya waya badala ya kando yake?",
                "Pourquoi place-t-on un interrupteur dans le fil plutôt qu'à "
                "côté ?",
            ),
            # Kept short on purpose: an option has to stay tappable on a phone
            # (step_coverage_test caps them at 22 characters). The diagram
            # shows *where* the switch sits; the caption says what that does.
            "choices": [
                (("It can break the loop.", "Inaweza kukata mzunguko.",
                  "Il peut couper la boucle."), "switch-in-loop"),
                (("It does nothing.", "Haifanyi chochote.",
                  "Il ne fait rien."), "switch-beside"),
            ],
            "answer": 0,
        },
    },
}


def is_circuit_step(step: dict) -> bool:
    return "circuit" in (step.get("action") or "").lower()


def retarget(lib: dict) -> tuple[int, list[str]]:
    """Point every build-circuit step at the builder. Returns (changed, keys)."""
    changed = 0
    dropped_keys: list[str] = []
    for item in lib["content"]:
        for index, step in enumerate(item.get("steps") or []):
            if not is_circuit_step(step):
                continue
            before = (step.get("mechanic"), *(step.get(f) for f in STANDIN_FIELDS))
            step["mechanic"] = MECHANIC
            for field in STANDIN_FIELDS:
                if field in step:
                    del step[field]
            # The overlay key for the removed prompt would otherwise linger and
            # translate a line nothing prints.
            dropped_keys.append(f"{item['id']}.steps.{index}.prompt")
            after = (step.get("mechanic"), *(step.get(f) for f in STANDIN_FIELDS))
            if before != after:
                changed += 1
    return changed, dropped_keys


def ask(lib: dict) -> tuple[int, dict[str, dict[str, str]]]:
    """Give the follow-up steps real, drawn options.

    Returns (changed, overlay) where overlay maps lang -> {key: text}.
    """
    changed = 0
    overlay: dict[str, dict[str, str]] = {lang: {} for lang in LANGS}
    by_id = {c["id"]: c for c in lib["content"]}
    for item_id, steps in QUESTIONS.items():
        item = by_id.get(item_id)
        if item is None:
            raise SystemExit(f"{item_id} is not in the library")
        for index, spec in steps.items():
            step = item["steps"][index]
            before = json.dumps(step, sort_keys=True)
            step["mechanic"] = "multiChoice"
            # The question goes in the narration, not in `prompt`.
            # LocalizedItem.stepPrompt is documented as "null when the step has
            # none (the narration is the question)", and the player prints both
            # — so setting a prompt that restates the narration asked the same
            # thing twice, one line under the other.
            step["narration"] = spec["question"][0]
            step.pop("prompt", None)
            step["choices"] = [c[0][0] for c in spec["choices"]]
            step["figures"] = [c[1] for c in spec["choices"]]
            step["choiceIndex"] = spec["answer"]
            if before != json.dumps(step, sort_keys=True):
                changed += 1

            for lang_index, lang in enumerate(LANGS):
                base = f"{item_id}.steps.{index}"
                overlay[lang][f"{base}.narration"] = spec["question"][lang_index]
                for option_index, (text, _figure) in enumerate(spec["choices"]):
                    overlay[lang][f"{base}.choices.{option_index}"] = \
                        text[lang_index]
    return changed, overlay


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    lib = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    changed, dropped_keys = retarget(lib)
    asked, wanted = ask(lib)

    # A key the builder steps dropped is re-added by a question step only if
    # that step also asks something; drop wins otherwise.
    dropped_keys = [k for k in dropped_keys if k not in wanted[LANGS[0]]]

    stale = 0
    missing = 0
    for directory in I18N_DIRS:
        for lang in LANGS:
            path = directory / f"{lang}.json"
            if not path.exists():
                continue
            overlay = json.loads(path.read_text(encoding="utf-8"))
            stale += sum(1 for k in dropped_keys if k in overlay)
            missing += sum(
                1 for k, v in wanted[lang].items() if overlay.get(k) != v
            )

    if args.check:
        if changed or asked or stale or missing:
            print(
                f"drift: {changed} circuit step(s) not on {MECHANIC}, "
                f"{asked} question step(s) unstaged, "
                f"{stale} stale key(s), {missing} missing translation(s)"
            )
            return 1
        print(f"ok: {MECHANIC} declared and every question staged")
        return 0

    for path in LIBRARIES:
        path.write_text(
            json.dumps(lib, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    for directory in I18N_DIRS:
        for lang in LANGS:
            path = directory / f"{lang}.json"
            if not path.exists():
                continue
            overlay = json.loads(path.read_text(encoding="utf-8"))
            for key in dropped_keys:
                overlay.pop(key, None)
            overlay.update(wanted[lang])
            path.write_text(
                json.dumps(dict(sorted(overlay.items())), indent=2,
                           ensure_ascii=False) + "\n",
                encoding="utf-8",
            )

    print(f"{changed} circuit step(s) declare {MECHANIC}; "
          f"{asked} question step(s) staged; "
          f"{stale} stale key(s) removed, {missing} translation(s) written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
