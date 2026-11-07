/**
 * Watoto backend — Payments (Gate 7). Completes the verifyPurchase hook and keeps
 * entitlement in sync with the stores. See PAYMENTS_README.md.
 *
 * Identity link: the client sets the store's account token to the Firebase uid at
 * purchase time — Apple `appAccountToken`, Google `obfuscatedExternalAccountId` — so
 * store notifications can be mapped back to the right account.
 *
 * Secrets (set via `firebase functions:secrets` / config, never in code):
 *   APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (.p8 contents), APPLE_BUNDLE_ID
 *   GOOGLE_PACKAGE_NAME  (+ a service account with Play access via GOOGLE_APPLICATION_CREDENTIALS)
 */
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import * as crypto from "node:crypto";
import { GoogleAuth } from "google-auth-library";

// Mirrors backend/products.json — keep in sync.
const PRODUCTS: Record<string, { tier: string; periodDays: number }> = {
  "watoto.premium.monthly": { tier: "premium", periodDays: 30 },
  "watoto.premium.annual": { tier: "premium", periodDays: 365 },
};

function b64urlJson(segment: string): any {
  return JSON.parse(Buffer.from(segment, "base64url").toString("utf8"));
}

/**
 * Decode + optionally verify an Apple JWS (x5c chain).
 *
 * When APPLE_JWS_REQUIRE_VERIFY=true (recommended in production), the leaf
 * certificate's public key must verify the ES256 signature. Full Apple Root CA
 * pinning should still be added before hard launch (store the Apple Root CA G3
 * PEM in secrets and walk x5c → root).
 */
function decodeJWS(jws: string, opts?: { requireVerify?: boolean }): any {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWS compact serialization");
  const [headerB64, payloadB64, sigB64] = parts;
  const header = b64urlJson(headerB64);
  const requireVerify =
    opts?.requireVerify ?? process.env.APPLE_JWS_REQUIRE_VERIFY === "true";

  if (requireVerify) {
    const x5c: string[] | undefined = header.x5c;
    if (!x5c?.length) {
      throw new Error("JWS missing x5c certificate chain");
    }
    if (header.alg !== "ES256") {
      throw new Error(`Unsupported JWS alg: ${header.alg}`);
    }
    // Leaf cert (first x5c element) is DER base64.
    const leafPem =
      "-----BEGIN CERTIFICATE-----\n" +
      x5c[0].match(/.{1,64}/g)!.join("\n") +
      "\n-----END CERTIFICATE-----";
    const signingInput = `${headerB64}.${payloadB64}`;
    const sig = Buffer.from(sigB64, "base64url");
    // Apple uses IEEE-P1363 (r||s) for ES256 in many payloads.
    const verifyOnce = (dsaEncoding?: "ieee-p1363" | "der") => {
      const v = crypto.createVerify("SHA256");
      v.update(signingInput);
      v.end();
      return dsaEncoding
        ? v.verify({ key: leafPem, dsaEncoding }, sig)
        : v.verify(leafPem, sig);
    };
    const ok = verifyOnce("ieee-p1363") || verifyOnce("der") || verifyOnce();
    if (!ok) throw new Error("JWS signature verification failed");
  }

  return b64urlJson(payloadB64);
}

async function setEntitlement(uid: string, plan: "premium" | "free", expiryMs: number | null) {
  await getFirestore().collection("accounts").doc(uid).set(
    { plan, entitlementExpiry: expiryMs ? Timestamp.fromMillis(expiryMs) : null },
    { merge: true }
  );
}

// ---- Apple: signed JWT for the App Store Server API ----
function appleBearer(): string {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: process.env.APPLE_KEY_ID, typ: "JWT" };
  const payload = {
    iss: process.env.APPLE_ISSUER_ID, iat: now, exp: now + 1800,
    aud: "appstoreconnect-v1", bid: process.env.APPLE_BUNDLE_ID,
  };
  const enc = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const signingInput = `${enc(header)}.${enc(payload)}`;
  const sig = crypto.sign("sha256", Buffer.from(signingInput),
    { key: process.env.APPLE_PRIVATE_KEY as string, dsaEncoding: "ieee-p1363" });
  return `${signingInput}.${sig.toString("base64url")}`;
}

