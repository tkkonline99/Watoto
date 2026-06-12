# 18. Testing Strategy

## 18.1 Pyramid & Coverage Targets

| Layer | Tooling | Target |
|---|---|---|
| Unit — Flutter | `flutter_test`, mocktail, riverpod test utils | 80%+ lines on `lib/` (excl. generated) |
| Unit — NestJS | Jest, ts-mockito-style fakes | 80%+ lines; 90%+ on billing, sync, grading, safety |
| Widget/golden — Flutter | golden_toolkit | All core widgets + lesson block renderers, light/dark/HC themes, 1.0×/1.6× text scale |
| Integration — API | Jest + Testcontainers (Postgres, Redis) + supertest | Every endpoint happy path + authz denial + validation failure |
| Integration — Flutter | `integration_test` on emulators | Critical flows offline+online |
| E2E — Web/CMS | Playwright | Parent journey, purchase (Stripe test), CMS publish chain |
| Contract | OpenAPI diff + generated-client compile check | CI gate |

Coverage is ratcheted: CI fails if coverage drops >0.5% vs main.

## 18.2 Critical Test Suites (must-pass release gates)

1. **Sync engine** — property-based tests (fast-check / Dart `glados`): random op interleavings across 2 simulated devices converge to identical state; idempotency under duplicate delivery; clock-skew scenarios; queue overflow.
2. **Grading & rewards** — every question type; reward ledger idempotency; no double-grant on retry.
3. **Entitlements** — matrix of (plan × content flag × platform × offline) → access decision; expiry/grace transitions; webhook-driven downgrade mid-session.
4. **Billing webhooks** — recorded fixture payloads for ASSN v2, RTDN, Stripe (renew, cancel, refund, grace, resubscribe); replay/idempotency; signature failures.
5. **AI safety evals** — prompt eval suite (50 jailbreaks, 30 off-topic, 20 PII baits → 100% safe outputs) runs on every prompt change and weekly against live model.
6. **Authz** — generated test: every route × every role → expected allow/deny from the RBAC matrix (route added without matrix entry fails CI).
7. **Compliance jobs** — retention purge and erasure pipeline against seeded fixtures, asserting zero PII residue (automated PII scanner over DB dump + S3 listing).

## 18.3 Accessibility Testing

- Automated: `flutter_test` semantics assertions on every screen widget test; axe-core in Playwright for web/CMS; contrast lint on theme tokens.
- Manual per release: TalkBack + VoiceOver passes on the child loop and parent dashboard; keyboard-only web pass; 200% text scale sweep.

## 18.4 Performance & Load

- k6 load: catalog reads 500 RPS, sync batches 100 RPS, p95 <300 ms @ staging scale; soak 2 h.
- App: startup <2.5 s cold mid-tier Android; lesson open <500 ms from local pack; frame budget — no >32 ms frames during lesson interactions (profile-mode integration runs in CI on Firebase Test Lab).
- Pack download: 200 MB course pack on flaky 3G simulation (network conditioning) completes with resume.

## 18.5 Device & Platform Matrix

| Tier | Devices |
|---|---|
| P0 (every release) | Pixel 7 (13), Galaxy A14 (low-RAM Android 13), iPhone 12 (iOS 17), iPad 9th gen, Chrome desktop |
| P1 (weekly) | Android 10 minimum spec, iPhone SE 2, Safari + Firefox web, Android tablet |
| Child-reality checks | offline cold start, mid-lesson kill, storage-full download, airplane-mode purchase attempt |

## 18.6 QA Process

- PR: lint (`flutter analyze`, eslint strict, boundaries plugin), unit + affected integration, golden diff review.
- Nightly on develop: full integration + E2E + Test Lab device runs + k6 smoke.
- Release candidate: full regression checklist, accessibility manual pass, compliance smoke (consent flows, deletion), store-build validation.
- Bug bar: child-facing functional bugs and any safety/privacy bug = release blockers; cosmetic parent-surface issues are not.
