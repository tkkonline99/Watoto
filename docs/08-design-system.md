# 8. UI/UX Design System — "Savanna"

Design language built around a friendly safari world. Mascot: **Kibo the lion cub** (Rive-animated, reacts to progress). Tone: warm, encouraging, never punitive — errors are "let's try again!" moments.

## 8.1 Design Principles

1. **Audio-first under 6** — every interactive element speaks its label; pre-readers never depend on text.
2. **One primary action per screen** in child surfaces; no nested menus for children.
3. **Big, forgiving touch** — min target 48dp (6–10), 64dp (3–5), 88dp (0–2); generous hit slop.
4. **Predictable layout** — back button always top-left, audio-repeat always top-right, Kibo bottom-left for help.
5. **Calm by default** — animation celebrates completion, never distracts during tasks; no flashing >3 Hz, `prefers-reduced-motion` respected.
6. **Parent/teacher surfaces are standard Material 3** — dense, data-forward, not playful.

## 8.2 Color Tokens

| Token | Hex | Use |
|---|---|---|
| `primary.sun` | `#FFB703` | Primary actions, highlights |
| `primary.sky` | `#219EBC` | Child app bars, links (parent) |
| `primary.deep` | `#023047` | Text on light, parent surfaces |
| `accent.mango` | `#FB8500` | Rewards, streaks |
| `accent.leaf` | `#52B788` | Success, correct answers |
| `accent.berry` | `#E76F51` | Gentle "try again" (never harsh red) |
| `surface.cloud` | `#FDF6EC` | Child background (warm, low glare) |
| `surface.card` | `#FFFFFF` | Cards |
| `hc.*` | — | High-contrast alternates, all pairs ≥7:1 |

Per-age accents: 0–2 soft pastels of the above; 3–5 full saturation; 6–8 cooler mix; 9–10 deeper "grown-up" variants. All text/background pairs meet **WCAG 2.2 AA (≥4.5:1)**; AAA targeted for body text in child reading surfaces.

## 8.3 Typography

| Role | Font | Sizes |
|---|---|---|
| Child display/UI | **Baloo 2** (rounded, friendly, true a/g letterforms) | 32/24/20 |
| Child reading text | **Andika** (literacy-optimized) | 22–28, line-height 1.6 |
| Dyslexia mode | **OpenDyslexic** (user toggle, swaps reading font) | same scale |
| Parent/teacher/CMS | **Inter** | Material 3 type scale |

Text scaling supported 100–200% without clipping (golden tests enforce); child UI clamps at 160% with reflow.

## 8.4 Spacing, Shape, Elevation

- 8dp grid; spacing tokens 4/8/12/16/24/32/48.
- Corner radius: child 24dp (cards) / 32dp (buttons, pill); parent 12dp.
- Elevation: flat + soft shadows (y2 blur8 @8% deep navy); no harsh borders.

## 8.5 Core Components (`core/widgets/`)

| Component | Notes |
|---|---|
| `WatotoButton` | pill, icon+label+auto-audio on focus/long-press, pressed squash animation |
| `SubjectIsland` | home-screen subject entry: illustration, progress ring, lock state |
| `LessonBlockScaffold` | consistent frame for lesson blocks: progress dots, audio-repeat, back |
| `AnswerTile` | tap target with correct (leaf bounce + chime) / retry (berry wiggle) states |
| `ProgressRing` / `XPBar` | reward visuals |
| `MascotWidget` | Rive state machine: idle/cheer/think/sleep, drives encouragement |
| `StarBurst` | Lottie celebration on completion |
| `PinPad` | parent gate, with "ask a grown-up" copy + math fallback challenge |
| `ReportCard` | parent dashboard stat tiles & charts |

## 8.6 Motion & Audio

- Durations: micro 150 ms, transitions 300 ms, celebrations ≤2 s and skippable.
- Rive for mascot + interactive lesson animations; Lottie for one-shot celebrations.
- Audio layers: narration (priority, ducks others), SFX (≤ -12 dB vs narration), optional ambient music (off by default 6+, parental toggle). Praise lines recorded per locale (8 variants rotated to avoid monotony).

## 8.7 Accessibility Checklist (per screen, enforced in review)

- [ ] Semantics labels on all interactives (screen readers: TalkBack/VoiceOver)
- [ ] Focus order logical; visible focus ring on web/keyboard
- [ ] Contrast AA verified in both themes
- [ ] Captions for all video; transcripts for audio lessons
- [ ] Voice-navigation labels unique on screen
- [ ] Works at 200% text scale (parent) / 160% (child)
- [ ] No timed interactions without "no-timer" alternative
- [ ] Reduced-motion variant verified
