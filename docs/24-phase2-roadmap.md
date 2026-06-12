# 24. Phase 2 Roadmap (Months 7–14)

Theme: widen the age funnel, light up AI safely, open the school channel, complete trilingual promise.

## Wave 1 (M7–M9) — Bands & Language Completion

- **0–2 band** ("Discover"): audio-first UI variant, giant-card home, parent-guided mode; 250-lesson content set (lighter items, heavy VO).
- **9–10 band** ("Master"): deeper subjects (history, ICT incl. block coding, creative writing sandbox), 250-lesson set.
- **French** full localization (UI done early in wave; curriculum translation + VO through the wave) → all four translation directions live with vocabulary decks.
- **Child web app** enabled (drift-wasm offline subset, no large video packs).
- Certificates (PDF pipeline) + avatar shop economy expansion.

## Wave 2 (M9–M11) — AI Features (consent-gated, staged)

1. **Parent Insights AI** first (lowest risk, no child interaction) — weekly summaries.
2. **Reading Coach**: EN first (best STT coverage), then FR; SW in beta with phoneme-distance fallback; voice-consent UX, 30-day purge verified.
3. **AI Tutor**: closed beta cohort (opt-in families) → safety-eval telemetry review → GA with per-day caps and parent transcript visibility.
- Adaptive engine upgrade: BKT parameters fitted from accumulated attempt data; placement checks; spaced-review surface.

Gate for each AI GA: prompt eval suite 100% pass on 2 consecutive weekly runs in production shadow mode + DPIA addendum signed off.

## Wave 3 (M11–M14) — Schools & Social

- **Teacher module**: groups, join-code + parent approval, assignments, class analytics, CSV export (FERPA controls audited). Pilot with 10 schools (Kenya/Tanzania focus) before GA.
- **Leaderboards** (parent-approved, sharded cohorts) + family/class challenges.
- **Learning clubs** (teacher-moderated, reaction-only) — behind feature flag, pilot-only.
- School licensing plan (site licenses, invoice billing via Stripe) added to billing.

## Continuous Tracks

| Track | Items |
|---|---|
| Content | +60 lessons/month/locale-equivalent; seasonal packs; story library to 200+ |
| Platform | EU region deployment option (GDPR data-residency), Play Integrity/App Attest, performance budget automation |
| Growth | referral program (parent-to-parent, compliant — no child-facing virality), school ambassador kit |
| Monetization | regional pricing (PPP-adjusted for East/West Africa), family plan (up to 4 children — already supported by model), annual-gift cards |

## Phase 2 Exit Criteria

- All four age bands live with ≥250 lessons each; EN/SW/FR parity ≥90% of catalog.
- AI features GA with zero unresolved safety incidents and tutor cost <$0.04/DAU/day.
- 25+ paying schools; teacher NPS ≥40.
- Platform: p95 API <300 ms at 50k DAU; infra cost <$0.06/DAU/month.
