# 25. Production Launch Plan

## 25.1 Launch Gates (all must be green — single go/no-go meeting, T-7)

| # | Gate | Owner | Evidence |
|---|---|---|---|
| 1 | Security: external pen test findings (high/critical) closed | DevOps | report + retest |
| 2 | Compliance: counsel sign-off on privacy policy, consent text, DPIA; deletion + retention jobs demoed | PM | sign-off doc |
| 3 | Stores: both apps approved (or in final review with no flags) | Mobile lead | store status |
| 4 | Billing: live-mode purchase/cancel/refund verified on all 3 providers | Backend lead | test log |
| 5 | Quality: crash-free ≥99.6% across beta; release-blocker count = 0 | QA | dashboards |
| 6 | Load: k6 targets met on prod-sized staging; autoscaling observed | DevOps | k6 report |
| 7 | Content: launch catalog published, zero missing EN translations, moderation queue empty | Content lead | CMS dashboard |
| 8 | A11y: AA manual pass (TalkBack/VoiceOver/keyboard/200%) | Design | checklist |
| 9 | Ops: runbooks written, on-call rota staffed, alarms tested (game-day) | DevOps | game-day notes |
| 10 | Support: help center live, support inbox staffed, safety-escalation path defined | PM | dry-run |

## 25.2 Rollout Sequence

```
T-14  Production infra final apply; prod webhooks wired; synthetic monitors on
T-10  Submit iOS + Android (builds from release tag)
T-7   Go/no-go; web app live behind beta flag; beta families migrated to prod
T-3   Play staged rollout 10%; iOS phased release start; watch 48h
T-1   Play → 50% if halt criteria clean
T-0   LAUNCH: Play 100%, web public, marketing on (site, socials, press kit, school partners)
T+2   Postmortem-style health review #1 (even if healthy)
T+7   Health review #2; begin normal release cadence (biweekly)
T+30  Launch retrospective; metrics vs targets; Phase 2 kickoff confirmation
```

Halt criteria during rollout (auto + manual): crash rate >0.5%, ANR >0.3%, payment failure >2%, sync failure >1%, any safety/privacy incident → pause rollout, hotfix path (expedited review request if needed).

## 25.3 Launch-Week Operations

- **On-call**: 2 engineers (app + backend) on PagerDuty, 24/7 for week 1, then business-hours + escalation.
- **War room**: daily 30-min standup reviewing: store metrics, funnel (install→consent→activation), payment success, AI spend (off at MVP), top crashes, support themes.
- **Dashboards**: CloudWatch (infra), Sentry (errors), Firebase (funnels, crash-free), revenue (Stripe + store consoles), content engagement (top/zero-play items).
- **Support SLAs**: safety/privacy reports — first response <4 h, resolution path same day; billing — <24 h; general — <48 h. Safety reports route to PM + counsel immediately.

## 25.4 Communications

- Marketing site `watoto.app` (privacy-forward messaging: "No ads. Ever."), press kit, founder posts.
- School/educator outreach list warmed during beta; "Teacher Approved" badge pursued on Play.
- Parents' email onboarding series (consent-gated): day 0 welcome, day 3 offline tip, day 7 progress report intro, day 14 premium trial nudge.
- App store review responses: templates ready; all 1–2★ reviews answered within 48 h.

## 25.5 Incident Response

Severity ladder: **SEV1** child-safety/privacy breach or full outage → page all, status page, counsel notified, regulator-notification clock starts if breach (GDPR 72 h); **SEV2** payments or sync degraded → page on-call; **SEV3** feature degraded → next business day. Every SEV1/2 gets a blameless postmortem within 5 days with tracked actions.

## 25.6 Post-Launch Measurement (week 1 targets)

| Metric | Target | Source |
|---|---|---|
| Installs | 5,000+ | store consoles |
| Onboarding completion (install→child profile) | ≥60% | Firebase funnel |
| Consent completion rate | ≥90% of onboarders | API metrics |
| Activation (3 lessons / week 1) | ≥45% | analytics |
| Crash-free sessions | ≥99.6% | Crashlytics |
| p95 API latency | <300 ms | CloudWatch |
| Refund rate | <3% | providers |

Misses on activation/onboarding trigger immediate UX iteration sprints; technical misses trigger the relevant runbook.
