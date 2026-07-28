# Watoto Playable Content Library

This is the **playable content** layer for the Watoto app — the gate that sits right after
"Curriculum plan in-app." The plan (`curriculum.pptx`) defined *what* to teach across 10
stages (Birth → Age 10). This library is the *actual playable material* the app loads:
lessons, quizzes, and stories, structured against that plan.

## Files

| File | What it is |
|------|------------|
| `watoto_content_library.json` | Source of truth. Curriculum taxonomy + **565** playable items + build plan. |
| `validate_content.py` | Schema + design-rule checker. Put it in CI. |
| `i18n/en.json`, `fr.json`, `sw.json` | Content string overlays (full coverage target). |
| `check_i18n.py` | Translation completeness gate (CI fails on missing keys). |
| `README.md` | This file. |

## What's in the library (v0.13.0)

**565 items: 342 lessons, 166 quizzes, 57 stories** across stages 1–10 (Birth → Grade 4).

- Full EN / FR / SW content strings (see `i18n/`).
- Design tiers from parent-led (0–2) through autonomy (older bands).
- Target full library remains ~**684** items (6 lessons + 4 quizzes + 2 stories per stage-subject).

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
