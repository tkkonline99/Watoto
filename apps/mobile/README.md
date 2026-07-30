# watoto_mobile

Flutter client for **Watoto** — multilingual (EN / FR / SW), offline-first learning for ages 0–10.

## Prerequisites

- Flutter stable (this machine: `C:\dev\flutter`)
- For Android: Android SDK + JDK 21
- On this Windows PC, prefer developing from `C:\dev\watoto` if OneDrive Controlled Folder Access blocks Hive/Gradle (see root `README.md`)

## Run

```powershell
cd apps/mobile
flutter pub get
flutter gen-l10n
flutter run -d chrome          # web
flutter run -d windows         # desktop (same lib/ as mobile)
# Android (use build script on this machine):
pwsh tool/build-android.ps1 apk --debug
```

### Windows desktop install (recommended on this PC)

One shared Flutter codebase — desktop is not a separate app. After any `lib/`
change, rebuild and install the shortcut:

```powershell
pwsh tool/build-all.ps1 -Platforms windows -Install
```

That installs to `%LOCALAPPDATA%\Programs\Watoto` and refreshes the Desktop
**Watoto** shortcut. Progress is stored under the app-support directory (not
OneDrive Documents), with a one-time migration if the folder name changed.


## Tests & analysis

```powershell
flutter analyze
flutter test
```

## Feature flags (`--dart-define`)

| Define | Default | Meaning |
|--------|---------|---------|
| `USE_FIREBASE` | `false` | Use `createAuthService()` Firebase path (requires packages + options) |
| `ALLOW_SANDBOX_IAP` | `false` | Allow local sandbox Premium in **release** (debug always allows sandbox) |
| `WATOTO_API_URL` | `http://localhost:3000/v1` | Nest sync API base (optional; Firebase is v1 backend) |
| `START` | `/welcome` | Initial route for demos |

## Project layout

- `lib/features/` — screens (home, library play, parent, auth, …)
- `lib/core/offline/` — Hive store, sync queue, lifecycle flush
- `lib/core/widgets/` — design-system buttons, mascot, subject islands
- `lib/core/analytics/` — privacy-preserving, opt-in analytics seam
- `assets/content/` — playable library JSON
- `assets/guides/` — parent curriculum guides

## Parent zone highlights

- PIN gate with lockout after failed attempts
- Screen-time soft lock → `/rest`
- Weekly insights (rule-based), export JSON, delete child
- Accessibility: text scale, reading ease, high contrast, reduced motion
- Premium map: free stages 1–5; Premium 6–10 (sandbox only outside store IAP)

## Related docs

- Root `README.md` — monorepo overview  
- `docs/LAUNCH_RUNBOOK.md` — what only you can do (accounts, legal, assets)  
- `docs/BACKEND_PATH.md` — Firebase vs Nest for v1  