async function verifyApple(transactionId: string): Promise<{ productId: string; expiryMs: number; uid?: string }> {
  const host = "https://api.storekit.itunes.apple.com"; // sandbox: api.storekit-sandbox.itunes.apple.com
  const res = await fetch(`${host}/inApps/v1/subscriptions/${transactionId}`, {
    headers: { Authorization: `Bearer ${appleBearer()}` },
  });
  if (!res.ok) throw new HttpsError("permission-denied", `Apple verification failed (${res.status}).`);
  const body: any = await res.json();
  const item = body.data?.[0]?.lastTransactions?.[0];
  if (!item) throw new HttpsError("not-found", "No Apple subscription found.");
  const tx = decodeJWS(item.signedTransactionInfo);
  return { productId: tx.productId, expiryMs: Number(tx.expiresDate), uid: tx.appAccountToken };
}

// ---- Google: Play Developer API subscriptionsv2 ----
async function googleAccessToken(): Promise<string> {
  const auth = new GoogleAuth({ scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
  const client = await auth.getClient();
  const t = await client.getAccessToken();
  return t.token as string;
}

async function verifyGoogle(purchaseToken: string): Promise<{ productId: string; expiryMs: number; uid?: string }> {
  const pkg = process.env.GOOGLE_PACKAGE_NAME;
  const res = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/purchases/subscriptionsv2/tokens/${purchaseToken}`,
    { headers: { Authorization: `Bearer ${await googleAccessToken()}` } }
  );
  if (!res.ok) throw new HttpsError("permission-denied", `Google verification failed (${res.status}).`);
  const body: any = await res.json();
  const line = body.lineItems?.[0];
  if (!line) throw new HttpsError("not-found", "No Google subscription found.");
  return {
    productId: line.productId,
    expiryMs: new Date(line.expiryTime).getTime(),
    uid: body.externalAccountIdentifiers?.obfuscatedExternalAccountId,
  };
}

/**
 * verifyPurchase — called by the client right after a store purchase.
 * data: { platform: "apple" | "google"; receipt: string; productId: string }
 *   receipt = Apple transactionId or Google purchaseToken.
 */
export const verifyPurchase = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in as the account holder.");
  const platform = req.data?.platform;
  const receipt = String(req.data?.receipt ?? "");
  if (!receipt) throw new HttpsError("invalid-argument", "receipt is required.");

  const v = (platform === "apple" || platform === "ios") ? await verifyApple(receipt)
          : (platform === "google" || platform === "android") ? await verifyGoogle(receipt)
          : (() => { throw new HttpsError("invalid-argument", "Unknown platform."); })();
  const result = await v;

  if (!PRODUCTS[result.productId]) throw new HttpsError("failed-precondition", "Unknown product.");
  const active = result.expiryMs > Date.now();
  await setEntitlement(uid, active ? "premium" : "free", active ? result.expiryMs : null);
  return { ok: true, plan: active ? "premium" : "free", entitlementExpiry: result.expiryMs };
});

/** Apple App Store Server Notifications V2 → keep entitlement current. */
export const appleNotifications = onRequest(async (request, response) => {
  try {
    const payload = decodeJWS(request.body.signedPayload);            // { notificationType, data }
    const tx = decodeJWS(payload.data.signedTransactionInfo);          // productId, expiresDate, appAccountToken
    const uid = tx.appAccountToken;
    if (uid) {
      const active = Number(tx.expiresDate) > Date.now()
        && !["EXPIRED", "REFUND", "REVOKE"].includes(payload.notificationType);
      await setEntitlement(uid, active ? "premium" : "free", active ? Number(tx.expiresDate) : null);
    }
    response.status(200).send("ok");
  } catch (e) {
    console.error("apple notification error", e);
    response.status(400).send("bad notification");
  }
});

/** Google Real-time Developer Notifications (Pub/Sub push) → keep entitlement current. */
export const googleNotifications = onRequest(async (request, response) => {
  try {
    const msg = b64urlJson(request.body.message.data);                 // { subscriptionNotification: { purchaseToken } }
    const token = msg.subscriptionNotification?.purchaseToken;
    if (token) {
      const v = await verifyGoogle(token);                             // re-read current status
      if (v.uid) {
        const active = v.expiryMs > Date.now();
        await setEntitlement(v.uid, active ? "premium" : "free", active ? v.expiryMs : null);
      }
    }
    response.status(200).send("ok");
  } catch (e) {
    console.error("google notification error", e);
    response.status(400).send("bad notification");
  }
});
