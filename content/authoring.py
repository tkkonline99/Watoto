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


def build_quiz(spec, *, stage, ages, tier, reading=False):
    """A quiz spec becomes the English library item plus keys for all locales.

    [reading] defaults False because stages 1-4 are pre-readers, but it must
    follow the stage: these builders *replace* an item when the id already
    exists, so a hardcoded False silently flips every rewritten stage-6 quiz
    from true, and `lesson_recap` reads that flag to decide whether a child can
    be shown a written recap at all.
    """
    qid = spec["id"]
    item = {
        "id": qid, "stage": stage, "ages": ages, "subject": spec["subject"],
        "type": "quiz", "title": spec["title"][0], "objective": spec["objective"][0],
        "designTier": tier, "reading": reading, "timed": False,
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
            # `asset` is None for a word-only option, which is most of them once
            # a quiz has four questions. Declaring {"ref": null} would put an
            # image asset with no image in the manifest the art pipeline reads.
            if asset is not None and asset not in seen:
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


def build_story(spec, *, stage, ages, tier, reading=False):
    """See [build_quiz] on why [reading] is a parameter and not a constant."""
    sid = spec["id"]
    item = {
        "id": sid, "stage": stage, "ages": ages, "subject": spec["subject"],
        "type": "story", "title": spec["title"][0], "objective": spec["objective"][0],
        "designTier": tier, "reading": reading, "timed": False,
        "interaction": "listen", "parentNote": spec["parentNote"][0],
        "accessibility": ACCESSIBILITY,
        "assets": [], "pages": [],
    }
    keys = {l: {} for l in LANGS}
    for n, lang in enumerate(LANGS):
        keys[lang][f"{sid}.title"] = spec["title"][n]
        keys[lang][f"{sid}.parentNote"] = spec["parentNote"][n]
    # A narration track the story already declared. This builder replaces the
    # whole item, so a cue not restated here is dropped — and these have never
    # been rendered, which makes the loss invisible at runtime and invisible in
    # a diff of what the child hears. Whether to keep an unrecorded cue is a
    # media decision; a script taking a story to depth should not make it by
    # omission.
    for ref, desc in spec.get("audio", []):
        item["assets"].append({"type": "audio", "ref": ref, "desc": desc})
    # Deduped like build_quiz's option art: a six-page story that returns to the
    # same scene twice would otherwise declare the same ref twice, and
    # worklist.js counts declared refs.
    seen = set()
    for pn, (narr, ill) in enumerate(spec["pages"]):
        item["pages"].append({"narration": narr[0], "illustration": ill})
        if ill is not None and ill not in seen:
            seen.add(ill)
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
    reading=False,
    min_questions=None,
    min_pages=None,
    base_question_counts=None,
    extra_questions=None,
    check_only=False,
):
    """Deepen a stage's lessons and add its missing quizzes and stories.

    [extra_questions] appends to quizzes that already exist, the same way
    [extra_steps] appends to lessons, and for the same reason. Taking a stage's
    quizzes to depth through [new_quizzes] means restating every question they
    already ask — 44 quizzes' worth of prompts, options and feedback across
    three languages, retyped only to be written back unchanged. Every one of
    those is a chance to drop a translation. A question is also not a page: it
    stands alone, so a third question appended after the first two reads
    exactly as well as one inserted between them, and nothing about the item
    needs rebuilding. Stories are the opposite and stay on [new_stories] —
    they have endings, so depth there means inserting a beat in the middle.

    Idempotency is [extra_steps]' rule, unchanged: truncate to the count the
    quiz shipped with, then append. Matching on question text instead would
    break the first time a prompt was reworded.
    """
    lib = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    by_id = {c["id"]: c for c in lib["content"]}
    overlay = {l: {} for l in LANGS}
    problems = []
    base_question_counts = base_question_counts or {}
    extra_questions = extra_questions or {}

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
        for extra in extras:
            action, mechanic, narr, fb = extra[:4]
            step = {
                "narration": narr[0], "action": action, "feedback": fb[0],
                "mechanic": mechanic,
            }
            # Optional 5th element: the numeric answer, authored rather than
            # inferred. `planStep` otherwise falls back to digging a number out
            # of the English feedback, which is the same trap baking mechanics
            # fixed — a translated line loses the numeral and the child is left
            # typing into a box with no right answer.
            if len(extra) > 4 and extra[4] is not None:
                step["answer"] = extra[4]
            steps.append(step)
        for offset, extra in enumerate(extras):
            narr, fb = extra[2], extra[3]
            n = len(base) + offset
            for i, lang in enumerate(LANGS):
                overlay[lang][f"{lid}.steps.{n}.narration"] = narr[i]
                overlay[lang][f"{lid}.steps.{n}.feedback"] = fb[i]
        if not check_only:
            item["steps"] = steps

    for spec in new_quizzes:
        built, keys = build_quiz(spec, stage=stage, ages=ages, tier=tier,
                                 reading=reading)
        for lang in LANGS:
            overlay[lang].update(keys[lang])
        if not check_only:
            if spec["id"] in by_id:
                lib["content"][lib["content"].index(by_id[spec["id"]])] = built
            else:
                lib["content"].append(built)
    for spec in new_stories:
        built, keys = build_story(spec, stage=stage, ages=ages, tier=tier,
                                  reading=reading)
        for lang in LANGS:
            overlay[lang].update(keys[lang])
        if not check_only:
            if spec["id"] in by_id:
                lib["content"][lib["content"].index(by_id[spec["id"]])] = built
            else:
                lib["content"].append(built)

    # Deepening runs *after* writing, so a quiz can be both authored here and
    # topped up by extra_questions — the `.04` quizzes of stages 4 and 5 are
    # both. The other order silently drops the appended questions, because
    # build_quiz replaces the whole item. by_id is rebuilt because those
    # replacements swapped in new dicts and the old handles are now stale.
    by_id = {c["id"]: c for c in lib["content"]}

    for qid, extras in extra_questions.items():
        item = by_id.get(qid)
        if item is None:
            problems.append(f"{qid} not in the library")
            continue
        n_base = base_question_counts.get(qid)
        if n_base is None:
            problems.append(f"{qid} has no base question count")
            continue
        if len(item["questions"]) < n_base:
            problems.append(
                f"{qid} has {len(item['questions'])} questions, fewer than the "
                f"{n_base} it shipped with — the library has been edited by hand")
            continue
        base = item["questions"][:n_base]
        questions = list(base)
        for offset, q in enumerate(extras):
            n = len(base) + offset
            opts = []
            for om, (label, asset) in enumerate(q["options"]):
                opts.append({"label": label[0], "asset": asset})
                for i, lang in enumerate(LANGS):
                    overlay[lang][f"{qid}.questions.{n}.options.{om}.label"] = label[i]
                # A word-only option is normal from `encourage-effort` up, where
                # the child reads the choice. Declaring {"ref": null} would put
                # an image asset with no image into the art manifest.
                if asset is not None and not any(
                        a.get("ref") == asset for a in item["assets"]):
                    item["assets"].append(
                        {"type": "image", "ref": asset, "desc": label[0]})
            questions.append({
                "prompt": q["prompt"][0], "options": opts, "answer": q["answer"],
                "correctFeedback": q["correctFeedback"][0],
                "retryFeedback": q["retryFeedback"][0],
            })
            for i, lang in enumerate(LANGS):
                overlay[lang][f"{qid}.questions.{n}.prompt"] = q["prompt"][i]
                overlay[lang][f"{qid}.questions.{n}.correctFeedback"] = q["correctFeedback"][i]
                overlay[lang][f"{qid}.questions.{n}.retryFeedback"] = q["retryFeedback"][i]
        if not check_only:
            item["questions"] = questions

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
        # Depth, not just presence. Checking only that a quiz exists is exactly
        # the gap that let five stages pass as done with one question each.
        by_cur = {c["id"]: c for c in cur["content"]}
        if min_questions:
            for qid in [s["id"] for s in new_quizzes] + list(extra_questions):
                it = by_cur.get(qid)
                if it and len(it.get("questions", [])) < min_questions:
                    problems.append(
                        f"{qid} is {len(it['questions'])} questions, "
                        f"needs {min_questions}")
        if min_pages:
            for spec in new_stories:
                it = by_cur.get(spec["id"])
                if it and len(it.get("pages", [])) < min_pages:
                    problems.append(
                        f"{spec['id']} is {len(it['pages'])} pages, "
                        f"needs {min_pages}")
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
          f"{len(extra_questions)} quizzes deepened, "
          f"{len(new_quizzes)} quizzes and {len(new_stories)} stories written")
    print(f"i18n: {len(overlay['en'])} keys per language x {len(LANGS)} languages")
    return 0
