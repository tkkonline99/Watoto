/**
 * Watoto backend — Cloud Functions (Firebase, TypeScript, v2 API).
 *
 * These implement the server-only operations that Security Rules deliberately forbid
 * clients from doing directly: writing the consent ledger metadata, exporting and
 * deleting account data (PRIVACY_POLICY.md §9–§10 and Appendix A), and setting paid
 * entitlements after a verified store purchase (PAYMENTS spec — implemented in ./payments).
 *
 * Identity comes from Firebase Auth (see ../auth). The authenticated principal is the
 * parent/account holder; request.auth.uid === the account document id.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, Timestamp, QueryDocumentSnapshot } from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

export const GRACE_DAYS = 14;               // soft-delete grace before hard purge (see runbook)
export const POLICY_VERSION = "2026-06-01"; // aligned with publish_config.dart consentPolicyVersionLabel

function requireAuth(req: { auth?: { uid?: string } }): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in as the account holder.");
  return uid;
}

/**
 * Record a parental-consent event in the append-only ledger.
 * data: { method: string; scope: string; profileId?: string }
 */
export const recordConsent = onCall(async (req) => {
  const uid = requireAuth(req);
  const method = String(req.data?.method ?? "");
  const scope = String(req.data?.scope ?? "");
  if (!method || !scope) throw new HttpsError("invalid-argument", "method and scope are required.");
  const ref = db.collection("accounts").doc(uid).collection("consents").doc();
  await ref.set({
    method,
    scope,
    profileId: req.data?.profileId ?? null,
    policyVersion: POLICY_VERSION,
    timestamp: FieldValue.serverTimestamp(),
  });
  return { ok: true, consentId: ref.id, policyVersion: POLICY_VERSION };
});

/**
 * Export everything we hold for this account: the account record, child profiles,
 * their progress, and the consent ledger. Backs the parental-review and GDPR
 * data-portability rights. Returns a single JSON object.
 */
export const exportAccountData = onCall(async (req) => {
  const uid = requireAuth(req);
  const accRef = db.collection("accounts").doc(uid);
  const acc = await accRef.get();
  if (!acc.exists) throw new HttpsError("not-found", "No account data.");

  const profilesSnap = await accRef.collection("profiles").get();
  const profiles = [];
  for (const p of profilesSnap.docs) {
    const progressSnap = await p.ref.collection("progress").get();
    profiles.push({
      id: p.id,
      profile: p.data(),
      progress: progressSnap.docs.map((d: QueryDocumentSnapshot) => ({ itemId: d.id, ...d.data() })),
    });
  }
  const consentsSnap = await accRef.collection("consents").get();

  return {
    exportedAt: new Date().toISOString(),
    account: acc.data(),
    profiles,
    consents: consentsSnap.docs.map((d: QueryDocumentSnapshot) => ({ id: d.id, ...d.data() })),
  };
});

/**
 * Parent-initiated account deletion. Soft-deletes immediately (sets deletedAt and a
 * purgeAfter date) so an accidental request can be reversed during the grace window;
 * the scheduled job below performs the irreversible purge.
 */
export const requestAccountDeletion = onCall(async (req) => {
  const uid = requireAuth(req);
  const purgeAfter = Timestamp.fromMillis(Date.now() + GRACE_DAYS * 86400_000);
  await db.collection("accounts").doc(uid).set(
    { deletedAt: FieldValue.serverTimestamp(), purgeAfter },
    { merge: true }
  );
  return { ok: true, purgeAfter: purgeAfter.toDate().toISOString(), graceDays: GRACE_DAYS };
});

/**
 * Scheduled purge: hard-delete accounts whose grace window has passed, including all
 * subcollections (profiles, progress, consents), and remove the Auth user. Implements
 * the retention runbook; logs each completion.
 */
export const hardDeleteExpiredAccounts = onSchedule("every 24 hours", async () => {
  const now = Timestamp.now();
  const due = await db.collection("accounts").where("purgeAfter", "<=", now).get();
  for (const doc of due.docs) {
    await db.recursiveDelete(doc.ref); // removes the account doc and all subcollections
    try {
      await getAuth().deleteUser(doc.id);
    } catch (err: any) {
      if (err?.code !== "auth/user-not-found") {
        console.error(JSON.stringify({ event: "auth_delete_error", uid: doc.id, code: err?.code }));
      }
    }
    console.log(JSON.stringify({ event: "account_purged", uid: doc.id, at: now.toDate().toISOString() }));
  }
});

/**
 * Payments (Gate 7). verifyPurchase and the Apple/Google store-notification handlers are
 * implemented in ./payments and re-exported here so they deploy as Cloud Functions.
 * verifyPurchase validates a store receipt and writes the server-only entitlement fields
 * (plan, entitlementExpiry) that clients are forbidden to set (see ../firestore.rules).
 */
export { verifyPurchase, appleNotifications, googleNotifications } from "./payments";
