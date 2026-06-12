# 17. Compliance Architecture

> Engineering framework, not legal advice — counsel review of final policies, consent text, and store listings is a launch gate.

## 17.1 Regulatory Mapping

### COPPA (US, under-13)
| Requirement | Implementation |
|---|---|
| Verifiable parental consent (VPC) before collecting child data | Onboarding consent step; methods: card micro-charge verification or email-plus; method recorded in `consents.method` |
| Direct notice + privacy policy | Plain-language notice at consent, full policy linked (parent surfaces only) |
| Data minimization | Nickname only, birth *month* only, no photos of children, no location, no contacts |
| Parental review/deletion rights | Parent Zone → Privacy: export (machine-readable JSON), delete per child, revoke consents |
| No behavioral advertising | **No ads at all**; Firebase Analytics configured with ad personalization disabled, no AdId collected |
| Retention limits | §17.3 schedule, automated purge jobs |
| Voice recordings | Distinct consent, ≤30-day retention, never used for any purpose beyond scoring |

### GDPR-K / GDPR (EU/UK)
| Requirement | Implementation |
|---|---|
| Lawful basis | Consent (Art. 6/8) — parental consent for under-16 per member-state age; age gate routes accordingly |
| Art. 15–20 rights | Self-service export + deletion; SAR queue for manual requests, 30-day SLA |
| Art. 17 erasure | Erasure pipeline: soft-delete → 30-day grace → hard purge of PII rows, S3 objects, Firebase user, analytics de-identification; certificate of completion emailed |
| DPIA | Required before launch (template in `docs/legal/` to be produced); AI features and voice processing are the high-risk items |
| Processors | DPAs with AWS, Google/Firebase, OpenAI, Stripe; OpenAI API zero-data-retention tier; data-processing register maintained |
| Transfers | EU data: SCCs; Phase 2 option — EU region deployment (architecture is region-portable) |

### FERPA (US schools, teacher features)
| Requirement | Implementation |
|---|---|
| Education records control | School/teacher data segregated by group scope; "school official" model documented in teacher ToS |
| Parental access rights | Parents see everything teachers see about their child (dashboard parity) |
| No redisclosure | Teacher exports limited to their groups, watermarked, audit-logged |

### Stores
Apple Kids Category + Google Play Families: no ads, no external links in child UI, parental gates before commerce/links, no third-party analytics receiving child identifiers, declared data-safety forms — detailed in the [App Store](21-app-store-checklist.md) and [Play](22-google-play-checklist.md) checklists.

## 17.2 Consent Management

- Granular kinds (`consent_kind` enum): COPPA parental, GDPR-K processing, leaderboard, AI features, voice recording, marketing email.
- Immutable consent ledger (`consents` append-only — revocation = new row `granted=false`); current state = latest row per kind.
- Feature gates read consent state server-side (claims refreshed on change via `/sync/changes`); UI hides non-consented features rather than erroring.
- Re-consent triggered on material policy change (versioned policy id stored with each consent row).

## 17.3 Data Retention Schedule (enforced by `retention-purge` worker)

| Data | Retention |
|---|---|
| Voice recordings | 30 days max (or on revocation, immediate) |
| AI tutor transcripts | 90 days (parent-viewable window), then aggregate-only |
| Learning progress/mastery | life of profile; deleted with profile |
| Quiz attempt detail (answers JSON) | 24 months → reduced to scores only |
| Audit logs | 12 months hot, 7 years Glacier (financial/billing-relevant), then destroyed |
| Payment events | 7 years (financial records) |
| Deleted-profile grace copies | 30 days, then hard purge |
| Inactive free accounts | reminder at 22 months, anonymized at 24 months |

## 17.4 Deletion Pipeline

```
request (Parent Zone / SAR email) → PIN + re-auth confirm
→ users.deleted_at / child_profiles.deleted_at set (immediate logical hide)
→ T+30d job: delete PII rows, reading audio S3 objects, certificates PDFs,
  Firebase Auth user, FCM tokens; foreign keys to analytics tables rewritten
  to anonymized child surrogate id; ledger/attempt rows de-identified (kept for aggregate stats)
→ deletion receipt emailed; audit_logs records the erasure event (no PII in the log)
```

## 17.5 Privacy-by-Design Defaults

Analytics: no advertising identifiers, child events keyed to internal UUID only, IP truncation on, Crashlytics scrubbers remove nicknames from logs. Leaderboards, AI, voice, marketing: **all off until explicit opt-in**. New features must complete a privacy checklist (data collected? purpose? retention? consent kind?) in the PR template before merge.
