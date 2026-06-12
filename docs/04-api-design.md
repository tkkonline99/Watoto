# 4. API Design

## 4.1 Conventions

- Base URL: `https://api.watoto.app/v1` (URI versioning; breaking changes → `/v2`).
- JSON only; `camelCase` fields; timestamps ISO-8601 UTC.
- Auth: `Authorization: Bearer <watoto-jwt>` (see §4.3). Child sessions carry `childId` claim; parent/teacher/admin carry role claims.
- Locale: `Accept-Language: en|sw|fr` selects content language; responses include `contentLocale`.
- Pagination: cursor-based — `?limit=20&cursor=<opaque>` → `{ "items": [...], "nextCursor": "..." }`.
- Idempotency: all sync/billing POSTs accept `Idempotency-Key` header (UUID); duplicates return the original result.
- Errors (RFC 7807):

```json
{ "type": "https://api.watoto.app/errors/entitlement-required",
  "title": "Premium content", "status": 403,
  "code": "ENTITLEMENT_REQUIRED", "detail": "Lesson m68-frac-01 requires premium." }
```

- Rate limits (Redis token bucket, per principal): child 60 rpm, parent/teacher 120 rpm, AI endpoints 10 rpm, admin 300 rpm. `429` + `Retry-After`.

## 4.2 OpenAPI

The contract is maintained as `packages/shared_models/openapi.yaml`; Dart client (`openapi_generator`) and NestJS DTO validation (zod via `nestjs-zod`) are generated from it. CI fails on uncommitted drift.

## 4.3 Auth Endpoints

| Method & Path | Description |
|---|---|
| `POST /auth/firebase` | Exchange Firebase ID token → `{accessToken (15m), refreshToken (30d), user}` . Creates user row on first sign-in |
| `POST /auth/refresh` | Rotate refresh token (device-bound, reuse detection revokes family) |
| `POST /auth/child-session` | Parent (or PIN-unlocked device) mints a scoped child token for `childId` — claims: `role=child`, `childId`, `entitlements`, no email |
| `POST /auth/pin` / `PUT /auth/pin` | Verify / set parent PIN (argon2id; 5 fails → 15 min lock) |
| `POST /auth/logout` | Revoke refresh token |

## 4.4 Accounts & Family

| Method & Path | Role | Description |
|---|---|---|
| `GET /me` | any | Profile + roles + entitlements |
| `GET/POST /children` | parent | List / create child profiles (nickname, avatar, birthMonth, learningLocale) |
| `PATCH/DELETE /children/:id` | parent | Update / delete (delete triggers erasure pipeline) |
| `GET/PUT /children/:id/screen-time` | parent (PIN) | Screen-time policy |
| `GET/POST /consents` | parent | Consent records; POST records grant/revoke with method |

## 4.5 Catalog (read-heavy, cached)

| Method & Path | Description |
|---|---|
| `GET /catalog/subjects?ageBand=6_8` | Subjects with course summaries |
| `GET /catalog/courses/:id` | Course → units → lesson summaries (locked/premium flags computed per caller) |
| `GET /catalog/lessons/:id` | Published lesson body (current version), localized |
| `GET /catalog/quizzes/:id` | Quiz with questions (correct answers stripped for child role; grading server-side or via signed answer-key in offline pack) |
| `GET /catalog/stories?ageBand=&readingLevel=` | Story list |
| `GET /catalog/stories/:id` | Story with pages, narration audio URLs, word timings |
| `GET /catalog/games?ageBand=` / `GET /catalog/flashcards/decks/:id` | Games / decks |
| `GET /catalog/search?q=&ageBand=` | Postgres FTS across published content (locale-aware) |
| `GET /catalog/manifest?scope=course:<id>` | Offline download manifest: file list, sizes, hashes, signed CDN URLs |

## 4.6 Learning & Progress

| Method & Path | Role | Description |
|---|---|---|
| `POST /progress/lessons` | child | Upsert lesson progress `{lessonId, status, scorePct, timeSpentS, clientUpdatedAt, clientOpId}` |
| `POST /progress/quizzes` | child | Submit attempt; server grades, returns `{scorePct, passed, rewards[]}` |
| `POST /progress/reading` | child | Submit reading attempt (audio uploaded separately via signed URL) |
| `GET /progress/children/:id/summary` | parent/teacher | Aggregate stats |
| `GET /challenges/today` | child | Daily challenge set |
| `GET /learning-path/next` | child | Adaptive engine's next recommended items |

## 4.7 Sync (offline)

