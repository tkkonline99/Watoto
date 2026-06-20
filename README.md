# Watoto — Production Blueprint

**Watoto** is a multilingual (English / Swahili / French) educational platform for children aged 0–10, delivered on Android, iOS, and Web from a single Flutter codebase, backed by a NestJS modular monolith on AWS.

This repository contains the complete production-ready design package: architecture, database, APIs, project structures, infrastructure, security, compliance, testing, CI/CD, deployment, and roadmaps.

## Launch status

The product is built and the launch package is assembled. **[docs/LAUNCH_RUNBOOK.md](docs/LAUNCH_RUNBOOK.md)** is the authoritative gate-by-gate status and the consolidated "what only you can do" list (accounts, billing, legal sign-off, assets). Delivered alongside the blueprint:

- **Backend (`backend/`)** — a deployable **Firebase + Cloud Firestore + Security Rules + Cloud Functions** backend (consent ledger, account export/deletion, scheduled purge) that reuses the existing Firebase Auth project. Recommended over running a second cloud backend; the AWS/NestJS design in `docs/` remains the documented alternative. See [`backend/BACKEND_README.md`](backend/BACKEND_README.md).
- **Payments (`backend/functions/src/payments.ts`, `auth/entitlements.ts`)** — Apple IAP + Google Play Billing with server-side receipt verification and renewal/refund sync; entitlement is server-only, so clients can never set paid status. See [`backend/PAYMENTS_README.md`](backend/PAYMENTS_README.md).
- **CI / build (`.github/workflows/build.yml`, `codemagic.yaml`)** — runs the Firestore rules tests + Cloud Functions typecheck on every push; builds signed Android/iOS and the web app; uploads to Play internal / TestFlight and deploys web to **Firebase Hosting**. No Mac required. See [`BUILD_README.md`](BUILD_README.md).
- **Store listing (`docs/STORE_LISTING.md`)** — paste-ready App Store / Play metadata, privacy-label answers, age rating, and screenshot shot-list.

## Document Index

| # | Document | Contents |
|---|----------|----------|
| 1 | [System Architecture](docs/01-system-architecture.md) | C4 views, component model, scaling strategy |
| 2 | [Database Schema](docs/02-database-schema.md) | Full PostgreSQL DDL, indexes, partitioning |
| 3 | [ER Diagrams](docs/03-er-diagrams.md) | Mermaid ER diagrams per domain |
| 4 | [API Design](docs/04-api-design.md) | REST conventions, full endpoint catalog, payloads |
| 5 | [Flutter Project Structure](docs/05-flutter-project-structure.md) | Feature-first layout, Riverpod, GoRouter, offline layer |
| 6 | [NestJS Project Structure](docs/06-nestjs-project-structure.md) | Module layout, Prisma, BullMQ, guards/RBAC |
| 7 | [AWS Infrastructure](docs/07-aws-infrastructure.md) | VPC, ECS Fargate, RDS, Redis, S3/CloudFront, Terraform |
| 8 | [UI/UX Design System](docs/08-design-system.md) | Tokens, palettes per age band, typography, motion, audio |
| 9 | [User Flows](docs/09-user-flows.md) | Onboarding, learning, purchase, teacher, offline flows |
| 10 | [Wireframes](docs/10-wireframes.md) | Annotated low-fi wireframes for all key screens |
| 11 | [Curriculum Framework](docs/11-curriculum-framework.md) | Hierarchy, age-band syllabi, content templates, volumes |
| 12 | [Gamification Architecture](docs/12-gamification.md) | Economy, levels, badges, streaks, safeguards |
| 13 | [AI Architecture](docs/13-ai-architecture.md) | AI Tutor, Reading Coach, Adaptive Engine, Parent Insights |
| 14 | [CMS Architecture](docs/14-cms-architecture.md) | Admin CMS modules, workflow states, media pipeline |
| 15 | [Offline Sync Design](docs/15-offline-sync.md) | Offline-first storage, download packs, sync queue, conflicts |
| 16 | [Security Architecture](docs/16-security-architecture.md) | AuthN/AuthZ, JWT, RBAC matrix, encryption, audit |
| 17 | [Compliance Architecture](docs/17-compliance.md) | COPPA, GDPR-K, FERPA, consent, retention, deletion |
| 18 | [Testing Strategy](docs/18-testing-strategy.md) | Pyramid, coverage, frameworks, device matrix |
| 19 | [CI/CD Pipeline](docs/19-cicd-pipeline.md) | GitHub Actions workflows, environments, promotion |
| 20 | [Deployment Guide](docs/20-deployment-guide.md) | Infra bring-up, backend deploy, store releases, web |
| 21 | [App Store Checklist](docs/21-app-store-checklist.md) | iOS / Kids Category submission checklist |
| 22 | [Google Play Checklist](docs/22-google-play-checklist.md) | Play / Families Policy submission checklist |
| 23 | [MVP Roadmap](docs/23-mvp-roadmap.md) | 6-month MVP plan, sprint breakdown |
| 24 | [Phase 2 Roadmap](docs/24-phase2-roadmap.md) | Post-MVP expansion plan |
| 25 | [Production Launch Plan](docs/25-launch-plan.md) | Launch gates, rollout, on-call, comms |

## Technology Summary

