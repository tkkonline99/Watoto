import test from "node:test";
import assert from "node:assert/strict";
import * as crypto from "node:crypto";
import {
  PRODUCTS,
  b64urlJson,
  decodeJWS,
  assertReceiptMatchesCaller,
  verifyApple,
} from "./payments";
import { GRACE_DAYS, POLICY_VERSION } from "./index";

test("POLICY_VERSION and GRACE_DAYS match mobile publish_config contract", () => {
  assert.equal(POLICY_VERSION, "2026-06-01");
  assert.equal(GRACE_DAYS, 14);
});

test("PRODUCTS defines monthly and annual premium SKUs", () => {
  assert.deepEqual(PRODUCTS["watoto.premium.monthly"], {
    tier: "premium",
    periodDays: 30,
  });
  assert.deepEqual(PRODUCTS["watoto.premium.annual"], {
    tier: "premium",
    periodDays: 365,
  });
});

test("decodeJWS decodes payload when verification is disabled", () => {
  const header = Buffer.from(JSON.stringify({ alg: "ES256" })).toString("base64url");
  const payload = Buffer.from(
    JSON.stringify({
      productId: "watoto.premium.monthly",
      expiresDate: 1900000000000,
      appAccountToken: "uid-123",
    }),
  ).toString("base64url");
  const jws = `${header}.${payload}.sig`;
  const decoded = decodeJWS(jws, { requireVerify: false });
  assert.equal(decoded.productId, "watoto.premium.monthly");
  assert.equal(decoded.appAccountToken, "uid-123");
  assert.deepEqual(b64urlJson(header), { alg: "ES256" });
});

test("decodeJWS rejects missing x5c or bad alg when requireVerify is true", () => {
  const h1 = Buffer.from(JSON.stringify({ alg: "ES256" })).toString("base64url");
  const p = Buffer.from(JSON.stringify({ ok: true })).toString("base64url");
  assert.throws(
    () => decodeJWS(`${h1}.${p}.sig`, { requireVerify: true }),
    /JWS missing x5c certificate chain/,
  );

  const h2 = Buffer.from(
    JSON.stringify({ alg: "HS256", x5c: ["dGVzdA=="] }),
  ).toString("base64url");
  assert.throws(
    () => decodeJWS(`${h2}.${p}.sig`, { requireVerify: true }),
    /Unsupported JWS alg: HS256/,
  );
});

test("assertReceiptMatchesCaller enforces product SKU, product match, and uid binding", () => {
  // Valid receipt matching caller uid and productId
  assert.doesNotThrow(() =>
    assertReceiptMatchesCaller(
      {
        productId: "watoto.premium.monthly",
        expiryMs: Date.now() + 60_000,
        uid: "parent-uid-1",
      },
      "parent-uid-1",
      "watoto.premium.monthly",
    ),
  );

  // Unknown SKU -> failed-precondition
  assert.throws(
    () =>
      assertReceiptMatchesCaller(
        { productId: "watoto.unknown.sku", expiryMs: Date.now() + 60_000 },
        "parent-uid-1",
      ),
    /Unknown product/,
  );

  // Product ID mismatch -> failed-precondition
  assert.throws(
    () =>
      assertReceiptMatchesCaller(
        {
          productId: "watoto.premium.monthly",
          expiryMs: Date.now() + 60_000,
          uid: "parent-uid-1",
        },
        "parent-uid-1",
        "watoto.premium.annual",
      ),
    /Product ID mismatch/,
  );

  // Cross-account receipt replay -> permission-denied
  assert.throws(
    () =>
      assertReceiptMatchesCaller(
        {
          productId: "watoto.premium.monthly",
          expiryMs: Date.now() + 60_000,
          uid: "other-parent-uid",
        },
        "parent-uid-1",
      ),
    /Receipt belongs to a different account/,
  );
});

test("verifyApple falls back from production 404 to StoreKit sandbox", async () => {
  const { privateKey } = crypto.generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  process.env.APPLE_KEY_ID = "TESTKEY123";
  process.env.APPLE_ISSUER_ID = "00000000-0000-0000-0000-000000000000";
  process.env.APPLE_BUNDLE_ID = "com.watoto.watotoMobile";
  process.env.APPLE_PRIVATE_KEY = privateKey
    .export({ type: "pkcs8", format: "pem" })
    .toString();
  process.env.APPLE_JWS_REQUIRE_VERIFY = "false";
  delete process.env.APPLE_USE_SANDBOX;

  const header = Buffer.from(JSON.stringify({ alg: "ES256" })).toString("base64url");
  const payload = Buffer.from(
    JSON.stringify({
      productId: "watoto.premium.annual",
      expiresDate: 1950000000000,
      appAccountToken: "sandbox-reviewer-uid",
    }),
  ).toString("base64url");
  const fakeJws = `${header}.${payload}.sig`;

  const calledUrls: string[] = [];
  const origFetch = globalThis.fetch;
  globalThis.fetch = (async (input: string | URL | Request) => {
    const url = String(input);
    calledUrls.push(url);
    if (url.includes("api.storekit.itunes.apple.com")) {
      return new Response("Not found in production", { status: 404 });
    }
    return new Response(
      JSON.stringify({
        data: [
          {
            lastTransactions: [{ signedTransactionInfo: fakeJws }],
          },
        ],
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }) as typeof fetch;

  try {
    const res = await verifyApple("tx-sandbox-1001");
    assert.equal(calledUrls.length, 2);
    assert.match(calledUrls[0], /api\.storekit\.itunes\.apple\.com/);
    assert.match(calledUrls[1], /api\.storekit-sandbox\.itunes\.apple\.com/);
    assert.equal(res.productId, "watoto.premium.annual");
    assert.equal(res.expiryMs, 1950000000000);
    assert.equal(res.uid, "sandbox-reviewer-uid");
  } finally {
    globalThis.fetch = origFetch;
  }
});
