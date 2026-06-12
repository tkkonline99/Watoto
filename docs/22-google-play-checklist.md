# 22. Google Play Deployment Checklist

## Families Policy / Designed for Families (the hard gates)

- [ ] Target audience & content: select age groups (Ages 5 & under, 6–8, 9–12) → app becomes subject to **Families Policy**
- [ ] **No ads** declared and true; no ad SDKs present (verify transitive dependencies — Play scans for non-certified SDKs)
- [ ] Only **Families-certified SDKs** in child-facing builds; Firebase configured child-safe (no AdId, `firebase_analytics` with ad signals off); `com.google.android.gms.permission.AD_ID` **removed** from merged manifest
- [ ] **Teacher Approved** program questionnaire submitted (optional but valuable — pedagogy notes ready)
- [ ] Parental gate before any commerce/links/settings; no external links in child UI
- [ ] No requesting location, contacts, phone; mic permission only with runtime rationale (Reading Coach) and parental consent precondition
- [ ] Content ratings questionnaire (IARC): Everyone, no violence/fear elements

## Data Safety Form

- [ ] Data collected: email (parents, account mgmt), audio (optional, child, ephemeral ≤30 d), app interactions (analytics, not shared)
- [ ] "Data shared": none with third parties for advertising; processors listed (Firebase, AWS, OpenAI) per current form guidance
- [ ] Deletion: in-app account deletion path declared + web deletion URL (`watoto.app/delete-account`)
- [ ] Encryption in transit: yes; user can request deletion: yes

## Billing

- [ ] Play Billing Library 6+; products `premium_monthly`, `premium_annual` (subscriptions with base plans/offers)
- [ ] Real-Time Developer Notifications: Pub/Sub topic → push to `/v1/webhooks/google`, OIDC-authenticated
- [ ] Test purchases via license testers: purchase, renew, cancel, grace, hold, restore, refund → entitlement transitions verified
- [ ] Paywall disclosure compliant (price, period, cancel anytime), parent-gated

## Build & Release

- [ ] `applicationId app.watoto`; minSdk 24, targetSdk = current requirement; App Bundle (AAB) with Play App Signing
- [ ] ProGuard/R8 rules verified (Firebase, Rive, drift native libs)
- [ ] Pre-launch report on internal track reviewed (crashes, a11y warnings, screenshots on real devices)
- [ ] Store listing: title, short/full description (no misleading claims), screenshots phone+tablet (7" & 10"), feature graphic, icon
- [ ] Privacy policy URL set; App content section fully completed (Families, ads, target audience, data safety, government app = no, COVID = no)
- [ ] Countries: launch set incl. Kenya, Tanzania, Uganda, Nigeria, Ghana, ZA, US, UK, FR, CA + expand later
- [ ] Release: internal → closed → production **staged rollout 10% → 50% → 100%** with halt criteria (crash rate >0.5%, ANR >0.3%)
- [ ] Android App Links verified for `watoto.app` (parent web → app deep links)

## Post-Launch

- [ ] Monitor Play Console: Families policy compliance messages, pre-launch reports on each release
- [ ] RTDN production events verified end-to-end
- [ ] Review responses within 48 h during launch window; safety-related reviews escalated same-day
