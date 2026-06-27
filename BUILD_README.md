# Watoto — Build & CI Guide (Gate 10)

This wires up automated builds and signing for both platforms, and runs the Firestore rules tests on every push so the children's-data security model can't silently regress. It assumes a Flutter client (matching the Dart adapter in `auth/flutter`); if you use React Native or native apps, keep the same job structure and swap the build commands.

## You do not need to own a Mac

iOS builds require macOS, but a **cloud macOS runner is the Mac** — both options below run one for you:

- **Codemagic** (`codemagic.yaml`) — Flutter-first, the simplest path for a solo builder. It builds Android and iOS, handles iOS signing for you, and can publish straight to TestFlight and Play internal testing. Recommended.
- **GitHub Actions** (`.github/workflows/build.yml`) — runs rules tests + Android on free Linux runners and iOS on a macOS runner. More setup for signing, but no extra service.

Use either; you don't need both.

## One-time setup

1. **Apple Developer Program** [USD 99/yr] and **Google Play Console** [USD 25 once].
2. **Android signing:** create an upload keystore (`keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 9125 -alias upload`). For local release builds, copy `apps/mobile/android/key.properties.example` to `key.properties` and fill it in (both it and `*.jks` are gitignored); CI instead supplies the `ANDROID_*` secrets and decodes the keystore. The Gradle config reads whichever is present and falls back to debug signing if neither is.
3. **App Store Connect API key** (.p8 + key id + issuer id) — reuse the one created for payments verification; it also drives TestFlight uploads.
4. **Google Play service account** with release permissions — reuse the one from payments; it also drives Play uploads.
5. **iOS signing assets** — a distribution certificate (.p12) and provisioning profile. On Codemagic, let it manage these automatically with the App Store Connect API key. On GitHub Actions, store them as base64 secrets (below) and fill in the `teamID` + provisioning-profile name in `apps/mobile/ios/ExportOptions.plist`.

## Secrets to set in CI

| Secret | Used for |
|---|---|
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Sign the Android App Bundle |
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_BASE64` | iOS signing + TestFlight upload |
| `IOS_DIST_CERT_BASE64`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64` | iOS signing on GitHub Actions (not needed if Codemagic auto-signs) |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Upload to Play internal track |
| `FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_PROJECT_ID` | Deploy the web build to Firebase Hosting |

Never commit these; set them in the CI provider's encrypted secrets.

## What the pipeline does

1. **Verify** (Linux): typecheck the Cloud Functions (`tsc --noEmit`), `dart analyze`, and run the **Firestore rules tests** in the emulator (`backend/tests/`). A failing rules test fails the build.
2. **Android** (Linux): `flutter build appbundle --release`, signed with the upload keystore → uploads the `.aab` to the Play **internal** track.
3. **iOS** (macOS): `flutter build ipa --release` with signing → uploads to **TestFlight**.
4. **Web** (Linux): `flutter build web --release` → deploys to **Firebase Hosting** (`firebase deploy --only hosting`, using `backend/firebase.json`).

The store uploads target test tracks, not public release — promotion to production stays a manual, deliberate step in the consoles. The Flutter app lives in `apps/mobile`, so CI runs every `flutter` command there; the web deploy serves `apps/mobile/build/web`. Android release signing is wired in `build.gradle.kts` (reads `key.properties` or the `ANDROID_*` secrets); iOS uses `apps/mobile/ios/ExportOptions.plist` — fill in its `teamID` and provisioning-profile name before the first signed build.

## Windows desktop (local build)

The app also targets **Windows desktop** (`apps/mobile/windows`), for a sideloadable `.exe` outside the mobile stores. It is not in CI — there's no store channel — so build it locally:

1. Install **Visual Studio 2019 or newer** with the **"Desktop development with C++"** workload (`flutter doctor` must show `[✓] Visual Studio - develop Windows apps`).
2. From `apps/mobile`: `flutter build windows --release`.
3. The bundle lands in `apps/mobile/build/windows/x64/runner/Release/` — ship the whole folder (the `.exe` needs the `.dll`s and `data/` beside it), or wrap it in an MSIX/installer.

On this machine, build from the `C:\dev\watoto` mirror, not the OneDrive copy — Controlled Folder Access blocks the C++ toolchain from writing there (same reason Android builds use the mirror).

## Versioning

Version comes from `pubspec.yaml` (`version: 1.0.0+<build>`). CI sets the build number from the run number so every build is unique; bump the marketing version (`1.0.0`) by hand for releases. Tagging `v1.0.0` is a good trigger for a release build.

## Rules tests (why they're in CI)

`backend/tests/firestore.rules.test.mjs` exercises the security properties that protect children's data: a parent can read and write only their own account; a different signed-in user is denied; child-PII fields are rejected; the consent ledger is immutable to clients; and progress writes obey last-write-wins. Run locally with:

    cd backend && firebase emulators:exec --only firestore "node --test ../backend/tests/"

Keeping these green on every push is the guardrail for the whole privacy model — extend them whenever the rules change.

## What only you can do

Create the developer accounts and add the signing secrets above; everything else runs in CI. The first iOS upload also needs an app record created in App Store Connect and the bundle id registered — a one-time console step.
