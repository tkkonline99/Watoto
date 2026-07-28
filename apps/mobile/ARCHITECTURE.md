# Watoto mobile architecture

## Layers

```
lib/
  domain/     # pure models, rules, ports — no Flutter UI
  data/       # (future) Hive/network adapters implementing ports
  core/       # shared widgets, audio, offline store, network client
  features/   # screens + feature controllers
  app shell   # bootstrap, router, theme (main/app/bootstrap)
```

**Dependency rule**

| Layer | May import |
|-------|------------|
| `domain` | Dart SDK only |
| `core` / `data` | `domain`, Flutter, packages — **not** `features` |
| `features` | `domain`, `core`, other features carefully |
| `router` / `app` | anything |

CI enforces this via `tool/check_layer_deps.py`.

## Identity (single plane)

- Port: `domain/ports/auth_port.dart` (`AuthPort` / `AuthUser`)
- Adapters: `LocalAuthService` (default offline), `FirebaseAuthService` (opt-in)
- Session/router use `SessionController` + Hive for PIN; credential auth goes through `AuthPort`
- **Release builds never call Nest `/auth/dev-token`**

## Backend v1

- **Firebase** path: `accounts/{uid}/profiles/{id}/progress/{itemId}` (see root `docs/BACKEND_PATH.md`)
- NestJS (`apps/api`) is Phase 2 — local sync only with explicit `ALLOW_NEST_DEV_TOKEN` in debug

## Content

- Primary player: library (`/play/:id`) + `watoto_content_library.json`
- Legacy `/lesson` and `/quiz` scaffold routes remain for tests/demos only

## Gamification (single source of truth)

- Stars: `domain/rules/stars.dart` — 40 / 67 / 100 (kinder thresholds)
- Levels: `domain/rules/levels.dart` — cumulative `floor(100 × n^1.4)`
- Economy: `domain/rules/economy.dart`

## Offline-first

Writes land in Hive first → `SyncEngine` drains with backoff → parent dashboard shows pending/error.
