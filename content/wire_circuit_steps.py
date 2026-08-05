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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    lib = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    changed, dropped_keys = retarget(lib)

    stale_keys = 0
    for directory in I18N_DIRS:
        for lang in LANGS:
            path = directory / f"{lang}.json"
            if not path.exists():
                continue
            overlay = json.loads(path.read_text(encoding="utf-8"))
            stale_keys += sum(1 for k in dropped_keys if k in overlay)

    if args.check:
        if changed or stale_keys:
            print(
                f"drift: {changed} circuit step(s) not on {MECHANIC}, "
                f"{stale_keys} stale prompt key(s)"
            )
            return 1
        print(f"ok: every build-circuit step declares {MECHANIC}")
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
            if not any(k in overlay for k in dropped_keys):
                continue
            for key in dropped_keys:
                overlay.pop(key, None)
            path.write_text(
                json.dumps(dict(sorted(overlay.items())), indent=2,
                           ensure_ascii=False) + "\n",
                encoding="utf-8",
            )

    print(f"{changed} circuit step(s) now declare {MECHANIC}; "
          f"{stale_keys} stale prompt key(s) removed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
