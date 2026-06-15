/**
 * Watoto auth — public API.
 *
 *   import { ensureAnonymousSession, signUpParent, getIdToken } from "@/auth";
 *
 * Typical flow:
 *   1. App launch:            await ensureAnonymousSession()   // child can play offline
 *   2. Parent taps "Account": show parent gate (makeParentGate / checkParentGate)
 *   3. Behind the gate:       signUpParent() or signInParent()
 *   4. Manage kids:           addChild / listChildren / updateChild / removeChild
 *   5. Call AWS backend:      Authorization: `Bearer ${await getIdToken()}`
 */
export { app, auth, db } from "./firebase";

export {
  ensureAnonymousSession,
  signUpParent,
  signInParent,
  resetParentPassword,
  resendVerification,
  signOut,
  getIdToken,
  observeAuth,
  currentUser,
  CONSENT_POLICY_VERSION,
  type AuthUser,
} from "./auth";

export {
  addChild,
  listChildren,
  updateChild,
  removeChild,
  stageForBand,
  type ChildProfile,
  type AgeBand,
} from "./childProfiles";

export {
  makeParentGate,
  checkParentGate,
  type ParentGateChallenge,
} from "./parentGate";
