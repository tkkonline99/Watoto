import test from "node:test";
import assert from "node:assert/strict";
import * as crypto from "node:crypto";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { execFileSync } from "node:child_process";
import { decodeJWS, verifyX5cChain, APPLE_ROOT_CA_G3_SHA256 } from "./payments";

/**
 * Builds a throwaway root → intermediate → leaf EC chain with openssl, the
 * same shape Apple uses for App Store signed payloads, so the chain walk and
 * the root pin are exercised end to end.
 */
function makeChain() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "x5c-"));
  const ossl = (...args: string[]) => execFileSync("openssl", args, { cwd: dir, stdio: "pipe" });
  const ext = path.join(dir, "ca.ext");
  fs.writeFileSync(ext, "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n");
  for (const n of ["root", "int", "leaf"]) {
    ossl("ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", `${n}.key`);
  }
  ossl("req", "-x509", "-new", "-key", "root.key", "-subj", "/CN=Test Root", "-days", "2",
    "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign",
    "-out", "root.pem");
  ossl("req", "-new", "-key", "int.key", "-subj", "/CN=Test Intermediate", "-out", "int.csr");
  ossl("x509", "-req", "-in", "int.csr", "-CA", "root.pem", "-CAkey", "root.key",
    "-CAcreateserial", "-days", "2", "-extfile", ext, "-out", "int.pem");
  ossl("req", "-new", "-key", "leaf.key", "-subj", "/CN=Test Leaf", "-out", "leaf.csr");
  ossl("x509", "-req", "-in", "leaf.csr", "-CA", "int.pem", "-CAkey", "int.key",
    "-CAcreateserial", "-days", "2", "-out", "leaf.pem");

  const der = (f: string) =>
    new crypto.X509Certificate(fs.readFileSync(path.join(dir, f))).raw.toString("base64");
  const rootFp = new crypto.X509Certificate(fs.readFileSync(path.join(dir, "root.pem"))).fingerprint256;
  const leafKey = fs.readFileSync(path.join(dir, "leaf.key"), "utf8");
  const x5c = [der("leaf.pem"), der("int.pem"), der("root.pem")];
  fs.rmSync(dir, { recursive: true, force: true });
  return { x5c, rootFp, leafKey };
}

function signJws(payload: object, x5c: string[], key: string): string {
  const h = Buffer.from(JSON.stringify({ alg: "ES256", x5c })).toString("base64url");
  const p = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const sig = crypto.sign("sha256", Buffer.from(`${h}.${p}`), { key, dsaEncoding: "ieee-p1363" });
  return `${h}.${p}.${sig.toString("base64url")}`;
}

const chain = makeChain();

test("verification is on by default (fail closed)", () => {
  delete process.env.APPLE_JWS_REQUIRE_VERIFY;
  const h = Buffer.from(JSON.stringify({ alg: "ES256" })).toString("base64url");
  const p = Buffer.from(JSON.stringify({ productId: "x" })).toString("base64url");
  assert.throws(() => decodeJWS(`${h}.${p}.sig`), /missing x5c/);
});

test("the production pin is Apple Root CA G3", () => {
  assert.match(APPLE_ROOT_CA_G3_SHA256, /^63:34:3A:BF/);
});

test("a chain to the pinned root verifies and decodes", () => {
  process.env.APPLE_ROOT_CA_SHA256 = chain.rootFp;
  try {
    const jws = signJws({ productId: "watoto.premium.monthly" }, chain.x5c, chain.leafKey);
    assert.equal(decodeJWS(jws, { requireVerify: true }).productId, "watoto.premium.monthly");
  } finally {
    delete process.env.APPLE_ROOT_CA_SHA256;
  }
});

test("a valid chain to an unpinned root is rejected (no self-made Apple)", () => {
  delete process.env.APPLE_ROOT_CA_SHA256; // pin stays the real Apple root
  const jws = signJws({ productId: "watoto.premium.monthly" }, chain.x5c, chain.leafKey);
  assert.throws(() => decodeJWS(jws, { requireVerify: true }), /Apple root CA/);
});

test("a lone self-signed leaf is rejected", () => {
  assert.throws(() => verifyX5cChain([chain.x5c[2]]), /too short/);
});

test("a reordered chain is rejected", () => {
  process.env.APPLE_ROOT_CA_SHA256 = chain.rootFp;
  try {
    assert.throws(() => verifyX5cChain([chain.x5c[1], chain.x5c[0], chain.x5c[2]]), /broken/);
  } finally {
    delete process.env.APPLE_ROOT_CA_SHA256;
  }
});

test("a tampered payload fails the signature check", () => {
  process.env.APPLE_ROOT_CA_SHA256 = chain.rootFp;
  try {
    const jws = signJws({ productId: "watoto.premium.monthly" }, chain.x5c, chain.leafKey);
    const [h, , s] = jws.split(".");
    const forged = Buffer.from(JSON.stringify({ productId: "watoto.premium.annual" })).toString("base64url");
    assert.throws(() => decodeJWS(`${h}.${forged}.${s}`, { requireVerify: true }), /signature verification failed/);
  } finally {
    delete process.env.APPLE_ROOT_CA_SHA256;
  }
});
