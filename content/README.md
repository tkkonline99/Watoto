# Watoto Playable Content Library

This is the **playable content** layer for the Watoto app — the gate that sits right after
"Curriculum plan in-app." The plan (`curriculum.pptx`) defined *what* to teach across 10
stages (Birth → Age 10). This library is the *actual playable material* the app loads:
lessons, quizzes, and stories, structured against that plan.

## Files

| File | What it is |
|------|------------|
| `watoto_content_library.json` | Source of truth. Curriculum taxonomy + 39 authored, ready-to-wire content items + the build-out plan. |
| `validate_content.py` | Schema + design-rule checker. `--assets` exports the art/audio manifest. Put it in CI. |
| `README.md` | This file. |

## What's in the seed (v0.1.0)

39 items: **23 lessons, 10 quizzes, 6 stories.**

- **Stages 1–3 (ages 0–3)** built to good depth — the foundation band and highest daily use.
- **Stages 5, 6, 8, 10** seeded with representative items so every content *type* and every
  *design tier* (parent-led → encourage-effort → gamify-gently → grant-autonomy) is proven to
  fit the same schema, from a single-tap baby cause-and-effect lesson up to a first-Python lesson.

The estimated full library (6 lessons + 4 quizzes + 2 stories per subject, across all 57
stage-subjects) is **~684 items**. The seed locks the shape; the rest is authoring at volume.

## Design rules baked into the schema

Straight from the deck's "Design Principles" slide, and enforced by the validator:

- **No time pressure** — every item has `timed: false`. The validator rejects anything else.
- **Quizzes are retry-friendly** — each question carries both `correctFeedback` and a gentle
  `retryFeedback`; nothing is punitive, nothing is scored against a clock.
- **Reading gate** — `reading: false` for stages 1–4 (narrator / one-word UI); the validator
  warns if early-stage content sneaks in text.
- **Design tier** is derived from the stage so the UI knows whether to be parent-led, reward
  effort, gamify gently, or grant autonomy.
- **Offline + no external links** — every asset is a local `ref` (no URLs), and `parentNote`
  carries the cozy, real-world tie-ins for the 0–2 band.

## How to add content

Add objects to the `content` array following `_meta.itemSchema`. Minimum shape:

```json
{
  "id": "s04.math-logic.lesson.01",
  "stage": 4,
  "subject": "Math & Logic",
  "type": "lesson",
  "title": "...",
  "objective": "...",
  "designTier": "encourage-effort",
  "reading": false,
  "timed": false,
  "interaction": "drag",
  "assets": [{ "type": "image", "ref": "img/s04/...", "desc": "..." }],
  "steps": [{ "narration": "...", "action": "...", "feedback": "..." }]
}
```

`subject` **must** match a subject listed for that stage in `curriculum.stages` — the
validator cross-checks it, so content can't drift away from the plan.

Then run:

```bash
python validate_content.py            # must print "OK" before merge
python validate_content.py --assets   # hand the printed manifest to art & audio
```

## Notes / open questions for you

- **Existing schema:** if the one lesson/quiz/story already built in the app uses a different
  shape, send it and the whole library can be re-emitted to match — the authored content is
  independent of the field names.
- **Language:** content is in English, matching the deck (no Swahili content appeared in the
  slides). The structure localizes cleanly — narration/captions are plain strings.
- This advances the gate from "1 each built" to a real seeded library + a validated pipeline;
  reaching the full ~684 is then a content-team authoring effort, not an engineering one.
