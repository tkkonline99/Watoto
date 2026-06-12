# 21. App Store (iOS) Deployment Checklist

## Kids Category & Guideline 1.3 / 5.1.4 (the hard gates)

- [ ] App enrolled in **Kids Category** (age bands: select "9–11 and under" coverage via 5 & Under + 6–8 + 9–11)
- [ ] **No third-party advertising** — confirmed none
- [ ] No third-party analytics that collect identifiers from child sessions — Firebase Analytics configured: `allow_ad_personalization_signals=false`, no IDFA; confirm Apple's current stance on first-party analytics in Kids apps at submission time
- [ ] **No external links / purchases reachable by children** — all commerce, account, settings, and any links behind the **parental gate** (PIN); gate itself meets Apple guidance (not a simple "tap to confirm")
- [ ] Privacy policy URL in metadata + in-app (parent surfaces)
- [ ] COPPA/GDPR-K compliance statement ready for review notes
- [ ] No requesting unnecessary permissions; mic permission string explains Reading Coach, requested only after parental consent toggle

## Privacy

- [ ] **Privacy Nutrition Labels** completed: data collected (email — parents only; audio — child, optional, not linked to identity for tracking; usage data — not used for tracking), no tracking, no IDFA
- [ ] `NSMicrophoneUsageDescription` (Reading Coach), no other sensitive permissions
- [ ] Account deletion available in-app (Guideline 5.1.1(v)) — Parent Zone → Privacy → Delete account
- [ ] Sign in with Apple offered (required since third-party login (Google) is offered)

## In-App Purchase

- [ ] IAP products created: `premium_monthly`, `premium_annual` (auto-renewable, family-shareable OFF), localized prices/descriptions
- [ ] Subscription group + upgrade/downgrade paths configured
- [ ] App Store Server Notifications v2 URL set (prod + sandbox)
- [ ] Restore Purchases button present (paywall + settings)
- [ ] Paywall shows price, term, auto-renew disclosure, ToS + privacy links (parent-gated screen)
- [ ] Sandbox-tested: purchase, renew (accelerated), cancel, grace, refund → entitlement transitions verified

## Build & Metadata

- [ ] Xcode project: bundle id `app.watoto`, deployment target iOS 14+, all device families tested (iPhone SE → iPad)
- [ ] App icon set, no alpha; launch screen; orientation: portrait (phone), both (iPad)
- [ ] Screenshots per device class (child UI shown truthfully), preview video optional
- [ ] Age rating questionnaire: 4+ ; made-for-kids declarations consistent everywhere
- [ ] Description avoids prohibited claims; keywords; support URL; marketing URL
- [ ] Export compliance: standard encryption exemption declared (HTTPS only)
- [ ] Review notes: demo parent account + PIN, demo child profile, how to reach premium content, note on parental gate location
- [ ] Crash-free session rate >99.5% on TestFlight before submitting
- [ ] Phased release enabled; release version tagged and matching CI artifact

## Post-Approval

- [ ] Verify live IAP with a real purchase + refund test
- [ ] Monitor App Store reviews for safety reports (daily during launch window)
- [ ] Confirm ASSN v2 production events flowing to `/v1/webhooks/apple`
