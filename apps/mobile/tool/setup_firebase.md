# Enable Firebase for Watoto

Watoto already includes `firebase_core`, `firebase_auth`, `cloud_firestore`, and
`cloud_functions` in `pubspec.yaml`, with `FirebaseAuthService`, `FirestoreSyncApi`,
and `verifyStoreReceiptCallable` wired and unit-tested.

When `DefaultFirebaseOptions.isConfigured` is `false`, the app runs 100% offline
using `LocalAuthService` and `OfflineStore`. Once you run `flutterfire configure`,
Firebase activates automatically at startup (`initializeWatotoFirebase()`).

## Activation Checklist (~10 minutes)

1. **Create a Firebase project** at https://console.firebase.google.com
2. **Enable Authentication** → Email/Password + Anonymous
3. **Create Firestore** (production mode), then deploy security rules and functions from `backend/`:
   ```bash
   cd backend
   firebase login
   firebase use --add   # select your project
   cd functions && npm ci && npm run build && cd ..
   firebase deploy --only firestore:rules,firestore:indexes,functions
   ```
4. **Configure FlutterFire** from `apps/mobile`:
   ```bash
   cd apps/mobile
   dart pub global activate flutterfire_cli
   flutterfire configure --out=lib/firebase_options.dart
   ```
5. **Build with Firebase enabled:**
   ```bash
   flutter build appbundle --release \
     --dart-define=USE_FIREBASE=true \
     --dart-define=FIREBASE_OPTIONS_CONFIGURED=true \
     --dart-define=PUBLISH_FREE_ONLY=true
   ```

## Verify Cloud Wiring

- Run unit tests: `flutter test test/firebase_integration_test.dart`
- Sign up a parent in the app → creates `accounts/{uid}` (without client-forbidden `plan`/`entitlementExpiry`/`deletedAt` fields) and records consent under `accounts/{uid}/consents/{id}`.
- Complete a lesson/quiz/story → `FirestoreSyncApi` writes child profiles to `accounts/{uid}/profiles/{profileId}` (zero PII fields) and progress to `accounts/{uid}/profiles/{profileId}/progress/{itemId}`.
