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
export const PRODUCTS: Record<string, { tier: string; periodDays: number }> = {
  "watoto.premium.monthly": { tier: "premium", periodDays: 30 },
  "watoto.premium.annual": { tier: "premium", periodDays: 365 },
};

export function b64urlJson(segment: string): any {
  return JSON.parse(Buffer.from(segment, "base64url").toString("utf8"));
}

/**
 * SHA-256 fingerprint of Apple Root CA - G3, the anchor for every App Store
 * signed payload (https://www.apple.com/certificateauthority/). Overridable via
 * APPLE_ROOT_CA_SHA256 so tests (or a future Apple root rotation) can supply
 * their own anchor without a code change.
 */
export const APPLE_ROOT_CA_G3_SHA256 =
  "63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79";

/**
 * Walk an x5c chain leaf → intermediate → root: each certificate must be
 * issued and signed by the next, all must be inside their validity window,
 * and the last must be the pinned Apple root. Without this, a JWS carrying a
 * self-signed leaf would "verify" against its own key.
 */
export function verifyX5cChain(x5c: string[], now: Date = new Date()): crypto.X509Certificate {
  if (x5c.length < 2) throw new Error("JWS x5c chain too short");
  const certs = x5c.map((b64) => new crypto.X509Certificate(Buffer.from(b64, "base64")));
  for (const c of certs) {
    if (now < new Date(c.validFrom) || now > new Date(c.validTo)) {
      throw new Error(`JWS certificate outside validity window: ${c.subject}`);
    }
  }
  for (let i = 0; i < certs.length - 1; i++) {
    const child = certs[i], parent = certs[i + 1];
    if (!child.checkIssued(parent) || !child.verify(parent.publicKey)) {
      throw new Error("JWS certificate chain is broken");
    }
  }
  const root = certs[certs.length - 1];
  const pinned = (process.env.APPLE_ROOT_CA_SHA256 || APPLE_ROOT_CA_G3_SHA256).toUpperCase();
  if (root.fingerprint256.toUpperCase() !== pinned) {
    throw new Error("JWS chain does not end at the Apple root CA");
  }
  return certs[0];
}

/**
 * Decode + verify an Apple JWS (x5c chain).
 *
 * Verification is ON by default: the x5c chain must lead to the pinned Apple
 * Root CA G3 and the leaf key must verify the ES256 signature. Set
 * APPLE_JWS_REQUIRE_VERIFY=false only for local emulator work.
 */
export function decodeJWS(jws: string, opts?: { requireVerify?: boolean }): any {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWS compact serialization");
  const [headerB64, payloadB64, sigB64] = parts;
  const header = b64urlJson(headerB64);
  const requireVerify =
    opts?.requireVerify ?? process.env.APPLE_JWS_REQUIRE_VERIFY !== "false";

  if (requireVerify) {
    const x5c: string[] | undefined = header.x5c;
    if (!x5c?.length) {
      throw new Error("JWS missing x5c certificate chain");
    }
    if (header.alg !== "ES256") {
      throw new Error(`Unsupported JWS alg: ${header.alg}`);
    }
    const leafKey = verifyX5cChain(x5c).publicKey;
    const signingInput = `${headerB64}.${payloadB64}`;
    const sig = Buffer.from(sigB64, "base64url");
    // Apple uses IEEE-P1363 (r||s) for ES256 in many payloads.
    const verifyOnce = (dsaEncoding?: "ieee-p1363" | "der") => {
      const v = crypto.createVerify("SHA256");
      v.update(signingInput);
      v.end();
      return dsaEncoding
        ? v.verify({ key: leafKey, dsaEncoding }, sig)
        : v.verify(leafKey, sig);
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

const APPLE_PROD_HOST = "https://api.storekit.itunes.apple.com";
const APPLE_SANDBOX_HOST = "https://api.storekit-sandbox.itunes.apple.com";

export async function verifyApple(transactionId: string): Promise<{ productId: string; expiryMs: number; uid?: string }> {
  const token = appleBearer();
  const encodedId = encodeURIComponent(transactionId);
  const prodUrl = `${APPLE_PROD_HOST}/inApps/v1/subscriptions/${encodedId}`;
  const sandboxUrl = `${APPLE_SANDBOX_HOST}/inApps/v1/subscriptions/${encodedId}`;

  let res = await fetch(
    process.env.APPLE_USE_SANDBOX === "true" ? sandboxUrl : prodUrl,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  // App Store Review tests production builds against the sandbox StoreKit
  // environment (Guideline 2.1). Fall back to sandbox when production returns
  // 404 / 400 (transaction not found in production).
  if (!res.ok && process.env.APPLE_USE_SANDBOX !== "true" && (res.status === 404 || res.status === 400)) {
    res = await fetch(sandboxUrl, {
      headers: { Authorization: `Bearer ${token}` },
    });
  }
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

export async function verifyGoogle(purchaseToken: string): Promise<{ productId: string; expiryMs: number; uid?: string }> {
  const pkg = process.env.GOOGLE_PACKAGE_NAME;
  const res = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
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
 * Validate a decoded store verification result against the calling user and
 * requested product before granting entitlement.
 */
export function assertReceiptMatchesCaller(
  result: { productId: string; expiryMs: number; uid?: string },
  callerUid: string,
  expectedProductId?: string,
): void {
  if (!PRODUCTS[result.productId]) {
    throw new HttpsError("failed-precondition", "Unknown product.");
  }
  if (expectedProductId && expectedProductId !== result.productId) {
    throw new HttpsError("failed-precondition", "Product ID mismatch.");
  }
  if (result.uid && result.uid !== callerUid) {
    throw new HttpsError("permission-denied", "Receipt belongs to a different account.");
  }
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
  const expectedProductId = req.data?.productId ? String(req.data.productId) : undefined;
  if (!receipt) throw new HttpsError("invalid-argument", "receipt is required.");

  const result = (platform === "apple" || platform === "ios") ? await verifyApple(receipt)
          : (platform === "google" || platform === "android") ? await verifyGoogle(receipt)
          : (() => { throw new HttpsError("invalid-argument", "Unknown platform."); })();

  assertReceiptMatchesCaller(result, uid, expectedProductId);
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