| Method & Path | Description |
|---|---|
| `POST /sync/batch` | Up to 200 queued ops `[{clientOpId, opType, payload, clientUpdatedAt}]` → per-op result `applied | duplicate | conflict_server_won | rejected`. LWW on `clientUpdatedAt`; ledger ops are append-only (never conflict) |
| `GET /sync/changes?since=<cursor>` | Server-side changes for this child (new assignments, entitlement changes, content-version bumps) |

## 4.8 Gamification

| Method & Path | Role | Description |
|---|---|---|
| `GET /rewards/balance` | child | `{stars, coins, xp, level}` |
| `POST /rewards/spend` | child | Spend coins (avatar shop) — server-validated |
| `GET /badges` / `GET /badges/earned` | child | Catalog / earned |
| `GET /leaderboards/:scope` | child (opted-in) | Weekly XP board (nicknames + avatars only) |
| `GET /certificates` | child/parent | Issued certificates (PDF URLs) |

## 4.9 Classroom

| Method & Path | Role |
|---|---|
| `POST /groups` / `GET /groups` / `GET /groups/:id` | teacher |
| `POST /groups/join` `{joinCode, childId}` | parent (approval = the act of joining) |
| `POST /groups/:id/assignments` / `GET .../assignments` | teacher |
| `GET /assignments` (for child) / `GET /groups/:id/analytics` | child / teacher |

## 4.10 Billing

| Method & Path | Description |
|---|---|
| `GET /billing/plans` | Plans with localized prices & store product IDs |
| `POST /billing/apple/verify` | App Store Server API verification of transaction; creates/updates subscription |
| `POST /billing/google/verify` | Play Developer API verification of purchase token |
| `POST /billing/stripe/checkout` | Create Stripe Checkout session (web) |
| `POST /webhooks/stripe` · `POST /webhooks/apple` (ASSN v2) · `POST /webhooks/google` (RTDN via Pub/Sub push) | Signature-verified, idempotent, archived to `payment_events` |
| `GET /billing/subscription` | Current subscription + manage-URL per provider |

## 4.11 AI

| Method & Path | Notes |
|---|---|
| `POST /ai/tutor/messages` | `{childSessionId, lessonId?, message}` → SSE stream. Server-side safety pipeline ([AI doc](13-ai-architecture.md)). Requires `ai_features` consent |
| `POST /ai/reading/score` | `{storyId, pageNo, audioUploadId}` → async job; result via `GET /ai/reading/score/:jobId` |
| `GET /ai/insights/children/:id` | Parent insights summary (generated weekly, cached) |
| `POST /media/uploads` | Signed S3 upload URL (audio attempts, admin media) |

## 4.12 Admin / CMS (`/admin/*`, roles admin+, all actions audit-logged)

| Area | Endpoints |
|---|---|
| Curriculum | CRUD `subjects, courses, units, lessons`; `POST /admin/lessons/:id/publish` (creates immutable version, enqueues CDN warm + manifest rebuild) |
| Quiz/Story/Flashcard/Game builders | CRUD + publish, same workflow states `draft → in_review → approved → published` |
| Media | `POST /admin/media` (signed upload → virus scan → moderation queue), list/search |
| Translations | `GET /admin/translations?key=&locale=&missing=true`, bulk import/export (CSV/XLIFF), `POST /admin/translations/:id/tts` (generate audio) |
| Moderation | `GET /admin/moderation/queue`, `POST /admin/moderation/:id/decision` |
| Users | Search, suspend, role grants (super_admin only for admin grants) |
| Platform | `GET/PUT /admin/settings/:key` (super_admin), `GET /admin/audit-logs` |

## 4.13 Sample Payload — Lesson Body (`lesson_versions.body`)

```json
{
  "schema": "watoto.lesson/1.2",
  "titleKey": "lesson.8f3a.title",
  "blocks": [
    { "type": "intro_animation", "rive": "media/rive/counting-intro.riv" },
    { "type": "concept", "textKey": "lesson.8f3a.b1", "image": "media/img/three-apples.webp",
      "audioKey": "lesson.8f3a.b1" },
    { "type": "tap_to_count", "items": 3, "successAudioKey": "ui.praise.great" },
    { "type": "check", "questionRef": "q-inline-1",
      "question": { "qtype": "tap_image", "promptKey": "lesson.8f3a.q1",
                    "options": [{"img":"two.webp"},{"img":"three.webp","correct":true}] } }
  ],
  "completion": { "rewards": { "xp": 10, "stars": 1 }, "skills": ["counting.1-10"] }
}
```
