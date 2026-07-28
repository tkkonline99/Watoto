# Kids Category / Families Policy checklist (improvement 5)

Use before App Store Kids Category and Google Play Families Policy submission.

## Child experience

- [x] No third-party ads in child UI
- [x] No external links on child surfaces (parent zone only for legal)
- [x] No open chat / UGC between children
- [x] Parent gate before account create, purchases, data export, delete
- [x] Analytics opt-in off by default
- [x] Screen-time soft lock with rest screen
- [ ] Real-device review: no accidental browser opens
- [ ] Confirm TTS does not upload audio off-device

## Data & privacy

- [x] In-app privacy + terms
- [x] Hostable pages in `docs/site/`
- [ ] Privacy URL live on your domain
- [ ] Data Safety / App Privacy forms match build
- [ ] Attorney review for COPPA / GDPR-K

## Free-only launch

- [x] `PUBLISH_FREE_ONLY=true` unlocks stages 1–10
- [x] Paywall does not sell IAP in free-only mode
- [ ] Store listing does **not** claim subscriptions
- [ ] Screenshots show free content only

## Accessibility

- [x] Text scale, high contrast, dyslexia spacing, reduced motion toggles
- [x] Large tap targets on primary buttons
- [ ] Full VoiceOver / TalkBack pass on home + play + parent

## Crash & quality

- [x] Unit/widget tests in CI
- [ ] Crash-free session target ≥99.6% on beta devices
- [ ] Airplane-mode lesson → reward → home loop verified

## When enabling Premium later

- [ ] `PUBLISH_FREE_ONLY=false`
- [ ] Store products + `in_app_purchase` bridge
- [ ] Server `verifyPurchase` only grants entitlement
- [ ] Update privacy (payment processors) + listing
