# Watoto — Store Listing Kit (Gate 9)

> **⚠ Every "ages 0–10" below is stale and must be edited to "ages 0–7" before
> submission, in all three languages.** The build ships stages 1–7 only — see
> [V1_SCOPE.md](V1_SCOPE.md). This file is left at the curriculum's full range
> deliberately rather than half-rewritten: the copy is marketing text in EN/FR/SW
> and the age bands feed the store age-rating questionnaires, so it wants one
> pass by whoever owns marketing, not a search-and-replace. The affected fields
> are the promotional text, both short descriptions, the screenshot captions,
> and Google's **target age groups** (keep *Ages 5 & Under* and *6–8*, drop
> *9–10*).

Everything needed to fill in the App Store Connect and Google Play Console listings. Copy blocks are paste-ready and within each field's character limit; privacy answers are mapped to what Watoto actually collects (see `PRIVACY_POLICY.md`). Replace anything in [brackets]. Confirm final wording with whoever owns marketing/legal.

## Category and audience decision

List under **Education** as the primary category on both stores. Watoto spans Birth–Grade 4, which crosses every age band, so it does **not** fit Apple's single-band **Kids** category cleanly; staying in Education avoids that constraint while still meeting children's-privacy rules. On Google Play, opt into the **Designed for Families** program (the app meets its requirements: no ads, privacy policy, appropriate content). If you later target one band specifically, you can opt into Apple's Kids category with that band.

- Apple: Primary **Education**, Secondary **[Family / Lifestyle]**. Made-for-Kids: Education listing, privacy-compliant.
- Google: Category **Education**; Designed for Families: **Yes**; target age groups **[Ages 5 & Under, 6–8, 9–10]**.

## Apple App Store — metadata

| Field | Limit | Value |
|---|---|---|
| App Name | 30 | `Watoto: Learn & Grow` |
| Subtitle | 30 | `Birth to age 10, ad-free` |
| Promotional text | 170 | `A safe, ad-free learning world for ages 0–10 — lessons, quizzes, and stories in English, French, and Swahili. Works offline. Built for parents to trust.` |
| Keywords | 100 | `kids,learning,toddler,preschool,phonics,math,reading,educational,offline,french,swahili,children,ad-free` |
| Description | 4000 | *(see EN long description below)* |
| Support URL | — | `https://watoto.app/privacy` |
| Marketing URL | — | `[https://company]` |
| Privacy Policy URL | — | `https://watoto.app/privacy` |

## Google Play — metadata

| Field | Limit | Value |
|---|---|---|
| Title | 30 | `Watoto: Learn & Grow` |
| Short description | 80 | `Ad-free learning for ages 0–10 in English, French & Swahili. Works offline.` |
| Full description | 4000 | *(see EN long description below)* |

## Long description (English)

> Watoto is a calm, ad-free place for children from birth to age 10 to learn and grow. A complete curriculum across ten developmental stages mixes short interactive lessons, gentle no-pressure quizzes, and warm read-aloud stories — covering reading, math, science, social studies, creativity, and early coding.
>
> Built for parents to trust: no ads, no third-party tracking, no external links, and no timers or scores that pressure your child. Everything works offline, so learning travels anywhere. A simple parent area, behind a parent gate, lets you set up profiles, see progress, and manage everything.
>
> Every lesson, quiz, and story is available in English, French, and Swahili, with read-aloud audio and captions, and the content celebrates diverse characters and families.
>
> • Birth–Grade 4, ten stages that grow with your child
> • Lessons, quizzes, and stories — hundreds of activities
> • Three languages with audio and captions
> • Fully offline; private by design
> • No ads, ever
>
> Premium unlocks the full curriculum, offline downloads, and multiple child profiles. Subscriptions are managed by your app store and renew automatically unless cancelled.

## Localized metadata

**French**
- Title: `Watoto : apprendre et grandir`
- Subtitle (30): `Naissance à 10 ans, sans pub`
- Short description (80): `Apprentissage sans pub, 0–10 ans, en anglais, français et swahili. Hors ligne.`
- Long (short form): `Watoto Un espace calme et sans publicité où les enfants de 0 à 10 ans apprennent et grandissent : leçons interactives, quiz sans pression et histoires lues à voix haute, en lecture, maths, sciences, et premiers pas en code. Pensé pour rassurer les parents : aucune publicité, aucun pistage, aucun minuteur. Tout fonctionne hors ligne. Disponible en anglais, français et swahili, avec audio et sous-titres.`

