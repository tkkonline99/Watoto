/**
 * Authentication for Watoto.
 *
 * Design (COPPA-aware): CHILDREN NEVER CREATE CREDENTIALED ACCOUNTS.
 *   - A PARENT signs in with email + password and owns everything.
 *   - Before any account exists, the app runs under an ANONYMOUS session so a
 *     child can play offline immediately (no data, no sign-up wall).
 *   - When a parent later creates an account, the anonymous session is UPGRADED
 *     in place (progress is preserved) via linkWithCredential.
 *   - getIdToken() returns a Firebase ID token (a signed JWT). This REPLACES
 *     the dev tokens you were sending to the AWS backend — see AUTH_README.md
 *     for how the backend verifies it.
 *
 * Parental consent is recorded at sign-up (timestamp + policy version) so the
 * compliance gate has an audit trail.
 */
import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signInAnonymously,
  signOut as fbSignOut,
  sendEmailVerification,
  sendPasswordResetEmail,
  onAuthStateChanged,
  linkWithCredential,
  EmailAuthProvider,
  updateProfile,
  type User,
} from "firebase/auth";
import { doc, setDoc, serverTimestamp } from "firebase/firestore";
import { auth, db } from "./firebase";

export const CONSENT_POLICY_VERSION = "2026-06-01";

export type AuthUser = {
  uid: string;
  email: string | null;
  isAnonymous: boolean;
  emailVerified: boolean;
};

function toAuthUser(u: User): AuthUser {
  return { uid: u.uid, email: u.email, isAnonymous: u.isAnonymous, emailVerified: u.emailVerified };
}

/** Start (or resume) an anonymous session. Safe to call on app launch. */
export async function ensureAnonymousSession(): Promise<AuthUser> {
  if (auth.currentUser) return toAuthUser(auth.currentUser);
  const { user } = await signInAnonymously(auth);
  return toAuthUser(user);
}

/**
 * Create a parent account. If a child has been playing anonymously, this
 * UPGRADES that session so progress carries over instead of creating a
 * separate empty account. `consent` must be true (gathered behind the
 * parent gate) — we store it for the compliance record.
 */
export async function signUpParent(
  email: string,
  password: string,
  opts: { displayName?: string; consent: boolean },
): Promise<AuthUser> {
  if (!opts.consent) throw new Error("Parental consent is required to create an account.");

  let user: User;
  const current = auth.currentUser;
  if (current?.isAnonymous) {
    const cred = EmailAuthProvider.credential(email, password);
    ({ user } = await linkWithCredential(current, cred)); // anon -> parent, keeps uid + data
  } else {
    ({ user } = await createUserWithEmailAndPassword(auth, email, password));
  }

  if (opts.displayName) await updateProfile(user, { displayName: opts.displayName });
  await sendEmailVerification(user);

  // consent + account record (no child PII here).
  // Path MUST match backend/firestore.rules: accounts/{uid}
  await setDoc(
    doc(db, "accounts", user.uid),
    {
      email,
      displayName: opts.displayName ?? null,
      consent: { granted: true, policyVersion: CONSENT_POLICY_VERSION, at: serverTimestamp() },
      createdAt: serverTimestamp(),
    },
    { merge: true },
  );

  return toAuthUser(user);
}

export async function signInParent(email: string, password: string): Promise<AuthUser> {
  const { user } = await signInWithEmailAndPassword(auth, email, password);
  return toAuthUser(user);
}

export async function resetParentPassword(email: string): Promise<void> {
  await sendPasswordResetEmail(auth, email);
}

export async function resendVerification(): Promise<void> {
  if (auth.currentUser && !auth.currentUser.isAnonymous) {
    await sendEmailVerification(auth.currentUser);
  }
}

export async function signOut(): Promise<void> {
  await fbSignOut(auth);
}

/**
 * The token to send to your AWS backend (replaces the dev token).
 * Firebase auto-refreshes it; pass forceRefresh=true right after sign-in if
 * you need the freshest claims. Returns null if somehow unauthenticated.
 *
 *   const token = await getIdToken();
 *   fetch(API, { headers: { Authorization: `Bearer ${token}` } });
 */
export async function getIdToken(forceRefresh = false): Promise<string | null> {
  const u = auth.currentUser;
  return u ? u.getIdToken(forceRefresh) : null;
}

/** Subscribe to auth changes (drive your navigation/state from this). */
export function observeAuth(cb: (user: AuthUser | null) => void): () => void {
  return onAuthStateChanged(auth, (u) => cb(u ? toAuthUser(u) : null));
}

export function currentUser(): AuthUser | null {
  return auth.currentUser ? toAuthUser(auth.currentUser) : null;
}
