# Publish checklist (free-only launch, no payments)

This release is configured for **PUBLISH_FREE_ONLY=true** (default): all stages unlock, paywall does not sell IAP.

## Done in the repo

- [x] Production privacy + terms in `apps/mobile/assets/legal/` (no “working draft” H1)
- [x] Hostable web pages in `docs/site/` (privacy, terms, home)
- [x] Publish identity in `lib/core/config/publish_config.dart` (emails, URLs, package ids)
- [x] Free-only entitlement gating (`effectiveFreeStageMax = 10`)
- [x] Paywall explains free release when free-only
- [x] Android `applicationId` = `app.watoto.watoto_mobile`
- [x] iOS bundle id = `app.watoto.watotoMobile`
- [x] Content art heuristics cover all items via starter pack
- [x] Release builds ban Nest dev-token; sandbox IAP blocked
- [x] Firebase setup guide for optional cloud (`apps/mobile/tool/setup_firebase.md`)
- [x] Adaptive next-best “Play now” + streak shield + quest loop
- [x] Password/PIN recovery + 90-day nickname policy
- [x] Family backup export for reinstall handoff
- [x] Kids Category checklist (`docs/KIDS_CATEGORY_CHECKLIST.md`)
- [x] Crash reporting + analytics seams (opt-in)
- [x] IAP bridge seam (`iap_bridge.dart`) for post-free launch

## You must still do (cannot be automated)

### 1. Domain + host legal pages (required by stores)

1. Buy/point a domain (default assumed: `watoto.app`) **or** change dart-defines:
   ```
   --dart-define=WATOTO_WEBSITE_URL=https://YOUR.domain
   --dart-define=WATOTO_SUPPORT_EMAIL=you@YOUR.domain
   --dart-define=WATOTO_PRIVACY_EMAIL=privacy@YOUR.domain
   ```
2. Deploy `docs/site/` so these URLs work:
   - `https://YOUR.domain/privacy`
   - `https://YOUR.domain/terms`
3. Optionally re-copy the full markdown from `assets/legal/` onto those pages for one-to-one match.

### 2. Legal review (strongly recommended)

- Have a licensed attorney review privacy + terms for your markets (COPPA, GDPR-K, local consumer law).
- Update company legal name / address via dart-defines if different from defaults.

### 3. Developer accounts + signing

| Item | Action |
|------|--------|
| Google Play | $25 one-time; create app with package `app.watoto.watoto_mobile` |
| Apple Developer | $99/year; create app with bundle `app.watoto.watotoMobile` |
| Android upload key | Create keystore → `android/key.properties` or CI secrets |
| iOS distribution | Cert + profile → CI secrets or Codemagic |

### 4. Store listing

Use `docs/STORE_LISTING.md`. Set:

- Privacy policy URL → your hosted `/privacy`
- Support URL / email → support@…  
- Age rating / Kids category forms honestly  
- Screenshots from a real device (home, play, parent zone)  
- **Do not claim IAP** while free-only; say all stages free  

### 5. Optional cloud (Firebase)

Not required for free offline launch. When ready: `apps/mobile/tool/setup_firebase.md`.

### 6. Build & submit

```bash
cd apps/mobile
flutter pub get
flutter gen-l10n
flutter test
# Android
flutter build appbundle --release
# iOS (macOS / Codemagic)
flutter build ipa --release
```

Or tag a release and use GitHub Actions / Codemagic with signing secrets filled.

### 7. Final QA on devices

- [ ] Fresh install → onboarding → complete 3 activities offline  
- [ ] Airplane mode still works  
- [ ] Parent PIN gate, screen time rest screen  
- [ ] Privacy / terms open and match website  
- [ ] No crash on cold start / background  
- [ ] No payment buttons claiming real IAP  

---

## After payments (later)

```
--dart-define=PUBLISH_FREE_ONLY=false
```

Then wire StoreKit / Play Billing + `verifyPurchase` (see `backend/PAYMENTS_README.md`).