| Layer | Choice |
|-------|--------|
| Client | Flutter (stable) — Android, iOS, Web; Riverpod, GoRouter, Flutter Intl/ARB, Rive, Lottie, just_audio, video_player, Hive + SQLite (drift) |
| Backend | NestJS (TypeScript), modular monolith, microservice-ready; Prisma ORM; BullMQ jobs |
| Data | PostgreSQL 16 (RDS), Redis 7 (ElastiCache), Postgres FTS |
| Media | S3 + CloudFront |
| Auth | Firebase Authentication (Email, Google, Apple) + Parent PIN; backend-issued JWT + refresh tokens; RBAC |
| Payments | Apple IAP (StoreKit 2) + Google Play Billing in‑app, verified server‑side via Cloud Functions; Stripe only if a web purchase flow is added later |
| AI | OpenAI API (tutor, insights), STT/TTS, pronunciation assessment |
| Observability | Firebase Analytics, Crashlytics, CloudWatch, Sentry |
| Infra | AWS — ECS Fargate, RDS, ElastiCache, S3, CloudFront, Route53, WAF, Secrets Manager |
| CI/CD | GitHub Actions → dev / staging / production |

## Repository Layout (target monorepo)

```
watoto/
├── apps/
│   ├── mobile/          # Flutter app (Android/iOS/Web)
│   └── api/             # NestJS backend (alternative; serves CMS admin API too)
├── backend/             # Firebase backend — Firestore rules+indexes, Cloud Functions, payments (recommended)
├── auth/                # Firebase Auth client adapters (TS + Dart) + entitlements
├── content/             # Content library, i18n, validators, generators
├── packages/            # (target) OpenAPI-generated clients, content JSON Schemas
├── infra/               # Terraform (envs: dev, staging, prod)
├── docs/                # Design package + LAUNCH_RUNBOOK, STORE_LISTING
├── codemagic.yaml       # iOS/Android CI (Codemagic)
└── .github/workflows/   # CI/CD (rules tests, signed builds)
```

## Getting Started (current scaffold)

The repo now contains a **working scaffold**: a Flutter app (`apps/mobile`) and a NestJS API (`apps/api`), both compiling, tested, and runnable.

```powershell
# Backend (needs Node 20+; PostgreSQL via docker compose up -d for full function)
cd apps/api
npm install
npm run build ; npm test            # 12 unit tests
node dist/main.js                   # http://localhost:3000/v1/health

# Mobile/Web app (needs Flutter SDK — installed at C:\dev\flutter on this machine)
cd apps/mobile
flutter pub get ; flutter gen-l10n
flutter analyze ; flutter test      # 18 tests incl. full lesson + quiz flow
flutter run -d chrome               # or: flutter build web --release

# Android (SDK at C:\dev\android-sdk, JDK 21 at C:\dev\jdk-21):
pwsh tool/build-android.ps1 apk --debug        # -> build/app/outputs/flutter-apk/app-debug.apk
```

### Building Android on this machine

`flutter build apk` works, but **must be invoked via `tool/build-android.ps1`** (or with
`TMP`/`TEMP` set to a clean path like `C:\dev\tmp`). Reason: this machine's endpoint
security blocks AF_UNIX socket files under the default `%TEMP%`
(`C:\Users\...\AppData\Local\Temp`). Gradle's Java NIO selector opens such a socket as an
internal self-pipe, so a plain build dies instantly with *"Unable to establish loopback
connection"* (`UnixDomainSockets.connect0 → Invalid argument: connect`). Redirecting
`TMP`/`TEMP` elsewhere sidesteps it — no admin rights needed. This is **not** an iOS/Android
code issue and does not affect CI or other machines.

iOS still requires macOS + Xcode (or a cloud-Mac CI runner) — unchanged.

> **⚠ Windows note (this machine):** Windows Defender **Controlled Folder Access** blocks
> `dart.exe` (and slows `node.exe`) inside this OneDrive folder. Day-to-day builds run from the
> mirror at **`C:\dev\watoto`**; sync source back here with
> `robocopy C:\dev\watoto . /E /XD node_modules .dart_tool build dist coverage .git`.
> Permanent fix: allowlist `C:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe` under
> Windows Security → Ransomware protection (requires admin), or develop outside OneDrive.

What the scaffold includes today: child home (subject islands, daily challenge, XP chip), a
lesson player executing `watoto.lesson/1.0` JSON (concept → tap-to-count → check blocks,
celebration + XP), one-click EN/SW/FR switching, Savanna theme; **offline-first layer** —
Hive-backed local store (progress, XP balance, sync queue) with a SyncEngine draining to
`POST /v1/sync/batch` (idempotent, queue survives restarts; 13 tests incl. an offline
end-to-end lesson flow); API with health/auth(dev)/catalog/progress/sync modules, Prisma
schema + seed (demo family + sample lesson on fixed UUIDs), LWW merge logic with tests.

## Non-Negotiable Product Constraints

1. **Child safety**: no ads, no external links in child surfaces, no open chat, all content moderated before publish.
2. **Compliance**: COPPA / GDPR-K / FERPA, Apple Kids Category, Google Play Families Policy.
3. **Offline-first**: lessons, stories, quizzes downloadable; progress recorded locally and synced.
4. **Accessibility**: WCAG 2.2 AA; screen readers, dyslexia-friendly font option, captions, scalable text.
5. **Localization**: full UI + curriculum in EN/SW/FR with one-click switching and pronunciation audio.
