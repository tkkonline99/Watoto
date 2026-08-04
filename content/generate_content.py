#!/usr/bin/env python3
"""
Watoto content authoring pipeline.

Fills the content library up to the per-subject target by having Claude author
the *creative* fields while THIS script owns every structural/safety field
(id, stage, ages, designTier, reading, timed). That split means generated
items are schema-correct and design-rule compliant by construction, and each
one is still validated before it is merged. The run is resumable — existing
items are never touched or duplicated.

This is the honest path from 16% to 100%: run it (with your own API key) to
author the remaining items, or run it in --limit batches over time.

    export ANTHROPIC_API_KEY=sk-ant-...
    python generate_content.py --plan          # offline: show exactly what's missing
    python generate_content.py --limit 30      # author 30 items, validate, merge
    python generate_content.py                 # author everything still missing

Set WATOTO_MODEL to your preferred current model (default below).
"""
import os, sys, json, re, time, urllib.request, urllib.error

LIB = "watoto_content_library.json"
TARGET = {"lesson": 6, "quiz": 4, "story": 2}   # per stage-subject -> 12 * 57 = 684
MODEL = os.environ.get("WATOTO_MODEL", "claude-sonnet-4-6")
API_KEY = os.environ.get("ANTHROPIC_API_KEY")
ID_RE = re.compile(r"^s\d{2}\.[a-z0-9\-]+\.(lesson|quiz|story)\.\d{2}$")

TIER = {1: "parent-led", 2: "parent-led", 3: "parent-led", 4: "encourage-effort",
        5: "encourage-effort", 6: "gamify-gently", 7: "gamify-gently",
        8: "grant-autonomy", 9: "grant-autonomy", 10: "grant-autonomy"}


# ---------------------------------------------------------------- library ----
def load_lib():
    return json.load(open(LIB, encoding="utf-8"))

def save_lib(lib):
    json.dump(lib, open(LIB, "w", encoding="utf-8", newline="\n"), indent=2, ensure_ascii=False)

def slug_map(lib):
    """Recover the id slug used for each (stage, subject) from existing items."""
    m = {}
    for c in lib["content"]:
        m[(c["stage"], c["subject"])] = c["id"].split(".")[1]
    return m

def stage_meta(lib, stage):
    return next(s for s in lib["curriculum"]["stages"] if s["stage"] == stage)


# ------------------------------------------------------------------- gaps ----
def compute_gaps(lib):
    """Return list of (stage, subject, slug, ages, {type: deficit}, existing_titles)."""
    have = {}
    titles = {}
    for c in lib["content"]:
        key = (c["stage"], c["subject"])
        have.setdefault(key, {"lesson": 0, "quiz": 0, "story": 0})
        have[key][c["type"]] += 1
        titles.setdefault(key, []).append(c["title"])
    sm = slug_map(lib)
    gaps = []
    for s in lib["curriculum"]["stages"]:
        for subj in s["subjects"]:
            key = (s["stage"], subj)
            cur = have.get(key, {"lesson": 0, "quiz": 0, "story": 0})
            deficit = {t: max(0, TARGET[t] - cur.get(t, 0)) for t in TARGET}
            if sum(deficit.values()):
                gaps.append((s["stage"], subj, sm.get(key, _fallback_slug(subj)),
                             s["ages"], deficit, titles.get(key, [])))
    return gaps

def _fallback_slug(subj):
    return re.sub(r"[^a-z0-9]+", "-", subj.lower()).strip("-")[:20]

def next_index(lib, stage, slug, typ):
    n = 0
    for c in lib["content"]:
        if c["stage"] == stage and c["id"].split(".")[1] == slug and c["type"] == typ:
            n = max(n, int(c["id"].split(".")[-1]))
    return n + 1


# -------------------------------------------------------------- claude api ---
SYSTEM = """You author content for Watoto, an educational app for children from birth to age 10.
You write ONLY the creative fields of a content item. You never invent ids or metadata.

Hard rules (the app enforces these — follow them exactly):
- Age-appropriate, warm, encouraging, culturally inclusive (diverse names; not US-centric).
- NO time pressure anywhere; never reference timers, scores, or "fast".
- Quizzes must be retry-friendly: every question has gentle correctFeedback AND a kind,
  non-punitive retryFeedback that nudges toward the answer.
- For stages 1-4 the child cannot read: narration is spoken, instructions are one short
  spoken sentence, options are pictures with a one-word label.
- Never collect or request personal information from a child.
- Keep strings short and natural; this text will be read aloud.

Return ONLY a JSON array (no prose, no code fences). Each element:
{
 "title": str,
 "objective": str,                         // one learning objective
 "interaction": str,                       // e.g. "tap", "drag", "trace", "tap-to-count"
 "parentNote": str|null,                   // tip for the grown-up (use for stages 1-3)
 "assets": [{"type":"image|audio|haptic","ref":"img/sNN/...","desc":str}],
 // exactly one body matching the requested type:
 "steps":     [{"narration":str,"action":str,"feedback":str}],            // for lesson
 "questions": [{"prompt":str,"options":[{"label":str,"asset":str|null}],
                "answer":int,"correctFeedback":str,"retryFeedback":str}], // for quiz
 "pages":     [{"narration":str,"illustration":str,"interaction":str|null}] // for story
}"""

