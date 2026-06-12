# 6. NestJS Project Structure

Modular monolith. One deployable image runs in two modes (`MODE=api` | `MODE=worker`) sharing the same codebase; workers consume BullMQ queues. Prisma for data access (one schema, per-module client wrappers), zod-based DTO validation generated from the OpenAPI contract.

## 6.1 Directory Layout (`apps/api/`)

```
src/
├── main.ts                        # api bootstrap (helmet, CORS, pino, validation)
├── worker.ts                      # worker bootstrap (BullMQ processors only)
├── app.module.ts
│
├── common/
│   ├── config/                    # typed env config (zod-validated), per-env files
│   ├── prisma/                    # PrismaService, tx helper, soft-delete middleware
│   ├── guards/                    # JwtAuthGuard, RolesGuard, ChildAccessGuard, PinGuard
│   ├── decorators/                # @Roles(), @Principal(), @ChildScope()
│   ├── interceptors/              # audit-log, response-cache (Redis), timeout
│   ├── filters/                   # RFC7807 exception filter
│   ├── events/                    # typed DomainEventBus (in-proc + BullMQ mirror)
│   ├── idempotency/               # Idempotency-Key middleware (Redis SETNX)
│   └── rate-limit/                # token-bucket guard
│
├── modules/
│   ├── auth/                      # firebase-admin verify, JWT issue/rotate, PIN
│   │   ├── auth.controller.ts / auth.service.ts / token.service.ts / pin.service.ts
│   ├── accounts/                  # users, child_profiles, teacher_profiles, RBAC
│   ├── curriculum/                # subjects/courses/units/lessons + publishing
│   │   ├── curriculum-admin.controller.ts   # /admin/* CRUD
│   │   ├── catalog.controller.ts            # public read API (cached)
│   │   ├── publishing.service.ts            # version snapshot, hash, manifest rebuild
│   ├── content/                   # quizzes, flashcards, stories, games, activities, media
│   │   ├── grading.service.ts               # server-side quiz grading
│   │   └── media/ (upload signing, virus-scan callback, moderation hooks)
│   ├── i18n/                      # translations CRUD, XLIFF import/export, TTS jobs
│   ├── learning/                  # progress, attempts, mastery (BKT), challenges, adaptive
│   │   ├── progress.controller.ts / mastery.service.ts / adaptive.service.ts
│   ├── gamification/              # ledger, levels, badges (rules engine), certificates
│   ├── classroom/                 # groups, join codes, assignments, submissions
│   ├── billing/
│   │   ├── apple/ (ASSN v2 webhook, App Store Server API client)
│   │   ├── google/ (RTDN handler, Play Developer API client)
│   │   ├── stripe/ (checkout, webhook)
│   │   └── entitlements.service.ts          # single source for "what can this user access"
│   ├── sync/                      # batch op ingestion, LWW resolution, change feed
│   ├── ai/                        # ai-gateway: prompt registry, safety pipeline, providers
│   │   ├── tutor.controller.ts / reading.controller.ts / insights.service.ts
│   │   ├── safety/ (input filter, output filter, topic allowlist)
│   │   └── providers/ (openai.client.ts, stt.client.ts, tts.client.ts)
│   ├── safety/                    # consents, screen-time, moderation queue
│   ├── reporting/                 # parent/teacher reports, materialized view refresh
│   ├── notifications/             # FCM, SES email, preferences
│   └── admin/                     # platform settings, audit log query, user admin
│
├── jobs/                          # BullMQ processors (worker mode)
│   ├── media-transcode.processor.ts
│   ├── reading-score.processor.ts         # STT + pronunciation scoring
│   ├── report-weekly.processor.ts
│   ├── certificate-pdf.processor.ts
│   ├── billing-reconcile.processor.ts     # nightly receipt revalidation
│   ├── retention-purge.processor.ts       # voice recordings, expired partitions
│   └── translation-tts.processor.ts
│
prisma/
├── schema.prisma
└── migrations/
test/                              # jest unit + e2e (testcontainers: pg + redis)
```

## 6.2 Module Boundary Enforcement

- `eslint-plugin-boundaries`: a module may import from `common/*` and other modules' `index.ts` (public API) only — never their internals.
- Each module exports a façade service (`CurriculumFacade`, `EntitlementsService`, …) registered in its Nest module's `exports`.
- Cross-module async = domain events:

```ts
// learning/progress.service.ts
await this.tx(async (db) => {
  await db.lessonProgress.upsert({...});
  this.events.emit(new LessonCompleted({ childId, lessonId, scorePct, skills }));
});
// gamification listens → grants rewards; reporting listens → invalidates caches;
// classroom listens → updates assignment submissions.
```

## 6.3 AuthN/AuthZ Pipeline

```
Request → JwtAuthGuard (verify Watoto JWT, load principal)
        → RolesGuard (@Roles('parent','admin'))
        → ChildAccessGuard (any :childId param ∈ principal's family/group scope)
        → PinGuard (parent-zone mutations require recent PIN verification claim, 10 min TTL)
        → Controller (zod-validated DTO)
        → AuditInterceptor (admin routes: before/after diff → audit_logs)
```

JWT claims: `sub`, `role`, `familyId`, `childId?` (child sessions), `ent` (entitlement hash), `pinAt?`. Access 15 min / refresh 30 days rotating, device-bound, reuse detection.

## 6.4 Configuration & Secrets

- `common/config` loads env via zod schema — fails fast on missing keys.
- Production secrets injected by ECS from AWS Secrets Manager (`DATABASE_URL`, `REDIS_URL`, `FIREBASE_SA`, `OPENAI_API_KEY`, `STRIPE_SECRET`, `APPLE_IAP_KEY`, `JWT_KEYS` — RS256 keypair, kid-rotated).
- No secret ever in env files committed to git; local dev uses `.env.local` + docker-compose Postgres/Redis.

## 6.5 Queues (BullMQ)

| Queue | Producer → Processor | Notes |
|---|---|---|
| `media` | media upload → transcode/thumbnail/scan | concurrency 4 |
| `reading` | reading score requests | GPU-less; STT API call, 2 retries |
| `reports` | cron weekly/monthly | fan-out per family |
| `billing` | webhooks + nightly cron | idempotent by provider event id |
| `notify` | domain events → FCM/SES | rate-limited per device |
| `retention` | daily cron | purges per compliance policy |
| `ai-insights` | weekly cron | parent insight generation |

## 6.6 Observability

- pino structured logs (`requestId`, `principalId`, `module`) → CloudWatch.
- Sentry for exceptions (API + workers), release-tagged from CI.
- OpenTelemetry traces (HTTP + Prisma + BullMQ instrumentations) → CloudWatch/X-Ray.
- `/health` (liveness) and `/ready` (DB+Redis ping) for ALB/ECS checks.
- Domain metrics via CloudWatch EMF: sync batch size, grading latency, AI token spend, webhook lag.
