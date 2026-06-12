# 10. Wireframes (low-fi, annotated)

Conventions: `[ ]` tappable, `( )` toggle/state, `~~` illustration/animation area, 🔊 = auto-narrated element.

## 10.1 Child Home (6–8 band)

```
┌────────────────────────────────────────────┐
│ [👤 avatar]   Jambo, Amani! 🔊    [🔥 4]   │  ← streak chip; avatar = profile switch (PIN-free, family only)
│                                            │
│   ~~ Kibo mascot idle animation ~~         │
│                                            │
│ ⭐ Daily Challenge ───────────────────────┐ │
│ │ [ 3 fun tasks today!  ▶ Start ] 🔊     │ │
│ └──────────────────────────────────────── ┘ │
│                                            │
│  Subject Islands (horizontal scroll)       │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌──────┐  │
│ │ ~math~ │ │ ~eng~  │ │ ~sci~  │ │ 🔒art│  │ ← lock = premium; ring = unit progress
│ │ ◔ 64%  │ │ ◑ 40%  │ │ ○ new  │ │      │  │
│ └────────┘ └────────┘ └────────┘ └──────┘  │
│                                            │
│ From your teacher ▸ (only if linked)       │
│ ┌──────────────────────────────────────┐   │
│ │ 📋 Fractions quiz — due Friday       │   │
│ └──────────────────────────────────────┘   │
│                                            │
│ [🏠 Home] [📚 Stories] [🎮 Games] [🏆 Me]  │  ← shell tabs, 64dp, icons+labels+audio
└────────────────────────────────────────────┘
```

0–2 band variant: no tabs, no text dependence — full-screen carousel of 4 giant cards (Colors, Sounds, Animals, Music), each auto-narrating on focus; parent-handed-device assumption.

## 10.2 Lesson Player

```
┌────────────────────────────────────────────┐
│ [←]      ● ● ● ○ ○      [🔊 repeat]        │  ← progress dots; back = confirm sheet
│                                            │
│        ~~ block content area ~~            │
│     "Count the mangoes!" 🔊                │
│      🥭   🥭   🥭                          │
│   (tap each mango — it counts aloud)       │
│                                            │
│            [ 1 ] [ 2 ] [ 3 ]               │  ← answer tiles, 64dp
│                                            │
│ ~Kibo~  (reacts: thinking → cheering)      │
└────────────────────────────────────────────┘
Completion overlay: StarBurst Lottie, "+10 XP ⭐", [▶ Next lesson] [🏠]
```

## 10.3 Story Reader

```
┌────────────────────────────────────────────┐
│ [←]   The Clever Hare        [Aa] [🔊]     │  ← Aa = text size/dyslexia font; 🔊 = narration toggle
│                                            │
│   ~~ full-bleed illustration ~~            │
│                                            │
│  Hare ran fast. The sun was hot. 🔊        │  ← karaoke word-highlight follows narration
│  ────                                      │
│                                            │
│ [🎤 Read it myself]        [◀ pg 3/12 ▶]  │  ← mic only if voice consent granted
└────────────────────────────────────────────┘
```

## 10.4 Quiz Runner & Results

```
┌──────────────────────────────┐  ┌──────────────────────────────┐
│ [←]  Q 2 / 5     ⏱ off       │  │      🎉 Great job! 🔊         │
│ Which shape is a circle? 🔊  │  │   ~Kibo cheering~            │
│ ┌─────┐ ┌─────┐              │  │   Score: 4/5  ⭐⭐⭐⭐         │
│ │ ▲   │ │ ●   │              │  │   +20 XP  +2 coins           │
│ └─────┘ └─────┘              │  │   New badge: Shape Finder!   │
│ ┌─────┐ ┌─────┐              │  │ [▶ Next]  [↻ Try again] [🏠] │
│ │ ■   │ │ ★   │              │  └──────────────────────────────┘
│ └─────┘ └─────┘              │   Fail state: same warmth,
└──────────────────────────────┘   "So close! Let's practice ▶" → easier variant
```

## 10.5 Parent Dashboard

```
┌────────────────────────────────────────────┐
│ Parent Zone                    [⚙] [👋 out]│  ← entered via PIN gate
│ Children:  (● Amani) ( Zuri ) [+ Add]      │
│                                            │
│ This week — Amani                          │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│ │ 86 min  │ │ 12 ✓    │ │ 🔥 4    │        │
│ │ time    │ │ lessons │ │ streak  │        │
│ └─────────┘ └─────────┘ └─────────┘        │
│ Mastery by subject     ▁▃▅▇ charts         │
│ 💡 AI Insight: "Amani is strong in         │
│ counting; try measurement next." [more]    │
│                                            │
│ [Set goals] [Screen time] [Reports]        │
│ [Leaderboard approval (off)]               │
│ [Subscription: Premium ✓] [Privacy & data] │
└────────────────────────────────────────────┘
```

## 10.6 Paywall (parent-gated)

```
┌────────────────────────────────────────────┐
│        Unlock all of Watoto 🦁             │
│  ✓ Full curriculum (1000+ lessons)         │
│  ✓ AI Tutor & Reading Coach                │
│  ✓ Unlimited stories & downloads           │
│  ✓ Advanced parent reports                 │
│ ┌──────────────────┐ ┌───────────────────┐ │
│ │ Monthly  $7.99   │ │ Annual  $59.99    │ │
│ │                  │ │ SAVE 37% ★best    │ │
│ └──────────────────┘ └───────────────────┘ │
│ [    Continue    ]   Restore purchases     │
│ Cancel anytime · No ads ever · COPPA-safe  │
└────────────────────────────────────────────┘
```

## 10.7 Teacher Dashboard (web/tablet)

```
┌──────────────────────────────────────────────────────┐
│ Watoto Teach   Groups ▾   Assignments   Analytics    │
│ Grade 2 — Blue (code: KIBO-42) 18 students           │
│ ┌ Assignment: Fractions intro — due Fri ┐            │
│ │ done 11 / in progress 5 / not started 2 │           │
│ └──────────────────────────────────────┘             │
│ Skill heatmap (class × skill)  [export CSV]          │
│ ▦▦▦▢▢ counting   ▦▦▢▢▢ fractions  ▦▦▦▦▢ shapes      │
│ [+ New assignment] [+ New group]                     │
└──────────────────────────────────────────────────────┘
```

## 10.8 CMS — Lesson Builder (admin web)

```
┌──────────────────────────────────────────────────────┐
│ CMS ▸ Lessons ▸ counting-1-10        status: DRAFT   │
│ ┌ Blocks (drag to reorder) ┐  ┌ Block editor ──────┐ │
│ │ 1 intro_animation        │  │ type: tap_to_count │ │
│ │ 2 concept                │  │ items: [3]         │ │
│ │ 3 ► tap_to_count         │  │ successAudio: [▾]  │ │
│ │ 4 check                  │  │ [preview ▶]        │ │
│ │ [+ add block]            │  └────────────────────┘ │
│ ├ Translations: EN ✓ SW ✓ FR ⚠ missing 2 keys       │
│ ├ Media: 3 assets (all moderated ✓)                  │
│ └ [Save] [Send to review] [Publish ▸ requires role]  │
└──────────────────────────────────────────────────────┘
```
