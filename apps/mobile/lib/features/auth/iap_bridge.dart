/// Native IAP bridge seam for Apple/Google (improvement 6 — business).
///
/// Free-only launch uses [UnconfiguredPurchaseBridge] / sandbox.
/// When ready:
///   1. `flutter pub add in_app_purchase`
///   2. Implement [StoreKitPlayPurchaseBridge]
///   3. Call Cloud Function `verifyPurchase` before granting entitlement
///   4. Build with `--dart-define=PUBLISH_FREE_ONLY=false`
library;

import 'package:flutter/foundation.dart';

import 'entitlements.dart';

/// Product metadata for parent paywall UI.
class PremiumProduct {
  const PremiumProduct({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.period,
  });

  final String id;
  final String title;
  final String priceLabel; // store-localized when IAP live
  final String period; // 'month' | 'year'
}

/// Catalog shown on paywall (ids must match store consoles).
const premiumCatalog = <PremiumProduct>[
  PremiumProduct(
    id: premiumMonthlyId,
    title: 'Monthly',
    priceLabel: '—',
    period: 'month',
  ),
  PremiumProduct(
    id: premiumAnnualId,
    title: 'Annual',
    priceLabel: '—',
    period: 'year',
  ),
];

/// Placeholder native bridge — throws with setup instructions.
/// Replace body with `in_app_purchase` when store products exist.
class StoreKitPlayPurchaseBridge implements PurchaseBridge {
  @override
  Future<({String platform, String receipt})> buy(
    String productId,
    String accountToken,
  ) async {
    throw StateError(
      'Wire in_app_purchase: buy($productId) with '
      'applicationUserName/appAccountToken=$accountToken, then call '
      'verifyPurchase Cloud Function. See backend/PAYMENTS_README.md',
    );
  }

  @override
  Future<({String platform, String receipt})?> restore(
    String accountToken,
  ) async {
    if (kDebugMode) {
      debugPrint('[iap] restore requested for $accountToken');
    }
    return null;
  }
}

/// Chooses sandbox (debug), store bridge, or unconfigured.
PurchaseBridge resolvePurchaseBridge({bool preferStoreBridge = false}) {
  if (sandboxIapEnabled && !preferStoreBridge) {
    return SandboxPurchaseBridge();
  }
  if (preferStoreBridge) {
    return StoreKitPlayPurchaseBridge();
  }
  return UnconfiguredPurchaseBridge();
}
