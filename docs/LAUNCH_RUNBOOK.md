# Watoto — Master Launch Runbook

This is the single document that ties everything together: where each launch gate stands, the one honest list of what only you can do, the order to do it in, the open flags to resolve, and a map of every file delivered. It supersedes the per-area notes for planning purposes; each gate points to its own README for detail.

## Where the project stands

The product is built. The curriculum is complete and validated — **565 activities across all ten stages (Birth–Grade 4)**, every one available in **English, French, and Swahili (3,348 strings per language, 100%)**. The content engine, auth, backend, payments, legal drafts, asset manifests, store listing, and CI are all delivered as working code, deployable config, or paste-ready documents. What remains is the work only you can do because it needs your accounts, your money, a lawyer's signature, or assets to be produced — none of which a code assistant can stand in for. That work is listed plainly below.

## Gate status

| # | Gate | Status | Delivered | Remains (yours) |
|---|---|---|---|---|
| 1 | Product shell | ✅ Done | App shell, `README.md` | — |
| 2 | Content engine | ✅ Done | 3 players, validators, pipelines | — |
| 3 | Content volume | ✅ Done | 565 items, all stages, validated | — |
| 4 | Translation FR/SW | ✅ Done | 3,348/3,348 each, 100% | Reauthor language-specific lines before audio (see flags) |
| 5 | Auth | 🟢 Free-only offline ready | Local auth + Firebase seam (`setup_firebase.md`) | Optional: create Firebase for cloud accounts |
| 6 | Backend | 🟢 Optional for free-only | `backend/` deployable | Optional: deploy Firebase project |
| 7 | Payments | ⏸ Deferred | Free-only launch (`PUBLISH_FREE_ONLY=true`) | Later: store products + IAP bridge |
| 8 | Compliance | 🟢 Publish copy in app | Production privacy/terms + `docs/site/` | Host site on your domain; attorney review recommended |
| 9 | Store listings | 🟡 Kit ready | `STORE_LISTING.md` + package ids fixed | Developer accounts; screenshots; submit forms |
| 10 | iOS/Android build | 🟡 Config ready | Bundle ids + signing hooks | Signing secrets; tag release |

Gates 1–4 are finished outright. Gates 5–10 are finished on the code/document side and gated only on your external actions.

## What only you can do — the consolidated list

Grouped by type, with rough cost and effort. This is the whole list; nothing here is hidden in the per-gate docs.

**Accounts and infrastructure**
- Create a **Firebase project**, enable Firestore, and set the **Blaze** plan (pay-as-you-go; usage stays within the free allowance at launch volume). Finishes Gates 5 and 6. ~30 min.
- **Apple Developer Program** membership — **USD 99/year**. Needed for Gates 9 and 10.
- **Google Play Console** account — **USD 25 one-time**. Needed for Gates 9 and 10.
- A **domain / simple website** to host the privacy policy and support pages the stores require — ~USD 10–15/year. Needed for Gates 8 and 9.

**Money / commerce**
- Create the **subscription products** (`watoto.premium.monthly`, `watoto.premium.annual`) in App Store Connect and the Play Console with identical ids.
- Generate the **App Store Connect API key** (.p8) and a **Google Play service account**; these drive both purchase verification and store uploads.
- Register the **store notification endpoints** (Apple ASSN V2 URL; Google Pub/Sub topic) so renewals/refunds keep entitlement in sync.

**Legal**
- Engage a **licensed attorney** to review and finalize `PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md`, and `COMPLIANCE_SIGNOFF.md`, set every bracketed value, and localize for your markets. This is the one gate that genuinely needs a professional; the drafts give them a head start, not a substitute.

**Production assets**
- Produce **audio** from `audio_manifest.csv` and **images** from `image_manifest.csv` (TTS or voice talent; illustration). Run the language-specific reauthoring pass first (below).

**Hardware / build**
- No Mac required — the cloud macOS runner in CI is the Mac. You only add **signing secrets** and tag a release; the pipeline builds and uploads to TestFlight and Play internal.

## Recommended launch sequence

