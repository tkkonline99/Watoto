# Free-only offline release checklist

Use this for the **first store ship** with `PUBLISH_FREE_ONLY=true` (default).  
Full cloud + IAP steps live in `21-app-store-checklist.md` / `22-google-play-checklist.md` for Phase 2.

## Build & version

- [ ] Local preflight: `powershell -File apps/mobile/tool/preflight-release.ps1` (tests + hero art + docs)
- [ ] `apps/mobile/pubspec.yaml` version matches marketing (`1.0.0+…`)
- [ ] Android AAB: `pwsh apps/mobile/tool/build-android.ps1 -Target appbundle -Mode release`
- [ ] iOS (Mac/CI): `pwsh apps/mobile/tool/build-ios.ps1 -Mode release` or `-Ipa`
- [ ] Confirm dart-define: `PUBLISH_FREE_ONLY=true` (unlocks stages 1–10, hides IAP)
- [ ] CI: GitHub `mobile-test` job green; free-only AAB/IPA as needed

## Store listing (no IAP claims)

- [ ] Paste metadata from `STORE_LISTING.md` (EN + FR/SW as needed)
- [ ] Free-only long description: **all ten stages free offline** (no purchase required)
- [ ] Feature graphic: `store-assets/feature_graphic_1024x500.png`
- [ ] Screenshots per `SCREENSHOT_WALKTHROUGH.md` (script: `tool/screenshot-walkthrough.ps1`)
- [ ] Support + privacy URLs live (host `docs/site/`; replace placeholders)
- [ ] Category: **Education** (not Apple Kids single-band — see STORE_LISTING)

## Privacy & families (free-only truths)

- [ ] **No ads** / no ad SDKs in child path
- [ ] **No IAP** in this build — Data Safety / App Privacy: do **not** declare in-app purchases
- [ ] Parent gate (PIN) still used for parent zone, settings, legal
- [ ] Privacy policy + terms match offline free launch (attorney sign-off)
- [ ] Microphone only if Reading Coach / voice consent path ships (else omit)

## In-app free-only sanity

- [ ] Child home: Play now works offline
- [ ] Stages 1–10 open without lock screen
- [ ] Parent zone: “Everything is free offline” (no paywall CTA)
- [ ] Screenshot mode: triple-tap lock → Amani demo seed
- [ ] EN / FR / SW language switch
- [ ] Celebration → Keep going; high-five first day optional

## Review notes (paste into store consoles)

```
Watoto free offline launch. No account or IAP required.
Demo: complete onboarding or triple-tap the parent lock on child home
(screenshot mode) to seed child "Amani" with progress. Parent PIN default
from onboarding (demo often 1234). All stages unlocked. No ads.
```

## Explicitly deferred (Phase 2)

- Firebase auth, cloud sync, entitlement server  
- Premium monthly/annual products + restore  
- `PUBLISH_FREE_ONLY=false` builds  

## Related docs

| Doc | Use |
|-----|-----|
| `LAUNCH_RUNBOOK.md` | Ordered launch steps |
| `STORE_LISTING.md` | Paste-ready listing text |
| `SCREENSHOT_WALKTHROUGH.md` | Capture frames |
| `APP_IDS.md` | Bundle / application IDs |
| `site/` | Privacy/support hosting stubs |
