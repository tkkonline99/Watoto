# Firebase + Payments (mobile)

The app runs fully offline with `LocalAuthService` and a **sandbox Premium**
entitlement. Real Firebase Auth and store IAP plug in without rewriting
features.

## Free vs Premium (now live in the app)

| Tier | What unlocks |
|------|----------------|
| **Free** | Curriculum stages **1–5**, XP/coins/stars, daily challenge, avatar shop |
| **Premium** | Stages **6–10**, multi-device sync (when backend is live), offline packs (roadmap) |

Gating never interrupts a child mid-activity. Premium prompts are **parent zone
only** (`/paywall`).

## Sandbox purchase (works today)

1. Open **Parent zone** → **Watoto Premium**.
2. Tap **Monthly (sandbox)** or **Annual (sandbox)**.
3. Local entitlement is written for 30 / 365 days (`OfflineStore.setLocalPremium`).

Product ids match `backend/products.json`:

- `watoto.premium.monthly`
- `watoto.premium.annual`

## Activate real Firebase Auth

1. Create a Firebase project; enable Email/Password + Anonymous; create Firestore.
2. From `apps/mobile`:
   ```bash
   flutter pub add firebase_core firebase_auth cloud_firestore
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
3. Replace the body of `lib/features/auth/firebase_auth_service.dart` with the
   adapter in `auth/FIREBASE_SETUP_FLUTTER.md`.
4. In `lib/features/auth/auth_service.dart`, point the provider at
   `createAuthService()` (or `FirebaseAuthService()`).
5. In `main.dart`, after binding:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   await container.read(authServiceProvider).ensureAnonymousSession();
   ```
6. Deploy `backend/` (rules + functions) and create store products — see
   `backend/PAYMENTS_README.md`.

## Activate real IAP

1. Create the two products in App Store Connect + Play Console (same ids).
2. Implement a native `PurchaseBridge` (StoreKit 2 / Play Billing) that returns
   a receipt; keep `SandboxPurchaseBridge` for debug builds.
3. After buy/restore, call the `verifyPurchase` Cloud Function; entitlement is
   written **server-side only** (clients cannot set `plan` in Firestore rules).
4. Swap `EntitlementService` to read the account doc (mirror of
   `auth/entitlements.ts`) instead of / in addition to local premium.

## Screen time

Parent zone → **Screen time**: Off / 15 / 25 / 45 minutes. When exceeded, child
routes redirect to `/rest`. Parents can grant **+10 minutes** from the dashboard.
