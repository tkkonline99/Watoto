# 26. Question Screen System

Every question, check, activity and story page in the child app renders on one
skeleton. This document is the contract. It supersedes the ad-hoc layouts in
`library_play_screen.dart` and the stage widgets it drives.

## 26.1 Why

The picture a child sees is **guessed from the narration text**, not declared by
the author. `step_visuals.dart` runs a four-rung ladder — a lexicon word in the
narration, then a topic keyword, then a keyword in the item's title, then the
item's subject — and whatever falls out is what renders. Nothing checks that the
result has anything to do with the question, and nothing gives it a defined
place on screen.

The result in the field, traced end to end: `s10.science.lesson.05` ("Changes
of Matter") closes with the step *"Put a lid on a pan of hot water and watch
where the drops form."* The ladder's first rung takes the first lexicon word in
reading order, that word is **lid**, and `content_lexicon.dart` maps `'lid'` to
🥫 — a tin of food. So a condensation activity renders a tin, and it does so
deterministically, every time, in all three languages.

Nothing is malfunctioning. The ladder is doing exactly what it was written to
do; it was simply never told what the step is *about*. Meanwhile roughly half
the screen sits empty above the content, because the column is centred in
whatever space the prompt does not use.

Two separate faults:

1. **No contract on the visual.** The author never states what the picture
   should be, so any glyph the ladder produces passes review because nothing
   defines what a correct one is.
2. **No contract on the layout.** The visual has no reserved space, so screens
   with little content collapse into a void and screens with a lot of content
   crowd.

The ladder is not being deleted — it stays as the fallback for anything not yet
migrated, and it is genuinely good at what it does. It is being demoted from
*the* source of the picture to the last resort behind a declared one.

## 26.2 The skeleton

Six parts, always this order, always these proportions. A screen may shrink the
stage; it may never remove it.

| # | Part | Rule |
|---|---|---|
| 1 | Chrome | Back top-left, title centred, audio-repeat top-right. Never moves (docs/08 §8.1.4). |
| 2 | Progress | Dots for lesson steps, `n of m` for quizzes. Streak chip sits right when a streak is active. |
| 3 | **Stage** | Fixed height. Default 300dp; 180dp on text-heavy screens (comprehension, story). Rounded 24dp, white or the striped placeholder. |
| 4 | Prompt | One sentence. Baloo 2 800, 21–26sp, centred, wrapped for balance. The prompt names what the stage shows; it does not repeat it. |
| 5 | Response zone | Anchored to the bottom of the flex column, above the assist line. Tiles, bins, ordering rail, or a single pill. |
| 6 | Assist line | What to do next, or the audio-repeat offer. Sky blue, 14–15sp, 700. Never a scold. |

Vertical slack collects between the prompt and the response zone, so a sparse
screen breathes rather than leaving a hole at the top.

## 26.3 Three ways to fill the stage

Authors pick exactly one. There is no fourth option and no empty stage.

### `token`
A vetted glyph on a tinted disc, 150dp. Only legitimate when the concept is a
single nameable object — a mango for /m/, ice/water/steam for states of matter.
Tokens come from `content/visual_tokens.json` and must be registered against the
item's skill. Free-text glyphs are rejected at validation.

### `scene`
Composed shapes that encode the maths or the structure: counting arrays,
base-ten columns, fraction bars, an outlined glyph with start and end markers, a
waveform for an audio prompt, a sentence card on deep ground. Scenes are built
from the primitives in `core/widgets/stages/` — no bitmap needed, so they
localise and scale for free. Prefer a scene over a token whenever the question is
about quantity, structure, order or relationship.

### `slot`
A framed brief for commissioned art. Ships as a striped placeholder carrying the
brief text, so an unfinished asset is visibly unfinished instead of silently
wrong. Use when the question depends on a real-world situation a glyph cannot
carry — condensation in a pan, a market before sunrise, a savanna food chain.

## 26.4 Band variations

Same skeleton throughout; the parameters change.

| Band | Targets | Choices | Text | Notes |
|---|---|---|---|---|
| 0–2 Discover | 132dp | 2 | Decorative — audio is the question | No fail state; every tap is acknowledged |
| 3–5 Explore | 88dp | 3 | Prompt narrated, answers may be glyphs | Tracing has no scoring and no timer |
| 6–8 Build | 88dp tiles / full-width rows | 3–4 | Text carries meaning | Parent-led activities gain the step strip (§26.5) |
| 9–10 Master | Full-width rows | 3–4 | Andika 18–19sp | Deeper palette, playful chrome recedes |

Bands map to the item's `stage`, which is 1–10 in the library — band "0–2" is
stages 1–2, "3–5" is stages 3–5, and so on.

## 26.5 Parent-led activities

Activities that happen away from the screen carry three extra elements:

- a **GROWN-UP NEEDED** chip in the assist line;
- a **three-step strip** between prompt and response — heat / cover / look —
  each step a numbered chip with three or four words. This is what fills the
  space the old layout left blank, and it is the part a parent actually reads;
- a completion pill in the child's voice ("We did it"), never a correctness
  claim.

The activity copy itself is authored text and is never rewritten by the client.

## 26.6 Rules that hold everywhere

- No timed interactions (docs/11 §11.5, enforced by `validate_content.py`).
- Colour never carries an answer alone — the fraction bars differ in length as
  well as hue; the sorting bins differ in border style as well as colour.
- Correct is `accent.leaf` with a pop; retry is `accent.berry` with a wiggle
  that reverts after one second. Never red, never a cross.
- Every stage has an `alt` string, read by TalkBack/VoiceOver and reused as the
  art brief.
- Reduced motion drops pop, wiggle and star burst; state changes remain visible
  through colour and border weight.
- A labelled `Semantics` wrapping a tappable stage puts `ExcludeSemantics`
  around the child *inside* the tap target, never `excludeSemantics: true` on
  the `Semantics` itself — the short form silently drops the tap action
  (docs/08, and the accessibility notes in `subject_island.dart`).

## 26.7 Implementation notes

The live player is `LibraryPlayScreen` (`/play/:id`), driven by `LibraryItem`
from `content/watoto_content_library.json`. The rendered parts are
`LessonStep`, `LibQuestion` and `LibPage` — those are what gain a visual:

```dart
sealed class Visual {
  const Visual({required this.alt});
  final String alt;
}
class TokenVisual extends Visual { final String ref; }  // key in visual_tokens.json
class SceneVisual extends Visual { final String ref; }  // maps to a widget builder
class SlotVisual  extends Visual { final String ref; }  // image asset, striped fallback
```

`LibPage.illustration` is the existing slot field and keeps working: a page
without an explicit `visual` is read as `SlotVisual(ref: illustration)`. Story
art therefore migrates without retyping 594 pages.

`QuestionScaffold` owns parts 1–3 and 6; the stage widgets supply only the
prompt and the response zone. That is what keeps the skeleton honest.

Where an item has no declared visual, the `step_visuals.dart` ladder still
runs, so nothing regresses mid-migration. The validator lands with
`strict=False` and warns; it flips to an error once the library is clean.

### A note on the legacy player

`lesson_player_screen.dart` and `quiz_runner_screen.dart` implement an older
`watoto.lesson/1.0` schema (`LessonBody` / `ConceptBlock.emoji`), read two
sample packs in `assets/content/`, and are reachable only by typing
`/lesson/:slug` or `/quiz/:slug` — no screen in the app links to them. They are
out of scope for this contract. `ConceptBlock.emoji` is the free-text glyph
field this document was originally written against; it exists only there, and
no item in the content library has an `emoji` field at all.
