# Firebase + Payments (mobile)

Watoto ships with full `firebase_core`, `firebase_auth`, `cloud_firestore`, and
`cloud_functions` integration wired end-to-end. When `DefaultFirebaseOptions.isConfigured`
is `false` (the default offline clone state), the app automatically falls back to
`LocalAuthService`, `OfflineStore`, and `SandboxPurchaseBridge` (in debug builds)
with zero network errors.

## Free vs Premium

| Tier | What unlocks |
|------|--------------|
| **Free** | Curriculum stages **1–5** (or **1–10** when `PUBLISH_FREE_ONLY=true`), XP/coins/stars, daily challenge, avatar shop |
| **Premium** | Stages **6–10**, multi-device Firestore cloud sync, server-verified entitlements |

Gating never interrupts a child mid-activity. Premium prompts and voice-pack
downloads live strictly behind the **Parent Zone** (`/parent` and `/paywall`).

## Sandbox purchase (works offline today)

1. Open **Parent Zone** → **Watoto Premium**.
2. Tap **Monthly (sandbox)** or **Annual (sandbox)**.
3. Local entitlement is written for 30 / 365 days (`OfflineStore.setLocalPremium`).

Product IDs match `backend/products.json`:
- `watoto.premium.monthly`
- `watoto.premium.annual`

## Activate Live Firebase Auth + Firestore Sync (~10 minutes)

All Dart and TypeScript code is already wired in:
- `lib/firebase_options.dart` (`DefaultFirebaseOptions`)
- `lib/firebase/firebase_bootstrap.dart` (`initializeWatotoFirebase()`)
- `lib/features/auth/firebase_auth_service.dart` (`FirebaseAuthService`)
- `lib/data/cloud/cloud_sync.dart` (`FirestoreSyncApi`)
- `lib/features/auth/iap_bridge.dart` (`verifyStoreReceiptCallable`, `fetchServerEntitlement`)

To connect your live Firebase project:

1. **Create & configure Firebase project:**
   - Enable **Authentication** → Email/Password + Anonymous.
   - Create **Cloud Firestore** database (production mode).
2. **Deploy Firestore rules, indexes, and Cloud Functions:**
   ```bash
   cd backend
   firebase login
   firebase use --add   # select your Firebase project
   cd functions && npm ci && npm run build && cd ..
   firebase deploy --only firestore:rules,firestore:indexes,functions
   ```
3. **Generate `lib/firebase_options.dart` via FlutterFire:**
   ```bash
   cd apps/mobile
   dart pub global activate flutterfire_cli
   flutterfire configure --out=lib/firebase_options.dart
   ```
   *(Alternatively, pass `--dart-define=FIREBASE_PROJECT_ID=... --dart-define=FIREBASE_API_KEY=...` at build time.)*
4. **Build release binaries:**
   ```bash
   flutter build appbundle --release \
     --dart-define=USE_FIREBASE=true \
     --dart-define=FIREBASE_OPTIONS_CONFIGURED=true
   ```

## Activate Live StoreKit 2 / Google Play Billing IAP

1. Create `watoto.premium.monthly` and `watoto.premium.annual` in App Store Connect and Google Play Console.
2. Configure store secrets for Cloud Functions (`backend/functions/src/payments.ts`):
   - `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_BUNDLE_ID`
   - `GOOGLE_PACKAGE_NAME` (and Play Developer API service account access)
3. Build with `--dart-define=PUBLISH_FREE_ONLY=false`. After purchase/restore, `EntitlementService` automatically invokes `verifyStoreReceiptCallable` (`verifyPurchase` Cloud Function) and syncs `accounts/{uid}` via `refreshFromServer()`.

## Screen Time

Parent Zone → **Screen time**: Off / 15 / 25 / 45 minutes. When exceeded, child
routes redirect to `/rest`. Parents can grant **+10 minutes** from the dashboard.
