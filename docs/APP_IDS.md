# Watoto — Application identifiers

Canonical IDs for store consoles and signing. Keep Android and iOS **stable** once the first build is published (changing them creates a new app listing).

| Platform | Identifier | Where set |
|----------|------------|-----------|
| **Android** `applicationId` | `app.watoto.watoto_mobile` | `apps/mobile/android/app/build.gradle.kts` |
| **Android** namespace | `app.watoto.watoto_mobile` | same file |
| **iOS** bundle id | `app.watoto.watotoMobile` | Xcode `PRODUCT_BUNDLE_IDENTIFIER` |
| **Codemagic** | `app.watoto.watotoMobile` | `codemagic.yaml` |

Notes:

- Underscore vs camelCase is intentional Flutter tooling history; both are registered as **your** package names in each store.
- Checklists that mention bare `app.watoto` are shorthand — use the full IDs above when creating App Store Connect / Play Console records.
- Free-only launch does **not** require different IDs. Premium later uses the same IDs with `PUBLISH_FREE_ONLY=false`.

## Store URLs (fill before submit)

| Use | Placeholder | Your value |
|-----|-------------|------------|
| Privacy policy | `[https://company/privacy]` | |
| Support | `[https://company/support]` | |
| Marketing | `[https://company]` | |

Host the finalized `docs/legal/PRIVACY_POLICY.md` and `TERMS_OF_SERVICE.md` (attorney-reviewed) at HTTPS URLs. Stores reject `http://` and raw GitHub raw links for privacy in some cases — a simple static site is fine.

## Signing (Android)

Local: `apps/mobile/android/key.properties` (gitignored) pointing at your upload keystore.  
CI: `ANDROID_KEYSTORE_*` env vars (see `BUILD_README.md`).
