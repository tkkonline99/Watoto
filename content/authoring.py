"""Shared machinery for the per-stage authoring scripts.

`author_stage1.py`, `author_stage2.py` and `author_stage3.py` differ only in
their content. Everything mechanical lives here: where the two copies of the
library are, how a quiz or story becomes both a library item and a set of i18n
keys, and how extra steps are appended to a shipped lesson idempotently.

The idempotency rule is the part worth knowing. Re-running a stage script must
produce the same library, and matching authored steps *by text* does not
achieve that — it broke twice while stage 1 was being written. Once when an
authored line happened to reuse a shipped step's wording, so the filter ate the
original and the lesson lost a step; and again whenever an authored line was
reworded, because the old version stopped being recognised and survived
alongside the new one. So each script declares how many steps every lesson
shipped with, and the append truncates back to that count first. That number is
a fact about the library rather than a guess about the text.

Both copies of the library are written from one in-memory object. They are
supposed to be identical (`validate_content.py` fails if they drift), and
editing them separately is how they drifted before.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LIBRARIES = [
    ROOT / "apps/mobile/assets/content/watoto_content_library.json",
    ROOT / "content/watoto_content_library.json",
]
I18N_DIRS = [ROOT / "apps/mobile/assets/i18n", ROOT / "content/i18n"]
LANGS = ("en", "sw", "fr")

ACCESSIBILITY = "All narration is also shown as captions; playable audio-only."


def Q(prompt, opts, answer, correct, retry):
    """One quiz question. Every string is an (en, sw, fr) tuple."""
    return {"prompt": prompt, "options": opts, "answer": answer,
            "correctFeedback": correct, "retryFeedback": retry}


def build_quiz(spec, *, stage, ages, tier):
    """A quiz spec becomes the English library item plus keys for all locales."""
    qid = spec["id"]
    item = {
        "id": qid, "stage": stage, "ages": ages, "subject": spec["subject"],
        "type": "quiz", "title": spec["title"][0], "objective": spec["objective"][0],
        "designTier": tier, "reading": False, "timed": False,
        "interaction": spec.get("interaction", "tap"),
        "parentNote": spec["parentNote"][0],
        "accessibility": ACCESSIBILITY,
        "assets": [], "questions": [],
    }
    keys = {l: {} for l in LANGS}
    for n, lang in enumerate(LANGS):
        keys[lang][f"{qid}.title"] = spec["title"][n]
        keys[lang][f"{qid}.parentNote"] = spec["parentNote"][n]
    seen = set()
    for qn, q in enumerate(spec["questions"]):
        opts = []
        for om, (label, asset) in enumerate(q["options"]):
            opts.append({"label": label[0], "asset": asset})
            for n, lang in enumerate(LANGS):
                keys[lang][f"{qid}.questions.{qn}.options.{om}.label"] = label[n]
            if asset not in seen:
                seen.add(asset)
                item["assets"].append({"type": "image", "ref": asset, "desc": label[0]})
        item["questions"].append({
            "prompt": q["prompt"][0], "options": opts, "answer": q["answer"],
            "correctFeedback": q["correctFeedback"][0],
            "retryFeedback": q["retryFeedback"][0],
        })
        for n, lang in enumerate(LANGS):
            keys[lang][f"{qid}.questions.{qn}.prompt"] = q["prompt"][n]
            keys[lang][f"{qid}.questions.{qn}.correctFeedback"] = q["correctFeedback"][n]
            keys[lang][f"{qid}.questions.{qn}.retryFeedback"] = q["retryFeedback"][n]
    return item, keys


def build_story(spec, *, stage, ages, tier):
    sid = spec["id"]
    item = {
        "id": sid, "stage": stage, "ages": ages, "subject": spec["subject"],
        "type": "story", "title": spec["title"][0], "objective": spec["objective"][0],
        "designTier": tier, "reading": False, "timed": False,
        "interaction": "listen", "parentNote": spec["parentNote"][0],
        "accessibility": ACCESSIBILITY,
        "assets": [], "pages": [],
    }
    keys = {l: {} for l in LANGS}
    for n, lang in enumerate(LANGS):
        keys[lang][f"{sid}.title"] = spec["title"][n]
        keys[lang][f"{sid}.parentNote"] = spec["parentNote"][n]
    for pn, (narr, ill) in enumerate(spec["pages"]):
        item["pages"].append({"narration": narr[0], "illustration": ill})
        item["assets"].append({"type": "image", "ref": ill, "desc": narr[0]})
        for n, lang in enumerate(LANGS):
            keys[lang][f"{sid}.pages.{pn}.narration"] = narr[n]
    return item, keys


def apply_stage(
    *,
    stage,
    ages,
    tier,
    base_step_counts,
    extra_steps,
    new_quizzes,
    new_stories,
    min_steps,
    check_only=False,
):
    """Deepen a stage's lessons and add its missing quizzes and stories."""
    lib = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    by_id = {c["id"]: c for c in lib["content"]}
    overlay = {l: {} for l in LANGS}
    problems = []

    for lid, extras in extra_steps.items():
        item = by_id.get(lid)
        if item is None:
            problems.append(f"{lid} not in the library")
            continue
        n_base = base_step_counts.get(lid)
        if n_base is None:
            problems.append(f"{lid} has no base step count")
            continue
        if len(item["steps"]) < n_base:
            problems.append(
                f"{lid} has {len(item['steps'])} steps, fewer than the {n_base} it "
                f"shipped with — the library has been edited by hand")
            continue
        base = item["steps"][:n_base]
        steps = list(base)
        for offset, entry in enumerate(extras):
            action, mechanic, narr, fb = entry[:4]
            # Optional fifth element: everything a question step needs beyond
            # narration. `prompt` and `choices` are per-language tuples, in the
            # same (en, sw, fr) order as the rest; `answer`, `choiceIndex`,
            # `count`, `rows` and `cols` are numbers and travel as they are.
            # Without this a `multiChoice` step renders nothing to choose
            # between — which is how stages 4 and 5 first shipped 46 of them.
            more = entry[4] if len(entry) > 4 else {}
            n = len(base) + offset
            step = {
                "narration": narr[0], "action": action, "feedback": fb[0],
                "mechanic": mechanic,
            }
            if "prompt" in more:
                step["prompt"] = more["prompt"][0]
            if "choices" in more:
                step["choices"] = list(more["choices"][0])
            for key in ("answer", "choiceIndex", "count", "rows", "cols"):
                if key in more:
                    step[key] = more[key]
            steps.append(step)

            for i, lang in enumerate(LANGS):
                overlay[lang][f"{lid}.steps.{n}.narration"] = narr[i]
                overlay[lang][f"{lid}.steps.{n}.feedback"] = fb[i]
                if "prompt" in more:
                    overlay[lang][f"{lid}.steps.{n}.prompt"] = more["prompt"][i]
                for m, choice in enumerate(more.get("choices", [[]] * 3)[i]):
                    overlay[lang][f"{lid}.steps.{n}.choices.{m}"] = choice
        if not check_only:
            item["steps"] = steps

    for spec in new_quizzes:
        built, keys = build_quiz(spec, stage=stage, ages=ages, tier=tier)
        for lang in LANGS:
            overlay[lang].update(keys[lang])
        if not check_only:
            if spec["id"] in by_id:
                lib["content"][lib["content"].index(by_id[spec["id"]])] = built
            else:
                lib["content"].append(built)
    for spec in new_stories:
        built, keys = build_story(spec, stage=stage, ages=ages, tier=tier)
        for lang in LANGS:
            overlay[lang].update(keys[lang])
        if not check_only:
            if spec["id"] in by_id:
                lib["content"][lib["content"].index(by_id[spec["id"]])] = built
            else:
                lib["content"].append(built)

    if check_only:
        cur = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
        cur_ids = {c["id"] for c in cur["content"]}
        for spec in new_quizzes + new_stories:
            if spec["id"] not in cur_ids:
                problems.append(f"{spec['id']} missing")
        for lid in extra_steps:
            it = next((c for c in cur["content"] if c["id"] == lid), None)
            if it and len(it["steps"]) < min_steps:
                problems.append(f"{lid} is {len(it['steps'])} steps, needs {min_steps}")
        for p in problems:
            print("  x " + p)
        print(f"stage {stage} check:", "FAILED" if problems else "OK")
        return 1 if problems else 0

    if problems:
        for p in problems:
            print("  x " + p)
        return 1

    lib["content"].sort(key=lambda c: (c["stage"], c["subject"], c["type"], c["id"]))
    for path in LIBRARIES:
        path.write_text(json.dumps(lib, indent=2, ensure_ascii=False) + "\n",
                        encoding="utf-8", newline="\n")
    for d in I18N_DIRS:
        for lang in LANGS:
            p = d / f"{lang}.json"
            cur = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
            cur.update(overlay[lang])
            p.write_text(
                json.dumps(dict(sorted(cur.items())), indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8", newline="\n")

    lessons = [c for c in lib["content"] if c["stage"] == stage and c["type"] == "lesson"]
    lo, hi = min(len(l["steps"]) for l in lessons), max(len(l["steps"]) for l in lessons)
    print(f"stage {stage}: {len(extra_steps)} lessons deepened (now {lo}-{hi} steps), "
          f"{len(new_quizzes)} quizzes and {len(new_stories)} stories added")
    print(f"i18n: {len(overlay['en'])} keys per language x {len(LANGS)} languages")
    return 0
