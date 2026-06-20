/**
 * Watoto client — entitlements (Gate 7). Reads the server-verified entitlement off the
 * account document and gates Premium features; starts purchases and restores through a
 * platform PurchaseBridge. See PAYMENTS_README.md.
 *
 * The TS/JS layer cannot perform native in-app purchases itself, so the actual StoreKit /
 * Play Billing call lives behind PurchaseBridge, implemented per platform (native plugin
 * or a wrapper such as RevenueCat). The bridge MUST set the store account token to the
 * Firebase uid — Apple `appAccountToken`, Google `obfuscatedExternalAccountId` — so the
 * server can map store notifications back to this account.
 */
import { getAuth } from "firebase/auth";
import { getFirestore, doc, onSnapshot, getDoc } from "firebase/firestore";
import { getFunctions, httpsCallable } from "firebase/functions";

export interface Entitlement {
  plan: "free" | "premium";
  entitlementExpiry: number | null; // epoch ms
  isPremium: boolean;
}

export interface PurchaseBridge {
  /** Launch the native purchase UI; resolve once the store confirms the transaction. */
  buy(productId: string, accountToken: string): Promise<{ platform: "apple" | "google"; receipt: string }>;
  /** Re-sync past purchases from the store (fallback if a notification was missed). */
  restore(accountToken: string): Promise<{ platform: "apple" | "google"; receipt: string } | null>;
}

function toEntitlement(data: any): Entitlement {
  const plan = data?.plan === "premium" ? "premium" : "free";
  const expiryMs = data?.entitlementExpiry?.toMillis?.() ?? data?.entitlementExpiry ?? null;
  const isPremium = plan === "premium" && typeof expiryMs === "number" && expiryMs > Date.now();
  return { plan, entitlementExpiry: expiryMs, isPremium };
}

/** One-shot read of the current entitlement. */
export async function getEntitlement(): Promise<Entitlement> {
  const uid = getAuth().currentUser?.uid;
  if (!uid) return { plan: "free", entitlementExpiry: null, isPremium: false };
  const snap = await getDoc(doc(getFirestore(), "accounts", uid));
  return toEntitlement(snap.data());
}

/** Live entitlement; fires on purchase, renewal, cancellation, refund. Returns unsubscribe. */
export function watchEntitlement(cb: (e: Entitlement) => void): () => void {
  const uid = getAuth().currentUser?.uid;
  if (!uid) { cb({ plan: "free", entitlementExpiry: null, isPremium: false }); return () => {}; }
  return onSnapshot(doc(getFirestore(), "accounts", uid), (s) => cb(toEntitlement(s.data())));
}

/** Gate a Premium feature. Returns true if the (verified) entitlement allows it. */
export async function isUnlocked(): Promise<boolean> {
  return (await getEntitlement()).isPremium;
}

/**
 * Start a subscription purchase. Call only from behind the parent gate.
 * Buys via the bridge, then asks the server to verify and set entitlement.
 */
export async function subscribe(productId: string, bridge: PurchaseBridge): Promise<Entitlement> {
  const uid = getAuth().currentUser?.uid;
  if (!uid) throw new Error("Sign in as the account holder before purchasing.");
  const purchase = await bridge.buy(productId, uid);
  const verify = httpsCallable(getFunctions(), "verifyPurchase");
  await verify({ platform: purchase.platform, receipt: purchase.receipt, productId });
  return getEntitlement(); // entitlement is now written server-side; read it back
}

/** Restore purchases on a new device or after a missed notification. */
export async function restorePurchases(bridge: PurchaseBridge): Promise<Entitlement> {
  const uid = getAuth().currentUser?.uid;
  if (!uid) throw new Error("Sign in first.");
  const purchase = await bridge.restore(uid);
  if (purchase) {
    const verify = httpsCallable(getFunctions(), "verifyPurchase");
    await verify({ platform: purchase.platform, receipt: purchase.receipt, productId: "" });
  }
  return getEntitlement();
}
