/// Native IAP bridge seam for Apple/Google (improvement 6 — business).
///
/// Free-only launch uses [UnconfiguredPurchaseBridge] / sandbox.
/// When ready:
///   1. `flutter pub add in_app_purchase`
///   2. Implement [StoreKitPlayPurchaseBridge]
///   3. Call Cloud Function `verifyPurchase` before granting entitlement
///   4. Build with `--dart-define=PUBLISH_FREE_ONLY=false`
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

/// Native StoreKit 2 / Google Play Billing bridge over MethodChannel
/// (`app.watoto.iap`).
class StoreKitPlayPurchaseBridge implements PurchaseBridge {
  StoreKitPlayPurchaseBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.watoto.iap');

  final MethodChannel _channel;

  @override
  Future<({String platform, String receipt})> buy(
    String productId,
    String accountToken,
  ) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('buy', {
      'productId': productId,
      'accountToken': accountToken,
    });
    final receipt = result?['receipt'] as String?;
    if (receipt == null || receipt.isEmpty) {
      throw StateError(
        'Store purchase did not return a receipt for $productId.',
      );
    }
    final platform = result?['platform'] as String? ??
        (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    return (platform: platform, receipt: receipt);
  }

  @override
  Future<({String platform, String receipt})?> restore(
    String accountToken,
  ) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'restore',
        {'accountToken': accountToken},
      );
      final receipt = result?['receipt'] as String?;
      if (receipt == null || receipt.isEmpty) return null;
      final platform = result?['platform'] as String? ??
          (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      return (platform: platform, receipt: receipt);
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('[iap] restore requested for $accountToken (no native plugin)');
      }
      return null;
    }
  }
}

/// Verifies a store receipt against the backend (`POST /v1/billing/verify` or
/// `WATOTO_VERIFY_PURCHASE_URL`) before granting premium entitlement.
Future<({bool valid, DateTime? expiry})> verifyStoreReceiptHttp({
  required String platform,
  required String productId,
  required String receipt,
  required String accountToken,
  http.Client? client,
  String? verifyUrl,
}) async {
  final httpClient = client ?? http.Client();
  final url = verifyUrl ??
      const String.fromEnvironment(
        'WATOTO_VERIFY_PURCHASE_URL',
        defaultValue: 'http://localhost:3000/v1/billing/verify',
      );
  final res = await httpClient
      .post(
        Uri.parse(url),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'platform': platform,
          'productId': productId,
          'receipt': receipt,
          'accountToken': accountToken,
        }),
      )
      .timeout(const Duration(seconds: 12));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    return (valid: false, expiry: null);
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final valid = body['valid'] == true;
  final expiryRaw = body['entitlementExpiry'] as String?;
  final expiry = expiryRaw != null ? DateTime.tryParse(expiryRaw) : null;
  return (valid: valid, expiry: expiry);
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
