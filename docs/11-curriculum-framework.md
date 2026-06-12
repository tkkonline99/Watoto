# 11. Curriculum Framework

## 11.1 Hierarchy

```
Subject → Course (subject × age band) → Unit (theme) → Lesson → inline checks
                                              ├ Quiz (unit & lesson level)
                                              ├ Flashcard deck
                                              ├ Game
                                              └ Activity
Stories sit parallel, tagged by age band + reading level (1–6) + skills.
```

Every lesson/question carries `skills[]` tags (taxonomy below) — the connective tissue for mastery tracking, adaptive paths, badges, and teacher heatmaps.

## 11.2 Skill Taxonomy (excerpt)

Dot-namespaced, locale-independent: `counting.1-10`, `counting.11-20`, `addition.single-digit`, `phonics.cvc`, `phonics.blends`, `reading.sight-words.l1`, `shapes.basic`, `shapes.3d`, `science.living-things`, `grammar.tenses.past`, `swahili.vocab.family`, `french.vocab.colors`, `ict.typing.home-row`, `writing.sentence`, `writing.paragraph`.

## 11.3 Content Volume Targets

| Per age band | Lessons | Quizzes | Flashcards | Games | Activities | Stories |
|---|---|---|---|---|---|---|
| Minimum (launch) | 250 | 100 | 200 | 50 | 100 | 50 |

Platform totals: **1,000+ lessons · 500+ quizzes · 800+ flashcards · 200+ games · 200+ stories**, every item in EN/SW/FR (text + narration audio). Free tier: first 2 units per course + 10 stories per band; remainder premium.

## 11.4 Syllabus by Age Band

### 0–2 Discover (audio-first, tap-anything, no fail states, sessions ≤5 min)
| Subject | Units (examples) |
|---|---|
| Colors | Meet the colors · Colors around us · Color sounds |
| Shapes | Circle & friends · Shape hunt |
| Animals | Farm · Safari · Animal sounds orchestra |
| Numbers 1–10 | Count with Kibo · Fingers & toes |
| Alphabet recognition | Letter parade A–M · N–Z · My name's letter |
| Sounds & Music | Loud/quiet · Clap the beat · Lullabies |
| Basic vocabulary | My body · My family · Things at home |

### 3–5 Explore (phonics-led literacy + numeracy readiness)
Alphabet & letter formation (tracing games) · Phonics (letter sounds → CVC blending → sight words L1) · Reading readiness (print concepts, rhyme) · Counting to 50, comparing, simple add/take-away with objects · Shapes & patterns · Nature & seasons · Social skills (sharing, feelings, helping) · Creativity (color, build-a-story, music maker).

### 6–8 Build (curriculum-aligned foundations)
Mathematics (place value, +/− to 1000, intro ×/÷, fractions ½ ¼, measurement, time, money, data pictographs) · English (reading comprehension, grammar basics, spelling, writing sentences→paragraphs) · Science (living things, habitats, materials, weather, simple machines, human body) · Social Studies (community, citizenship) · Geography (continents, maps, my country) · Art & Music (elements, rhythm, famous works) · Computer Basics (parts, mouse/touch skills, internet safety for kids).

### 9–10 Master (upper primary depth)
Mathematics (multi-digit ×/÷, fractions & decimals, geometry, perimeter/area, word problems) · English Grammar (tenses, clauses, punctuation, comprehension strategies) · Creative Writing (narrative, descriptive, letters, poetry — sandboxed editor) · Science (ecosystems, energy, matter, space, scientific method) · Geography (climate, landforms, Africa & world regions) · History (ancient civilizations, national history, great inventions) · Social Studies (government basics, economy for kids) · ICT (typing, files, spreadsheets intro, online safety, block coding).

### Language tracks (all bands, per locale)
Swahili and French as *subjects* too (not only UI locales): vocabulary ladders, pronunciation drills (Reading Coach), translation flashcards aligned to the four directions EN↔SW, EN↔FR.

## 11.5 Lesson Design Template (authoring standard)

| Section | Rule |
|---|---|
| Hook | ≤20 s animation/question connecting to child's world |
| Teach | 1 concept only; concrete visual + narration; ≤3 new vocabulary items |
| Try | 2–4 guided interactions with instant audio feedback |
| Check | 1–3 inline questions tagged to the lesson's skills |
| Celebrate | reward grant + forward link |
| Length | 0–2: ≤3 min · 3–5: ≤5 min · 6–8: ≤8 min · 9–10: ≤10 min |

Quiz standard: 5–10 questions, ≥2 question types, distractors plausible-not-tricky, pass 70%, every question has audio prompt + (for <6) audio options.

## 11.6 Localization Workflow

1. Author in English in CMS → keys auto-generated.
2. Translation Manager shows missing-key matrix per locale; translators work in CMS or via XLIFF round-trip.
3. Narration: human VO for stories + praise lines; TTS (reviewed) for long-tail lesson text; all audio attached to translation keys.
4. Cultural review pass per locale (names, foods, imagery localized — e.g., mangoes not blueberries) before `approved`.
5. A course can publish per-locale: EN may ship while SW/FR are `in_review` (client falls back to EN with parent-visible notice).

## 11.7 Authoring Pipeline & Pacing

Curriculum specialist writes outline → content author builds in CMS → internal review (pedagogy + safety checklist) → moderation approval → publish. Throughput assumption for roadmap: a 4-person content team produces ≈60 lessons + assets/month/locale-equivalent; launch volume therefore staged (see [MVP Roadmap](23-mvp-roadmap.md)) with EN-complete first, SW/FR fast-follow.