1. **Stand up the project.** Create the Firebase project, enable Firestore, set Blaze billing. Deploy `backend/` (`firebase deploy --only firestore:rules,firestore:indexes,functions`). Point the auth/client config at the project. Gates 5 and 6 are now live.
2. **Get legal moving in parallel** — it has the longest lead time. Hand the three legal documents to your attorney; stand up the website with the finalized privacy and support pages.
3. **Set up commerce.** Create the two products and the API key/service account; add them as function secrets; register the notification endpoints. Gate 7 is now live end to end.
4. **Produce assets.** Reauthor the flagged language-specific lines, then generate audio and images to the manifest paths. Gate 4's content becomes fully narrated and illustrated.
5. **Build the store listings.** Create the app records, paste the metadata (fix the FR typo), complete the App Privacy / Data Safety / rating forms, upload screenshots.
6. **Wire CI and build.** Add the signing secrets; tag `v1.0.0`. The pipeline runs the rules tests, builds both platforms, and uploads to the test tracks.
7. **Test, then submit.** Exercise internal testing on both stores, confirm purchases and entitlement sync, then submit for review.
8. **Launch.**

## Open flags to resolve before release

- **Language-specific audio:** reading/writing lines that teach phonics, verb tenses, quotation punctuation, and idioms keep English examples on purpose and are flagged `review_for_locale` in `audio_manifest.csv`. Reauthor these per language before recording FR/SW; everything else records as-is.
- **Image text:** 59 images flagged `text_risk` in `image_manifest.csv` imply embedded words/letters — keep text as a separate overlay or supply per-locale variants.
- **Attorney sign-off:** every bracketed value in the three legal docs, the consent method, retention intervals, hosting regions, and the analytics opt-in/opt-out default must be set and reviewed; the privacy-form answers in the store kit must match the final build. Analytics opt-in is now **off by default** in the app (parent toggle).
- **Payments:** JWS leaf-cert verification is implemented when `APPLE_JWS_REQUIRE_VERIFY=true`; still pin Apple Root CA G3 before hard launch. Native purchase bridge must set store account token to Firebase uid. **Sandbox IAP is blocked in release** unless `ALLOW_SANDBOX_IAP=true`.
- **Placeholders:** replace `[com.company.watoto]` (bundle id / package name) and the `[https://company/...]` URLs throughout the configs and listing.
- **Content gating:** Free = stages **1–5**, Premium = **6–10** (wired in `entitlements.dart` as `freeStageMax = 5`). Confirm this matches store marketing copy.
- **FR listing typo:** fixed (`Watoz` → `Watoto` in `STORE_LISTING.md`).

## File index

**Content & translation**
- `watoto_content_library.json` — source of truth, 565 items.
- `i18n/en.json`, `i18n/fr.json`, `i18n/sw.json` — 3,348 strings each.
- `validate_content.py`, `check_i18n.py`, `extract_strings.py` — validators/extractors.
- `build.py`, `merge_s10_*.py`, `build_locale*.py`, `generate_content.py`, `translate_content.py` — authoring/translation pipeline.

**Asset manifests**
- `build_audio_manifest.py` + `audio_manifest.json` (and the `audio_manifest.csv` / `audio_sfx_manifest.csv` it generates) + `AUDIO_README.md`.
- `build_image_manifest.py` + `image_manifest.json` (and `image_manifest.csv`) + `IMAGE_README.md`.

**Auth & client**
- `auth/` (`firebase.ts`, `auth.ts`, `parentGate.ts`, `childProfiles.ts`, `entitlements.ts`, `index.ts`, `flutter/`) + `AUTH_README.md`.

**Backend & payments**
- `backend/firestore.rules`, `backend/firestore.indexes.json`, `backend/firebase.json`, `backend/products.json`.
- `backend/functions/src/index.ts`, `backend/functions/src/payments.ts`, `+ package.json/tsconfig`.
- `backend/tests/firestore.rules.test.mjs` + `package.json`.
- `BACKEND_README.md`, `PAYMENTS_README.md`.

**Legal**
- `PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md`, `COMPLIANCE_SIGNOFF.md`.

**Store & build**
- `STORE_LISTING.md`.
- `.github/workflows/build.yml`, `codemagic.yaml`, `BUILD_README.md`.

**This document:** `LAUNCH_RUNBOOK.md`.

## Cost summary

| Item | Cost | When |
|---|---|---|
| Apple Developer Program | USD 99 / year | Before Gates 9–10 |
| Google Play Console | USD 25 once | Before Gates 9–10 |
| Firebase (Blaze) | ~USD 0 at launch, scales with use | At Gate 6 |
| Domain + simple site | ~USD 10–15 / year | Before Gates 8–9 |
| Audio production | Variable (TTS low; voice talent higher) | At asset step |
| Illustration | Variable | At asset step |
| Attorney review | Variable (their fee) | Gate 8 |
| CI | Free tier covers a solo cadence | Gate 10 |

That is the complete picture. The build is done; the runway above is yours to walk.
