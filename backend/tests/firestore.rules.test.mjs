/**
 * Watoto — Firestore rules tests (run in CI on every push).
 * Proves the security properties that protect children's data. Uses the Firebase
 * emulator via @firebase/rules-unit-testing. Run:
 *   cd backend && firebase emulators:exec --only firestore "node --test tests/"
 */
import { readFileSync } from "node:fs";
import { test, before, after } from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, Timestamp } from "firebase/firestore";

let env;
const PARENT = "parent_a";
const OTHER = "parent_b";
const asUser = (uid) => env.authenticatedContext(uid).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "watoto-rules-test",
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
    },
  });
});
after(async () => { await env.cleanup(); });

test("parent can create and read their own account", async () => {
  const db = asUser(PARENT);
  await assertSucceeds(setDoc(doc(db, `accounts/${PARENT}`), { email: "p@example.com" }));
  await assertSucceeds(getDoc(doc(db, `accounts/${PARENT}`)));
});

test("a different signed-in user cannot read someone else's account", async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), `accounts/${PARENT}`), { email: "p@example.com" });
  });
  await assertFails(getDoc(doc(asUser(OTHER), `accounts/${PARENT}`)));
});

test("client cannot set the server-only entitlement field", async () => {
  const db = asUser(PARENT);
  await assertFails(setDoc(doc(db, `accounts/${PARENT}`), { email: "p@example.com", plan: "premium" }));
});

test("child profile rejects PII fields", async () => {
  const db = asUser(PARENT);
  await assertSucceeds(setDoc(doc(db, `accounts/${PARENT}/profiles/k1`), { displayName: "Kiddo", ageBand: "4-5" }));
  await assertFails(setDoc(doc(db, `accounts/${PARENT}/profiles/k2`), { displayName: "Kid", ageBand: "4-5", realName: "Real Name" }));
});

test("consent ledger is immutable to clients", async () => {
  const db = asUser(PARENT);
  const c = doc(db, `accounts/${PARENT}/consents/c1`);
  await assertSucceeds(setDoc(c, { method: "id-check", scope: "all", policyVersion: "2026-06" }));
  await assertFails(setDoc(c, { method: "tampered", scope: "all", policyVersion: "2026-06" }));
});

test("progress writes are last-write-wins by updatedAt", async () => {
  const db = asUser(PARENT);
  const pr = doc(db, `accounts/${PARENT}/profiles/k1/progress/s01.math.lesson.01`);
  await assertSucceeds(setDoc(pr, { status: "completed", updatedAt: Timestamp.fromMillis(2000) }));
  await assertFails(setDoc(pr, { status: "stale", updatedAt: Timestamp.fromMillis(1000) }));
});
