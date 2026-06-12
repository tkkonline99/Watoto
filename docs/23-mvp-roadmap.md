# 23. MVP Roadmap (Months 1–6)

## MVP Scope Decision

**In**: parent onboarding + consent, child profiles, ages **3–5 and 6–8** bands, EN fully + SW UI, lessons/quizzes/stories/flashcards + 4 built-in game engines, offline downloads + sync, core gamification (XP/stars/coins/badges/streaks), parent dashboard (reports v1, screen time), subscriptions (all 3 providers), CMS (lesson/quiz/story/flashcard/media/translation), accessibility AA baseline.

**Out (Phase 2)**: 0–2 and 9–10 bands, French, AI Tutor & Reading Coach (ship adaptive engine *rules core* only), teacher module, leaderboards/clubs, certificates PDF, web app for children (web ships parent dashboard + CMS only at MVP).

Rationale: 3–8 is the engagement sweet spot and halves content volume; AI features carry the heaviest compliance/safety load and land better on a stable base; teacher features need school pilots anyway.

## Team (8.5 FTE)

1 PM/owner · 1 designer (UX+illustration direction) · 2 Flutter · 2 backend · 1 content lead + 2 content authors (contract) · 0.5 DevOps · 0.5 QA (ramping to 1 from M3) · compliance counsel (external, milestones).

## Sprint Plan (2-week sprints)

| Sprint | Engineering | Content/Design |
|---|---|---|
| 1–2 (M1) | Monorepo, CI skeleton, Terraform dev env, NestJS scaffold (auth, accounts), Flutter scaffold (flavors, router, theme tokens), Firebase projects | Design system v1, mascot concept, curriculum outline 3–5 & 6–8 |
| 3–4 (M2) | Curriculum/content schema + CMS lesson builder v1, catalog API + cached reads, lesson player block engine (5 block types), drift/Hive offline base | First 30 lessons authored in CMS (dogfood the builder), VO pipeline setup |
| 5–6 (M3) | Quiz builder + runner + server grading, rewards ledger + streaks + badges engine, sync queue + `/sync/batch` + LWW, download manifests + DownloadManager | 100 lessons, 40 quizzes, design QA pass, SW translation start |
| 7–8 (M4) | Story builder + reader (narration, word highlight), flashcards + SRS, parent dashboard v1, screen time, consent flows end-to-end | 200 lessons, 20 stories, 80 flashcard decks; accessibility audit round 1 |
| 9–10 (M5) | Billing: Stripe + Play + Apple, entitlements, paywall; games ×4 engines; adaptive rules core (difficulty governor + next-item) | Content freeze for launch set: 350 lessons, 140 quizzes, 60 stories EN + SW UI complete |
| 11–12 (M6) | Hardening: load tests, pen test + fixes, store submissions, staged rollout, observability dashboards, runbooks | Marketing site, store assets, beta family program (50 families) feedback fixes |

## Milestones & Gates

- **M2 end** — "walking skeleton": one lesson authored in CMS plays on device from the real API. *Gate: architecture review.*
- **M3 end** — offline lesson→quiz→reward loop works in airplane mode. *Gate: sync property tests green.*
- **M4 end** — closed alpha (team families, TestFlight/internal). *Gate: consent + deletion pipeline demo to counsel.*
- **M5 end** — beta with payments in sandbox; content launch set frozen. *Gate: entitlement matrix tests green; a11y AA pass.*
- **M6 end** — **public launch** both stores + parent web. *Gate: launch checklist ([25](25-launch-plan.md)).*

## MVP Success Metrics (first 90 days post-launch)

| Metric | Target |
|---|---|
| Activation (child completes 3 lessons in week 1) | ≥45% |
| W4 retention (families) | ≥25% |
| Free→paid conversion | ≥4% |
| Crash-free sessions | ≥99.6% |
| Sync failure rate | <0.5% of batches |
| Safety incidents | 0 (any = all-hands postmortem) |

## Top Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Content production slips (most common failure for edu apps) | CMS ships M2 so authoring parallelizes 4 months; launch set scoped to 2 bands; weekly content burn-up chart |
| Store rejection (Kids/Families) | Checklists from day 1; pre-submission review with a store-compliance consultant in M5; parental gate and no-links rules enforced by lint |
| IAP edge cases | Dedicated webhook fixture suite + nightly reconciliation from M5 |
| Offline sync bugs | Property-based tests from first sync commit; sync engine owner assigned |