**Swahili**
- Title: `Watoto: Jifunze na Ukue`
- Subtitle (30): `Kuzaliwa hadi miaka 10, bila matangazo`
- Short description (80): `Kujifunza bila matangazo, miaka 0–10, kwa Kiingereza, Kifaransa na Kiswahili.`
- Long (short form): `Watoto ni mahali tulivu, bila matangazo, ambapo watoto kuanzia kuzaliwa hadi miaka 10 hujifunza na kukua: masomo shirikishi, maswali bila shinikizo, na hadithi za kusomwa kwa sauti — kusoma, hisabati, sayansi, na misingi ya kupanga programu. Imeundwa ili wazazi waamini: hakuna matangazo, hakuna ufuatiliaji, hakuna saa za kubana. Hufanya kazi nje ya mtandao. Inapatikana kwa Kiingereza, Kifaransa na Kiswahili, ikiwa na sauti na manukuu.`

*(Fix the FR long-description opening word "Watoto" to "Watoto" — placeholder typo left visible so it isn't missed.)*

## Age rating

All content is non-objectionable; answer every violence/sexual-content/profanity/gambling/horror/mature-themes question with **None / No**.

- Apple result: **4+**.
- Google/IARC questionnaire → **Everyone** (ESRB) / **PEGI 3** / equivalent. Declares no ads, no user interaction beyond parent-managed account, no sharing of location.

## Apple App Privacy ("nutrition" labels)

**Data used to track you:** None. **Tracking (ATT):** the app does not track and does not use IDFA.

| Data type | Collected | Linked to user | Purpose |
|---|---|---|---|
| Contact Info — Email address | Yes (account holder) | Yes | App Functionality, Account Management |
| User Content — child nickname, learning progress | Yes | Yes | App Functionality |
| Usage Data — product interaction (aggregate) | [Optional] | Yes | Analytics (privacy-preserving) |
| Diagnostics — crash & performance, coarse region | [Optional] | Yes | App Functionality / Diagnostics |

No data is collected from children beyond the parent-created profile and progress; no precise location, contacts, photos, or advertising identifiers.

## Google Play — Data Safety form

- **Is data collected/shared?** Collected: yes. **Shared with third parties for their own use:** No. (Cloud hosting, payment, and crash reporting act as our processors, not for their own purposes.)
- **Is data sold?** No.
- **Encrypted in transit?** Yes.
- **Can users request deletion?** Yes — in-app parent area and [privacy@watoto.app]; deletion runbook in `PRIVACY_POLICY.md`.
- **Committed to Play Families policy?** Yes.

| Data type | Collected | Purpose | Optional? |
|---|---|---|---|
| Personal info — Email address | Yes | Account management, app functionality | Required |
| App activity — learning progress, in-app actions | Yes | App functionality; aggregate analytics | Progress required; analytics optional |
| App info & performance — crash logs, diagnostics | Yes | Stability | Optional |
| Device/other IDs | No | — | — |
| Location (precise) | No | — | — |

## Visual assets — specs

| Asset | Spec | Notes |
|---|---|---|
| App icon (Apple) | 1024×1024 PNG, no alpha | Friendly, distinctive; legible at small size |
| App icon (Play) | 512×512 PNG (32-bit) | Matches Apple icon |
| Play feature graphic | 1024×500 PNG/JPG | Required; tagline + brand |
| iPhone screenshots | 6.7" (1290×2796) and 6.5" (1242×2688) | Required set if those devices supported |
| iPad screenshots | 12.9" (2048×2732) | If iPad supported |
| Android phone screenshots | ≥ 1080×1920, 2–8 | |
| Android tablet screenshots | 7" and 10" | For Designed for Families quality |
| App preview video | 15–30s (optional) | Same shots as below |

## Screenshot shot-list (6–8 per device, localized EN/FR/SW)

1. **Hero** — a child mid-lesson, bright and warm. Caption: "A safe place to learn and grow, ages 0–10."
2. **Three ways to learn** — lesson, quiz, and story side by side. Caption: "Lessons, quizzes, and read-aloud stories."
3. **Three languages** — the same activity in EN/FR/SW with audio/caption. Caption: "Learn in English, French, and Swahili."
4. **Offline** — play with an airplane/offline badge. Caption: "Works anywhere — fully offline."
5. **Parent area** — progress and profile management behind the parent gate. Caption: "You're in control. See progress, set it up."
6. **Safe by design** — a calm 'no ads, no tracking' frame. Caption: "No ads. No tracking. Private by design."
7. **Grows with your child** — the ten-stage span Birth–Grade 4. Caption: "Ten stages that grow with your child."
8. *(optional)* **Representation** — diverse characters/families. Caption: "Stories that reflect every family."

Keep captions short, high-contrast, and translated per locale; show real in-app UI (store policies require screenshots to represent the actual app).

## What only you can do

Create the App Store Connect and Play Console listings (paid developer accounts: Apple [USD 99/yr], Google [USD 25 one-time]); upload the visual assets and screenshots; complete the age-rating and Data Safety/App Privacy forms with the answers above; set pricing and territories; and submit for review. The copy and answers here are ready to paste.
