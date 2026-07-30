# Backend path for v1 (architecture decision)

Watoto’s design package documents **two** backend options. For launch, pick **one** production path and treat the other as future scale.

## Recommended for v1: Firebase (`backend/`)

| Piece | Location |
|-------|----------|
| Auth | Firebase Authentication (`auth/`) |
| Data | Cloud Firestore + security rules |
| Server logic | Cloud Functions (`backend/functions`) |
| Payments | `payments.ts` (Apple/Google verify + notifications) |
| Hosting | Firebase Hosting (web) |

**Why:** Matches the launch runbook, lower ops for a solo/small team, COPPA-friendly client auth already sketched, IAP verification lives next to entitlement docs.

**Mobile wiring:**

1. `flutterfire configure` → `lib/firebase_options.dart`
2. `flutter pub add firebase_core firebase_auth cloud_firestore`
3. Paste the real adapter from `auth/FIREBASE_SETUP_FLUTTER.md` into `firebase_auth_service.dart`
4. Build with `--dart-define=USE_FIREBASE=true`
5. `firebase deploy --only firestore:rules,firestore:indexes,functions`

## Alternate / Phase 2: NestJS + Postgres (`apps/api`)

Documented in `docs/01–07` and `docs/06-nestjs-project-structure.md`. Use when you need:

- Heavy CMS / admin API
- Multi-region RDS + Redis job queues
- Teacher/school features at scale

The Flutter sync client (`WatotoApi`) still targets `POST /v1/sync/batch` for this path. Prefer Firebase ID tokens once Auth is live; Nest `POST /auth/dev-token` stays **dev-only** (disabled when `NODE_ENV=production` or Firebase SA is set).

## Do not run both in production

Running Firebase entitlements **and** Nest progress without a single identity plane will fork family data. Choose Firebase for v1; promote Nest only with a deliberate migration plan.

## Firestore path (canonical)

All production writers use:

```
accounts/{uid}
accounts/{uid}/profiles/{profileId}
accounts/{uid}/profiles/{profileId}/progress/{itemId}
accounts/{uid}/consents/{consentId}
```

**Do not** write `parents/*` or `children/*` — security rules deny those trees by default. Adapters in `auth/` were unified to `accounts/*` to match `backend/firestore.rules`.

## Mobile release sync

- Release builds **never** call Nest `/auth/dev-token` (`WatotoApi.allowDevToken` is false in `kReleaseMode`).
- Without a Firebase ID token, progress stays in the Hive offline queue until auth is configured.

