/// Native IAP bridge seam + Cloud Functions / Firestore entitlement verification
/// for Apple StoreKit 2 and Google Play Billing.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

/// Normalizes platform names so both client (`ios` / `android`) and backend
/// (`apple` / `google`) conventions match.
String normalizeStorePlatform(String platform) {
  switch (platform.trim().toLowerCase()) {
    case 'ios':
    case 'apple':
    case 'appstore':
      return 'apple';
    case 'android':
    case 'google':
    case 'play':
      return 'google';
    default:
      return platform.trim().toLowerCase();
  }
}

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
    final platform =
        result?['platform'] as String? ??
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
      final platform =
          result?['platform'] as String? ??
          (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      return (platform: platform, receipt: receipt);
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint(
          '[iap] restore requested for $accountToken (no native plugin)',
        );
      }
      return null;
    }
  }
}

/// Parses an expiry timestamp returned by Cloud Functions or Firestore
/// (epoch milliseconds, [Timestamp], or ISO-8601 string).
DateTime? parseEntitlementExpiry(Object? raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate().toUtc();
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
  }
  if (raw is String && raw.isNotEmpty) {
    final asInt = int.tryParse(raw);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
    }
    return DateTime.tryParse(raw)?.toUtc();
  }
  return null;
}

/// Verifies a store receipt via the `verifyPurchase` Firebase Cloud Function
/// (`backend/functions/src/payments.ts`).
Future<({bool valid, DateTime? expiry})> verifyStoreReceiptCallable({
  required String platform,
  required String productId,
  required String receipt,
  required String accountToken,
  Future<Map<String, dynamic>> Function(Map<String, Object?> payload)? caller,
}) async {
  final invoke =
      caller ??
      ((Map<String, Object?> payload) async {
        final res = await FirebaseFunctions.instance
            .httpsCallable('verifyPurchase')
            .call<dynamic>(payload);
        final data = res.data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return <String, dynamic>{};
      });
  final body = await invoke(<String, Object?>{
    'platform': normalizeStorePlatform(platform),
    'productId': productId,
    'receipt': receipt,
    'accountToken': accountToken,
  });
  final valid =
      body['ok'] == true || body['valid'] == true || body['plan'] == 'premium';
  final expiry = parseEntitlementExpiry(body['entitlementExpiry']);
  return (valid: valid && body['plan'] != 'free', expiry: expiry);
}

/// Reads the authoritative server entitlement from `accounts/{uid}` in
/// Firestore (written by `verifyPurchase` / store notifications in
/// `backend/functions/src/payments.ts`).
Future<Entitlement?> fetchServerEntitlement(
  String uid, {
  FirebaseFirestore? firestore,
  Future<Map<String, dynamic>?> Function(String uid)? docReader,
}) async {
  final reader =
      docReader ??
      ((String id) async {
        final snap = await (firestore ?? FirebaseFirestore.instance)
            .collection('accounts')
            .doc(id)
            .get();
        return snap.data();
      });
  final data = await reader(uid);
  if (data == null) return null;
  final plan = (data['plan'] as String?) ?? 'free';
  final expiry = parseEntitlementExpiry(data['entitlementExpiry']);
  final now = DateTime.now().toUtc();
  final isPremium =
      plan == 'premium' && (expiry == null || expiry.isAfter(now));
  return Entitlement(
    plan: isPremium ? 'premium' : 'free',
    entitlementExpiry: expiry,
    isPremium: isPremium,
  );
}

/// Verifies a store receipt against the HTTP backend (`POST /v1/billing/verify`
/// or `WATOTO_VERIFY_PURCHASE_URL`) before granting premium entitlement.
Future<({bool valid, DateTime? expiry})> verifyStoreReceiptHttp({
  required String platform,
  required String productId,
  required String receipt,
  required String accountToken,
  http.Client? client,
  String? verifyUrl,
}) async {
  final httpClient = client ?? http.Client();
  final url =
      verifyUrl ??
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
