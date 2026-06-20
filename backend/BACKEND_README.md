# Watoto — Backend Specification (Gate 6)

This is the server Watoto's client and existing auth layer talk to. It is built on the **same Firebase project that auth already requires**, so it adds no second cloud account: **Firebase Auth** (identity, already built in `../auth`) + **Cloud Firestore** (data) + **Security Rules** (authorization) + **Cloud Functions** (server-only operations). Files in this folder are deployable as-is once you point them at your project.

## Why this stack

Auth is already Firebase, the app is offline-first, and the data is small and per-family — so Firestore's offline cache, sync, and rules-based authorization do most of the work with very little server code. It keeps the children's-data security model in one auditable place (the rules) and avoids running and paying for a second backend. If you specifically want AWS, the data model below maps cleanly to it — see the last section.

## Architecture at a glance

The client reads and writes Firestore directly through the Firebase SDK; **Security Rules** decide what's allowed, and the SDK's offline cache makes play work with no connection and sync when it returns. The only things that go through **Cloud Functions** are operations the rules deliberately forbid clients from doing themselves: recording the consent ledger, exporting an account, deleting an account, and granting paid entitlements after a verified purchase. There is no always-on server to manage.

## Data model (Firestore)

The account holder (a parent) is the only authenticated principal; child data lives under their account, so it is reachable only by them.

| Path | Holds | Who writes |
|---|---|---|
| `accounts/{uid}` | Account holder: `email`, `plan` ("free"\|"premium"), `entitlementExpiry`, `consentVersion`, `deletedAt`/`purgeAfter` | Client creates at sign-up (safe fields only); `plan`/`entitlementExpiry`/`deletedAt` are **server-only** |
| `accounts/{uid}/profiles/{profileId}` | Child profile: `displayName` (parent-chosen nickname), `avatar`, `ageBand`, `stage`, `settings` — **no child PII** | Parent (client), shape-validated by rules |
| `accounts/{uid}/profiles/{profileId}/progress/{itemId}` | Per-item progress keyed by content id (`s09.math.quiz.01`): `status`, `attempts`, `lastResult`, `updatedAt` | Parent session; last-write-wins by `updatedAt` |
| `accounts/{uid}/consents/{consentId}` | Consent ledger: `method`, `scope`, `policyVersion`, `timestamp` | Append-only via `recordConsent`; immutable to clients |

`uid` equals the Firebase Auth user id. The `progress` key is exactly the content-library item id, so progress, content, captions, audio, and art all share one identity.

## Sync model (offline-first)

Children play offline; the device holds progress locally and the Firebase SDK syncs when online. Conflicts resolve **last-write-wins by `updatedAt`**, enforced in the rules themselves (`isNewer()`): a write is accepted only if it carries a newer timestamp than what's stored, so a batched flush of offline progress can't clobber newer data. No server round-trip is needed for normal play and sync.

## API contract (Cloud Functions, callable)

All require an authenticated account holder.

| Function | Input | Returns | Purpose |
|---|---|---|---|
| `recordConsent` | `{ method, scope, profileId? }` | `{ ok, consentId, policyVersion }` | Append a parental-consent event |
| `exportAccountData` | – | `{ account, profiles[], consents[] }` | Parental review / GDPR portability |
| `requestAccountDeletion` | – | `{ ok, purgeAfter, graceDays }` | Soft-delete now; purge after grace |
| `hardDeleteExpiredAccounts` | scheduled (daily) | – | Irreversibly purge accounts past grace |
| `verifyPurchase` | `{ platform, receipt, productId }` | `{ ok }` | **Stub** — completed in the payments deliverable |

## How this enforces the privacy policy

The consent ledger (`PRIVACY_POLICY.md` Appendix A) is server-written and immutable to clients. `exportAccountData` backs the parental-review and portability rights. `requestAccountDeletion` plus the scheduled `hardDeleteExpiredAccounts` implement the soft-delete grace window and the irreversible purge of profiles, progress, and consents on the retention schedule. Entitlement is server-only, so paid status can never be set by a client.

## Deploy

1. Use the Firebase project you create for auth; enable Firestore (production mode) and upgrade to the Blaze plan (required to deploy Cloud Functions; usage stays in the free allowance at low volume).
2. `firebase deploy --only firestore:rules,firestore:indexes`
3. `cd functions && npm install && npm run build && firebase deploy --only functions`
4. Local development: `npm run serve` runs the Functions + Firestore emulators.

Point the client/auth `firebase.ts` config at the same project. The rules are the security boundary — review them whenever the data model changes, and keep the emulator rules tests in CI (the build-config deliverable wires this up).

## Capacity and cost

Data is tiny and per-family, and offline-first keeps reads low (the device serves cached content; sync writes are small and batched). At launch volumes this sits comfortably in Firestore's and Cloud Functions' free allowances; the main cost driver later is active sync volume, not storage.

## If you prefer AWS instead

The same model maps directly: **Cognito** (or keep Firebase Auth) for identity; **DynamoDB** with partition key `ACCOUNT#{uid}` and sort keys `PROFILE#{id}`, `PROGRESS#{itemId}`, `CONSENT#{id}` (single-table) for data; **API Gateway + Lambda** for the five operations above; IAM/Lambda authorizers in place of Security Rules; and an EventBridge schedule for the purge job. The trade-off is that you then own and pay for a second backend and must re-implement the rules-as-authorization yourself, which is why Firestore is the recommended path here.

## What only you can do

Create the Firebase project and set billing (the same ~10-minute task auth already needs), then run the deploy commands. Everything in this folder is ready for that.
