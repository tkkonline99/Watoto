// Watoto entitlements — FlutterFire (Dart) adapter.
//
// Mirrors auth/entitlements.ts 1:1 so gating and purchase behaviour are identical
// across stacks. Reads the server-verified entitlement off the account document
// (accounts/{uid}) and gates Premium features; starts purchases and restores
// through a platform PurchaseBridge.
//
// The Dart layer cannot perform native in-app purchases itself, so the actual
// StoreKit / Play Billing call lives behind PurchaseBridge, implemented per
// platform (e.g. the in_app_purchase plugin or a wrapper such as RevenueCat).
// The bridge MUST set the store account token to the Firebase uid — Apple
// `appAccountToken`, Google `obfuscatedExternalAccountId` — so the server can
// map store notifications back to this account.
//
// Setup:
//   flutter pub add firebase_auth cloud_firestore cloud_functions
//   (and your IAP package, e.g. in_app_purchase, for the PurchaseBridge impl)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _db = FirebaseFirestore.instance;
final FirebaseFunctions _functions = FirebaseFunctions.instance;

/// The server-verified entitlement for the signed-in account.
class Entitlement {
  final String plan; // 'free' | 'premium'
  final DateTime? entitlementExpiry;
  final bool isPremium;

  const Entitlement({
    required this.plan,
    required this.entitlementExpiry,
    required this.isPremium,
  });

  static const Entitlement free =
      Entitlement(plan: 'free', entitlementExpiry: null, isPremium: false);

  factory Entitlement.fromDoc(Map<String, dynamic>? data) {
    final plan = data?['plan'] == 'premium' ? 'premium' : 'free';
    final raw = data?['entitlementExpiry'];
    final DateTime? expiry = raw is Timestamp
        ? raw.toDate()
        : (raw is int ? DateTime.fromMillisecondsSinceEpoch(raw) : null);
    final isPremium =
        plan == 'premium' && expiry != null && expiry.isAfter(DateTime.now());
    return Entitlement(
        plan: plan, entitlementExpiry: expiry, isPremium: isPremium);
  }
}

/// Result of a store purchase/restore. `platform` is 'apple' or 'google'.
class PurchaseResult {
  final String platform;
  final String receipt; // Apple transactionId or Google purchaseToken
  const PurchaseResult({required this.platform, required this.receipt});
}

/// Implemented per platform. The native layer launches the store UI and MUST
/// set the store account token to [accountToken] (the Firebase uid).
abstract class PurchaseBridge {
  /// Launch the native purchase UI; complete once the store confirms.
  Future<PurchaseResult> buy(String productId, String accountToken);

  /// Re-sync past purchases (fallback if a store notification was missed).
  Future<PurchaseResult?> restore(String accountToken);
}

class WatotoEntitlements {
  /// One-shot read of the current entitlement.
  static Future<Entitlement> getEntitlement() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Entitlement.free;
    final snap = await _db.collection('accounts').doc(uid).get();
    return Entitlement.fromDoc(snap.data());
  }

  /// Live entitlement; emits on purchase, renewal, cancellation, refund.
  static Stream<Entitlement> watchEntitlement() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<Entitlement>.value(Entitlement.free);
    return _db
        .collection('accounts')
        .doc(uid)
        .snapshots()
        .map((s) => Entitlement.fromDoc(s.data()));
  }

  /// Gate a Premium feature. True if the (verified) entitlement allows it.
  static Future<bool> isUnlocked() async {
    return (await getEntitlement()).isPremium;
  }

  /// Start a subscription purchase. Call only from behind the parent gate.
  /// Buys via the bridge, then asks the server to verify and set entitlement.
  static Future<Entitlement> subscribe(
      String productId, PurchaseBridge bridge) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in as the account holder before purchasing.');
    }
    final purchase = await bridge.buy(productId, uid);
    final verify = _functions.httpsCallable('verifyPurchase');
    await verify.call(<String, dynamic>{
      'platform': purchase.platform,
      'receipt': purchase.receipt,
      'productId': productId,
    });
    return getEntitlement(); // entitlement is now written server-side
  }

  /// Restore purchases on a new device or after a missed notification.
  static Future<Entitlement> restorePurchases(PurchaseBridge bridge) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in first.');
    final purchase = await bridge.restore(uid);
    if (purchase != null) {
      final verify = _functions.httpsCallable('verifyPurchase');
      await verify.call(<String, dynamic>{
        'platform': purchase.platform,
        'receipt': purchase.receipt,
        'productId': '',
      });
    }
    return getEntitlement();
  }
}
