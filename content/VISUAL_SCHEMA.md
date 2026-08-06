# Visual schema addition

Adds a required `visual` object to every rendered step, question and story
page. See `docs/26-question-screen-system.md` for the design rationale.

The library is **684 items** — 342 lessons, 228 quizzes, 114 stories — carrying
**3,556 rendered parts**: 2,230 steps, 732 questions, 594 story pages. That is
the size of the migration, and it is why the visuals are authored by script
(`author_visuals.py`) rather than by hand.

## Item shape

```json
{
  "id": "s08.science.lesson.05",
  "stage": 8,
  "subject": "Science",
  "type": "lesson",
  "skills": ["science", "science.weather"],
  "steps": [
    {
      "narration": "It cools into clouds, then falls as rain.",
      "action": "tap",
      "feedback": "Evaporate, condense, precipitate. The water cycle.",
      "visual": {
        "mode": "slot",
        "ref": "img/s08/water_cycle.png",
        "alt": "Water cycle diagram with sun, cloud and falling rain"
      }
    }
  ]
}
```

## Field rules

| Field | Rule |
|---|---|
| `mode` | One of `token`, `scene`, `slot`. Required. |
| `ref` | `token`: a key in `visual_tokens.json`. `scene`: a registered scene builder id. `slot`: an image path under `apps/mobile/assets/images/`. Required. |
| `alt` | Free text, ≥ 4 words. Doubles as the screen-reader label and the art brief. Required. |

A `token` ref is only valid if `visual_tokens.json` lists at least one of the
item's `skills[]` (or its `subject`) under that token's `for` array. This is
what stops a tin of food landing on a condensation activity: the glyph is not
registered for `science.weather`, so the build fails.

## The `skills[]` field

Token gating is only as good as the skill it gates on, and **no item in the
library had `skills[]`** — the field is introduced by this change, authored by
`content/author_skills.py`.

Each item gets two entries, coarse then fine:

```json
"skills": ["science", "science.matter"]
```

- The **domain** is the topic segment already encoded in every item id
  (`s08.`**`science`**`.lesson.05`). It maps 1:1 onto subject, so it is a
  restatement of existing structure rather than a new judgement.
- The **fine skill** is classified from the item's title and objective by
  keyword — `Ice and Water` and `States of Matter` are both `science.matter`,
  `Food Chains` and `Habitats` are both `science.ecosystems`.

Two levels lets the registry choose its own tightness. A glyph that suits any
science item registers `for: ["science"]`; one that only makes sense for matter
registers `for: ["science.matter"]` and is rejected everywhere else. An item
whose title matches no rule gets the domain alone, which is honest — it says
"we know the subject, not the sub-skill" rather than inventing one.

Subjects remain valid in a `for` array, so a token can also be gated the coarse
way (`for: ["Colors & Shapes"]`) without any skill at all.

## Token registry

`content/visual_tokens.json` is the whole vocabulary of legal glyphs. Adding a
token is a reviewed change, not an authoring convenience.

```json
{
  "_meta": { "version": "1.0", "note": "Vetted glyphs. A token is legal only for the skills listed in its 'for' array." },
  "tokens": {
    "mango":      { "glyph": "🥭", "for": ["reading.phonics", "math.counting"] },
    "ice":        { "glyph": "🧊", "for": ["science.matter"] },
    "water.drop": { "glyph": "💧", "for": ["science.matter", "science.weather"] },
    "cow":        { "glyph": "🐄", "for": ["science.animals", "vocab"] }
  }
}
```

The glyphs are drawn from the vocabulary `content_lexicon.dart` already knows
how to render, so a registered token is guaranteed to be a glyph the app can
actually draw.

## Migration

`author_visuals.py` chooses a mode per part from signals the content already
carries, in this order:

1. a story page's existing `illustration` → `slot` with that ref;
2. a step with `figures[]` (drawn answer options) → the matching `scene`;
3. a step or question whose skill has a registered scene (counting, fractions,
   place value, tracing, sentence work) → that `scene`;
4. a concrete noun the lexicon recognises, registered for the item's skill →
   `token`;
5. otherwise → `slot`, with the alt text as the art brief, rendering as the
   striped placeholder until someone draws it.

Rule 5 is the honest default: it makes an unmade picture visibly unmade instead
of silently substituting a wrong one. The validator lists every part that lands
there, so the art backlog is a query rather than an audit.