def call_claude(user_prompt, max_tokens=4000):
    if not API_KEY:
        sys.exit("ANTHROPIC_API_KEY not set. Use --plan for an offline preview.")
    body = json.dumps({
        "model": MODEL, "max_tokens": max_tokens, "system": SYSTEM,
        "messages": [{"role": "user", "content": user_prompt}],
    }).encode()
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages", data=body,
        headers={"x-api-key": API_KEY, "anthropic-version": "2023-06-01",
                 "content-type": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                data = json.load(r)
            return "".join(b.get("text", "") for b in data.get("content", []))
        except urllib.error.HTTPError as e:
            if e.code in (429, 529) and attempt < 3:
                time.sleep(2 ** attempt * 2); continue
            raise

def parse_items(text):
    text = re.sub(r"^```(?:json)?|```$", "", text.strip(), flags=re.MULTILINE).strip()
    start, end = text.find("["), text.rfind("]")
    return json.loads(text[start:end + 1])


# ----------------------------------------------------------- validation ------
def validate_item(it, stage_subjects):
    errs = []
    if not ID_RE.match(it.get("id", "")):
        errs.append("bad id")
    if it["subject"] not in stage_subjects:
        errs.append("subject not in stage")
    if it.get("timed") is not False:
        errs.append("timed must be false")
    t = it["type"]
    if t == "lesson" and not it.get("steps"):
        errs.append("no steps")
    if t == "quiz":
        for q in it.get("questions", []):
            if not (isinstance(q.get("answer"), int) and 0 <= q["answer"] < len(q.get("options", []))):
                errs.append("answer out of range")
            if not q.get("correctFeedback") or not q.get("retryFeedback"):
                errs.append("missing feedback")
    if t == "story" and not it.get("pages"):
        errs.append("no pages")
    return errs


def build_item(lib, stage, subject, slug, ages, typ, creative):
    """Wrap Claude's creative fields with the structural fields WE control."""
    idx = next_index(lib, stage, slug, typ)
    item = {
        "id": f"s{stage:02d}.{slug}.{typ}.{idx:02d}",
        "stage": stage, "ages": ages, "subject": subject, "type": typ,
        "title": creative.get("title", ""), "objective": creative.get("objective", ""),
        "designTier": TIER[stage], "reading": stage >= 5, "timed": False,
        "interaction": creative.get("interaction", "tap"),
        "parentNote": creative.get("parentNote"),
        "accessibility": "All narration is also shown as captions; playable audio-only.",
        "assets": creative.get("assets", []),
    }
    for k in ("steps", "questions", "pages"):
        if k in creative:
            item[k] = creative[k]
    return item


# ------------------------------------------------------------------- main ----
def main():
    lib = load_lib()
    gaps = compute_gaps(lib)
    total_missing = sum(sum(d.values()) for *_, d, _ in gaps)
    cur = len(lib["content"])

    print(f"Library: {cur}/684 items ({round(100*cur/684)}%). "
          f"Missing {total_missing} items across {len(gaps)} stage-subjects.")

    if "--plan" in sys.argv or total_missing == 0:
        for stage, subj, slug, ages, d, _ in gaps:
            need = ", ".join(f"{n} {t}" for t, n in d.items() if n)
            print(f"  s{stage:02d} {subj:<26} need {need}")
        print(f"\nEstimated API calls (one per stage-subject): {len(gaps)}")
        print("Run without --plan (and with ANTHROPIC_API_KEY set) to author them.")
        return

    limit = None
    if "--limit" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--limit") + 1])

    made = 0
    for stage, subj, slug, ages, deficit, existing in gaps:
        subjects = stage_meta(lib, stage)["subjects"]
        want = {t: n for t, n in deficit.items() if n}
        prompt = (
            f"Stage {stage} (ages {ages}, design tier '{TIER[stage]}', "
            f"reading {'allowed' if stage >= 5 else 'NONE — pre-reader'}).\n"
            f"Subject: {subj}.\n"
            f"Author NEW items, avoiding these existing titles: {existing}.\n"
            f"Counts to produce: " + ", ".join(f"{n} {t}" for t, n in want.items()) + ".\n"
            f"Return one JSON array with all of them; set the body key matching each item's type."
        )
        try:
            creatives = parse_items(call_claude(prompt))
        except Exception as e:
            print(f"  ! s{stage:02d} {subj}: generation failed ({e}); skipping")
            continue

        # the model returns items in some order; infer type from which body key is present
        for c in creatives:
            typ = "lesson" if "steps" in c else "quiz" if "questions" in c else "story"
            if want.get(typ, 0) <= 0:
                continue
            c["subject"] = subj
            item = build_item(lib, stage, subj, slug, ages, typ, c)
            item_for_check = {**item, "type": typ}
            errs = validate_item(item_for_check, subjects)
            if errs:
                print(f"  ! rejected {item['id']}: {errs}")
                continue
            lib["content"].append(item)
            want[typ] -= 1
            made += 1
            if limit and made >= limit:
                break
        save_lib(lib)
        print(f"  s{stage:02d} {subj}: now at target" if not any(want.values())
              else f"  s{stage:02d} {subj}: partial")
        if limit and made >= limit:
            break

    new = len(lib["content"])
    print(f"\nAuthored {made} items. Library now {new}/684 ({round(100*new/684)}%).")
    print("Run validate_content.py to re-check, then extract_strings.py to refresh the catalog.")

if __name__ == "__main__":
    main()
