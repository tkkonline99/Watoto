/**
 * Child profiles — stored UNDER the parent account, never as their own login.
 *
 * Data minimization (COPPA / GDPR-K): a profile holds only what the app needs
 * to personalize play — a display name (encourage a nickname, not a full legal
 * name), an age band that maps to a curriculum stage, and an avatar id. No
 * email, no birthdate, no contact info, no free-text that could carry PII.
 *
 * Firestore layout:  accounts/{parentUid}/profiles/{profileId}
 * Matches backend/firestore.rules. Do not use parents/children — rules deny it.
 */
import {
  collection,
  doc,
  addDoc,
  getDocs,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} from "firebase/firestore";
import { auth, db } from "./firebase";

// Age bands map directly to the 10 curriculum stages.
export type AgeBand =
  | "0-1" | "1-2" | "2-3" | "3-4" | "4-5"
  | "5-6" | "6-7" | "7-8" | "8-9" | "9-10";

const BAND_TO_STAGE: Record<AgeBand, number> = {
  "0-1": 1, "1-2": 2, "2-3": 3, "3-4": 4, "4-5": 5,
  "5-6": 6, "6-7": 7, "7-8": 8, "8-9": 9, "9-10": 10,
};

export function stageForBand(band: AgeBand): number {
  return BAND_TO_STAGE[band];
}

export type ChildProfile = {
  id: string;
  displayName: string; // nickname, not legal name
  ageBand: AgeBand;
  avatarId: string;
};

function childrenCol(parentUid: string) {
  return collection(db, "accounts", parentUid, "profiles");
}

function requireParentUid(): string {
  const u = auth.currentUser;
  if (!u || u.isAnonymous) throw new Error("A signed-in parent is required to manage profiles.");
  return u.uid;
}

export async function addChild(
  input: { displayName: string; ageBand: AgeBand; avatarId: string },
): Promise<ChildProfile> {
  const parentUid = requireParentUid();
  const ref = await addDoc(childrenCol(parentUid), {
    displayName: input.displayName.trim().slice(0, 24),
    ageBand: input.ageBand,
    avatarId: input.avatarId,
    createdAt: serverTimestamp(),
  });
  return { id: ref.id, ...input };
}

export async function listChildren(): Promise<ChildProfile[]> {
  const parentUid = requireParentUid();
  const snap = await getDocs(childrenCol(parentUid));
  return snap.docs.map((d) => {
    const data = d.data() as Omit<ChildProfile, "id">;
    return { id: d.id, displayName: data.displayName, ageBand: data.ageBand, avatarId: data.avatarId };
  });
}

export async function updateChild(
  childId: string,
  patch: Partial<{ displayName: string; ageBand: AgeBand; avatarId: string }>,
): Promise<void> {
  const parentUid = requireParentUid();
  await updateDoc(doc(db, "accounts", parentUid, "profiles", childId), patch);
}

export async function removeChild(childId: string): Promise<void> {
  const parentUid = requireParentUid();
  await deleteDoc(doc(db, "accounts", parentUid, "profiles", childId));
}
