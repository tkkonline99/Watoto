"""Merges authored recap questions into the content library.

The library is generated/edited elsewhere, so the recap questions live apart in
lesson_recaps.json (reviewable on their own) and are merged in by this script.
Idempotent: rerunning replaces the `recap` array rather than appending.

Usage (from repo root):
    python content/merge_recaps.py

Validates as it goes and refuses to write anything if a question is malformed
or gives away its own answer -- the same rule the Dart tests enforce.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
RECAPS = ROOT / "lesson_recaps.json"
TARGETS = [
    ROOT / "watoto_content_library.json",
    REPO / "apps" / "mobile" / "assets" / "content" / "watoto_content_library.json",
]

# Translations live beside the English source, one file per language, same
# shape. The app overlays them by dotted key at runtime.
LANGS = ["sw", "fr"]
I18N_DIRS = [
    ROOT / "i18n",
    REPO / "apps" / "mobile" / "assets" / "i18n",
]


def validate(item_id, questions):
    """Returns a list of problems, empty when the entry is sound."""
    problems = []
    if len(questions) < 2:
        problems.append(f"{item_id}: needs at least 2 questions")
    for i, q in enumerate(questions):
        where = f"{item_id}[{i}]"
        prompt = (q.get("prompt") or "").strip()
        options = q.get("options") or []
        answer = q.get("answer")
        if not prompt:
            problems.append(f"{where}: empty prompt")
        if len(options) < 2:
            problems.append(f"{where}: needs at least 2 options")
        if not isinstance(answer, int) or not (0 <= answer < len(options)):
            problems.append(f"{where}: answer index out of range")
            continue
        if any(not str(o).strip() for o in options):
            problems.append(f"{where}: empty option")
        if len(set(str(o).lower() for o in options)) != len(options):
            problems.append(f"{where}: duplicate options")
        # The rule that matters: a recap must not hand over its own answer.
        if str(options[answer]).lower() in prompt.lower():
            problems.append(
                f"{where}: prompt gives away the answer "
                f"({options[answer]!r} appears in {prompt!r})"
            )
    return problems


def main():
    recaps = json.loads(RECAPS.read_text(encoding="utf-8"))
    recaps.pop("_meta", None)

    problems = []
    for item_id, questions in recaps.items():
        problems += validate(item_id, questions)
    if problems:
        print("Refusing to merge -- fix these first:")
        for p in problems:
            print("  -", p)
        return 1

    for target in TARGETS:
        if not target.exists():
            print(f"skip (missing): {target}")
            continue
        data = json.loads(target.read_text(encoding="utf-8"))
        by_id = {c["id"]: c for c in data["content"]}

        applied, unknown = 0, []
        for item_id, questions in recaps.items():
            item = by_id.get(item_id)
            if item is None:
                unknown.append(item_id)
                continue
            if item.get("type") != "lesson":
                unknown.append(f"{item_id} (not a lesson)")
                continue
            item["recap"] = questions
            applied += 1

        target.write_text(
            json.dumps(data, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8",
        )
        print(f"{target.relative_to(REPO)}: merged {applied} recaps")
        for u in unknown:
            print(f"   ! unknown id: {u}")

    return emit_translations(recaps)


def emit_translations(recaps):
    """Writes recap keys into the locale bundles the app overlays at runtime.

    Keys mirror the rest of the content i18n scheme: `<id>.recap.<i>.prompt`
    and `<id>.recap.<i>.options.<o>`. Options are keyed one by one so the
    authored answer index stays valid in every language -- translating an
    options array as a block would let a reordering silently move the answer.
    """
    for lang in LANGS:
        path = ROOT / f"lesson_recaps.{lang}.json"
        if not path.exists():
            print(f"! no translations for {lang} ({path.name} missing)")
            continue
        translated = json.loads(path.read_text(encoding="utf-8"))
        translated.pop("_meta", None)

        problems = []
        keys = {}
        for item_id, english in recaps.items():
            local = translated.get(item_id)
            if local is None:
                problems.append(f"{lang}: {item_id} not translated")
                continue
            if len(local) != len(english):
                problems.append(
                    f"{lang}: {item_id} has {len(local)} questions, "
                    f"English has {len(english)}"
                )
                continue
            for i, (en_q, loc_q) in enumerate(zip(english, local)):
                en_opts, loc_opts = en_q["options"], loc_q.get("options", [])
                if len(en_opts) != len(loc_opts):
                    # A different option count means the answer index no
                    # longer points at the same thing -- refuse it.
                    problems.append(
                        f"{lang}: {item_id}[{i}] has {len(loc_opts)} options, "
                        f"English has {len(en_opts)}"
                    )
                    continue
                keys[f"{item_id}.recap.{i}.prompt"] = loc_q["prompt"]
                for o, text in enumerate(loc_opts):
                    keys[f"{item_id}.recap.{i}.options.{o}"] = text

        if problems:
            print(f"Refusing to write {lang} translations:")
            for p in problems:
                print("  -", p)
            return 1

        for d in I18N_DIRS:
            bundle = d / f"{lang}.json"
            if not bundle.exists():
                print(f"skip (missing): {bundle}")
                continue
            data = json.loads(bundle.read_text(encoding="utf-8"))
            data.update(keys)
            bundle.write_text(
                json.dumps(data, ensure_ascii=False, indent=1) + "\n",
                encoding="utf-8",
            )
            print(f"{bundle.relative_to(REPO)}: +{len(keys)} recap keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
