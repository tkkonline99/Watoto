# Enable Firebase for Watoto (optional for free-only launch)

Free-only publish works **offline** with local parent accounts. Enable Firebase when you want cloud auth, multi-device sync, and server-side consent/export.

## Steps (~20 minutes)

1. Create a Firebase project at https://console.firebase.google.com  
2. Enable **Authentication** → Email/Password + Anonymous  
3. Create **Firestore** (production mode), then deploy rules from `backend/`:
   ```bash
   cd backend
   firebase login
   firebase use --add   # select your project
   firebase deploy --only firestore:rules,firestore:indexes,functions
   ```
4. From `apps/mobile`:
   ```bash
   flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
5. Rebuild with:
   ```bash
   flutter build appbundle --release \
     --dart-define=USE_FIREBASE=true \
     --dart-define=FIREBASE_OPTIONS_CONFIGURED=true \
     --dart-define=PUBLISH_FREE_ONLY=true
   ```
6. Replace `FirebaseAuthService` methods with the live SDK adapter from
   `auth/FIREBASE_SETUP_FLUTTER.md` (path **accounts/{uid}**, not parents/).
7. Implement `initializeWatotoFirebase()` in `lib/firebase/firebase_bootstrap.dart`
   using `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

## Android

- Place `google-services.json` under `android/app/`
- Apply the Google Services plugin in `android/settings.gradle.kts` / `app/build.gradle.kts` as FlutterFire instructs

## iOS

- Place `GoogleService-Info.plist` in `ios/Runner/`
- Enable capabilities as needed for Auth

## Verify

- Sign up a parent → `accounts/{uid}` document exists  
- Consent callable records an entry under `consents`  
- Progress sync writes under `profiles/{id}/progress/{itemId}`
