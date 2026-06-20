# Watoto — Payments & Premium Specification (Gate 7)

This completes the `verifyPurchase` hook from the backend. It defines how Watoto sells a subscription, how entitlements are verified and kept in sync, and how that stays honest for a children's app.

## The platform rule that shapes everything

For digital subscriptions **inside the iOS/Android app**, Apple and Google require their own in-app purchase systems — **StoreKit / In-App Purchase** on iOS and **Google Play Billing** on Android. You may not use Stripe (or any outside processor) for in-app digital goods on mobile. Stripe is only relevant if you later add a **web** purchase flow on your own site; the same entitlement model below would apply, with Stripe's webhooks in place of the store notifications. The earlier "Stripe + Play Billing" note is corrected here to **Apple IAP + Play Billing for the app**.

## Model

Freemium: a genuinely useful **Free** tier plus a **Premium** subscription. Premium is the only paid layer (no consumables, no per-item purchases, no ads ever). The exact free/premium split is a business decision for [Company]; a sensible, child-respectful default:

- **Free:** the early stages in full, plus a rotating sample from later stages, single child profile, online play.
- **Premium:** the entire Birth–Grade-4 curriculum, offline downloads, and multiple child profiles.

Gating principles (non-negotiable for this audience): never interrupt a child mid-activity to sell; never show a child a purchase prompt — buying happens only behind the **parent gate**; mark premium content clearly and calmly; and keep the free experience meaningful rather than a crippled demo.

## Product catalog

Defined once in `backend/products.json` and shared by client and server. Default products:

| Product id | Tier | Period |
|---|---|---|
| `watoto.premium.monthly` | premium | 1 month, auto-renewing |
| `watoto.premium.annual` | premium | 1 year, auto-renewing |

Create these with identical ids in **App Store Connect** and the **Play Console**. Add or rename freely — the server reads period/tier from this file, so the two stay aligned.

## Purchase and verification flow

1. Behind the parent gate, the parent taps Subscribe; the client starts the purchase through StoreKit 2 (iOS) or Play Billing (Android).
2. The store returns a signed transaction (iOS) or purchase token (Android).
3. The client calls the `verifyPurchase` Cloud Function with `{ platform, receipt, productId }`.
4. The server validates it directly with the **App Store Server API** or the **Google Play Developer API**, derives the plan and expiry from the validated subscription, and writes the **server-only** `plan` and `entitlementExpiry` onto the account document. Clients cannot write those fields (see `firestore.rules`), so entitlement can't be spoofed.
5. The client reads entitlement from the account doc and unlocks Premium. Because entitlement lives on the account, it syncs across the family's devices automatically.

## Keeping entitlement in sync (renewals, cancellations, refunds)

Subscriptions change over time without the app being open, so the server listens for store notifications and updates entitlement on its own:

- **Apple:** App Store Server Notifications V2 → the `appleNotifications` HTTPS endpoint handles `DID_RENEW`, `EXPIRED`, `DID_CHANGE_RENEWAL_STATUS`, `REFUND`.
- **Google:** Real-time Developer Notifications delivered via Pub/Sub → the `googleNotifications` endpoint handles renew / expire / revoke / refund.

Each updates `entitlementExpiry` (or drops `plan` to free) so a lapsed or refunded subscription stops unlocking content, and a renewal extends it — with no client involvement.

## Restore and cross-device

Because entitlement is on the account and not the device, signing in on a new device restores Premium immediately. A "Restore Purchases" action simply re-runs store restore and re-verifies, which is also the fallback if a notification was missed.

## Consumer and children's-protection notes

Purchases sit behind the parent gate and are made by the adult account holder (ties to `TERMS_OF_SERVICE.md` §4). Show the price, period, and auto-renew terms before purchase, and surface cancellation instructions — auto-renewable subscriptions carry specific disclosure duties under store rules and consumer law in each market. Refunds for store purchases are handled by Apple/Google, not [Company]. Confirm the disclosures and any market-specific rules with counsel.

## Files

- `backend/functions/src/payments.ts` — `verifyPurchase` (completed) plus the Apple/Google notification handlers and entitlement writes.
- `backend/products.json` — the product catalog above.
- `auth/entitlements.ts` — client adapter: read entitlement, gate Premium features, start a purchase, restore.

## What only you can do

Create the products in App Store Connect and the Play Console; generate the App Store Server API key (.p8, issuer id, key id) and a Google service account with Play access; and register the notification endpoints (Apple ASSN URL; Google Pub/Sub topic). Add these as function secrets/config — the code reads them from there. A Dart mirror of `entitlements.ts` for the Flutter client is available on request, matching the existing `auth/flutter` adapter.
