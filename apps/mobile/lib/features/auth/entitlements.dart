/// Client entitlements — Dart port of `auth/entitlements.ts`.
///
/// Free vs Premium gating. Server-verified entitlement is the source of truth
/// once Firebase is live; until then [LocalEntitlementStore] keeps a device-
/// local premium flag (for sandbox / parent "simulate purchase").
///
/// **Release safety:** [SandboxPurchaseBridge] is only used in debug builds
/// (or when `--dart-define=ALLOW_SANDBOX_IAP=true`). Release builds never
/// grant premium from a client-side stub.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/publish_config.dart';
import '../../core/offline/offline_providers.dart';
import '../../firebase/firebase_bootstrap.dart';
import '../../l10n/gen/app_localizations.dart';
import 'iap_bridge.dart';

/// Product ids — must match `backend/products.json` and store consoles.
const premiumMonthlyId = 'watoto.premium.monthly';
const premiumAnnualId = 'watoto.premium.annual';

/// Stages 1–[freeStageMax] are always free when not in free-only launch.
/// Prefer [effectiveFreeStageMax] for gating (respects PUBLISH_FREE_ONLY).
const int freeStageMax = 5;

/// True when local sandbox IAP is allowed (never in production release).
bool get sandboxIapEnabled {
  const force = bool.fromEnvironment('ALLOW_SANDBOX_IAP', defaultValue: false);
  if (force) return true;
  return !kReleaseMode;
}

class Entitlement {
  const Entitlement({
    required this.plan,
    required this.entitlementExpiry,
    required this.isPremium,
  });

  final String plan; // 'free' | 'premium'
  final DateTime? entitlementExpiry;
  final bool isPremium;

  static const free = Entitlement(
    plan: 'free',
    entitlementExpiry: null,
    isPremium: false,
  );
}

/// Whether [stage] (1–10) is unlocked for the current entitlement.
///
/// [freeMax] overrides the compile-time [effectiveFreeStageMax] ceiling. Read
/// it from [freeStageMaxProvider] in widgets so tests (and, later, remote
/// config) can exercise the paywall without a `--dart-define` rebuild.
bool isStageUnlocked(int stage, Entitlement e, {int? freeMax}) =>
    stage <= (freeMax ?? effectiveFreeStageMax) || e.isPremium;

/// Whether a library item at [stage] may be opened.
bool isContentUnlocked(int stage, Entitlement e, {int? freeMax}) =>
    isStageUnlocked(stage, e, freeMax: freeMax);

/// The highest stage playable without premium. Defaults to the build-time
/// [effectiveFreeStageMax] (10 during the free-only launch); override in tests
/// to put the paywall back in the path.
final freeStageMaxProvider = Provider<int>((ref) => effectiveFreeStageMax);

/// The free vs premium split for parent UI, in the family's language.
///
/// It used to be English prose, shown as-is on the Parent Dashboard and the
/// paywall to Swahili and French families alike. [freeOnly] defaults to the
/// build's [publishFreeOnly]; tests pass it to reach the split a paid build
/// would show.
String freePremiumMapSummary(
  AppLocalizations l10n, {
  required bool isPremium,
  bool? freeOnly,
}) {
  if (freeOnly ?? publishFreeOnly) return l10n.premiumMapFreeLaunch;
  if (isPremium) return l10n.premiumMapActive;
  return l10n.premiumMapSplit(freeStageMax, freeStageMax + 1);
}

final entitlementProvider = Provider<Entitlement>((ref) {
  // Rebuild when session bumps (profiles/login) or store premium changes.
  ref.watch(sessionProvider);
  final store = ref.watch(offlineStoreProvider);
  final raw = store.entitlementRaw;
  return Entitlement(
    plan: raw.plan,
    entitlementExpiry: raw.expiry,
    isPremium: raw.isPremium,
  );
});

final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(entitlementProvider).isPremium,
);

/// Parent-zone purchase actions. Real IAP goes through a [PurchaseBridge]
/// once store products exist; sandbox mode writes local premium for demos.
abstract interface class PurchaseBridge {
  Future<({String platform, String receipt})> buy(
    String productId,
    String accountToken,
  );
  Future<({String platform, String receipt})?> restore(String accountToken);
}

/// Offline / demo bridge — marks the account premium immediately so QA and
/// families can try the full catalog before store products are wired.
/// **Must not ship as the production path** — gated by [sandboxIapEnabled].
class SandboxPurchaseBridge implements PurchaseBridge {
  @override
  Future<({String platform, String receipt})> buy(
    String productId,
    String accountToken,
  ) async =>
      (platform: 'sandbox', receipt: 'sandbox:$productId:$accountToken');

  @override
  Future<({String platform, String receipt})?> restore(
    String accountToken,
  ) async =>
      (platform: 'sandbox', receipt: 'sandbox:restore:$accountToken');
}

/// Release-safe stub until StoreKit / Play Billing is wired.
class UnconfiguredPurchaseBridge implements PurchaseBridge {
  @override
  Future<({String platform, String receipt})> buy(
    String productId,
    String accountToken,
  ) async {
    throw StateError(
      'In-app purchases are not configured. '
      'Wire Apple/Google IAP or enable sandbox with ALLOW_SANDBOX_IAP=true for testing.',
    );
  }

  @override
  Future<({String platform, String receipt})?> restore(
    String accountToken,
  ) async =>
      null;
}

PurchaseBridge defaultPurchaseBridge() =>
    sandboxIapEnabled ? SandboxPurchaseBridge() : UnconfiguredPurchaseBridge();

/// Prefer native store bridge when free-only is off and sandbox is off.
PurchaseBridge productionAwarePurchaseBridge() {
  // Lazy import path: iap_bridge.dart documents StoreKit/Play wiring.
  if (!sandboxIapEnabled && !publishFreeOnly) {
    // Still unconfigured until in_app_purchase is added — explicit seam.
    return UnconfiguredPurchaseBridge();
  }
  return defaultPurchaseBridge();
}

typedef ReceiptVerifier = Future<({bool valid, DateTime? expiry})> Function({
  required String platform,
  required String productId,
  required String receipt,
  required String accountToken,
});

class EntitlementService {
  EntitlementService(
    this._store, {
    PurchaseBridge? bridge,
    this.verifier,
  }) : _bridge = bridge ?? productionAwarePurchaseBridge();

  final OfflineStore _store;
  final PurchaseBridge _bridge;
  final ReceiptVerifier? verifier;

  bool get isSandbox => _bridge is SandboxPurchaseBridge;

  Entitlement get current {
    final raw = _store.entitlementRaw;
    return Entitlement(
      plan: raw.plan,
      entitlementExpiry: raw.expiry,
      isPremium: raw.isPremium,
    );
  }

  /// Subscribe (parent-only). Sandbox writes local premium for 30 days.
  Future<Entitlement> subscribe(String productId, {String? accountToken}) async {
    final token = accountToken ?? 'local';
    final purchase = await _bridge.buy(productId, token);
    // Real path: call Cloud Function verifyPurchase with purchase.receipt.
    // Sandbox path: grant local premium only when sandbox bridge is active.
    if (purchase.platform == 'sandbox') {
      if (!sandboxIapEnabled) {
        throw StateError('Sandbox purchases blocked in release builds.');
      }
      final days = productId.contains('annual') ? 365 : 30;
      await _store.setLocalPremium(
        true,
        expiry: DateTime.now().add(Duration(days: days)),
        source: purchase.platform,
      );
      return current;
    }
    if (verifier != null) {
      final verified = await verifier!(
        platform: purchase.platform,
        productId: productId,
        receipt: purchase.receipt,
        accountToken: token,
      );
      if (!verified.valid) {
        throw StateError('Store receipt verification failed.');
      }
      final days = productId.contains('annual') ? 365 : 30;
      await _store.setLocalPremium(
        true,
        expiry: verified.expiry ?? DateTime.now().add(Duration(days: days)),
        source: purchase.platform,
      );
      return current;
    }
    // Real store receipt: client must not set premium; server verifies.
    throw StateError(
      'Store receipt received (${purchase.platform}) — call verifyPurchase Cloud Function next.',
    );
  }

  Future<Entitlement> restore({String? accountToken}) async {
    final token = accountToken ?? 'local';
    final purchase = await _bridge.restore(token);
    if (purchase == null) return current;
    if (purchase.platform == 'sandbox' && sandboxIapEnabled) {
      if (_store.hadPremiumBefore) {
        await _store.setLocalPremium(
          true,
          expiry: DateTime.now().add(const Duration(days: 30)),
          source: 'restore',
        );
      }
      return current;
    }
    if (verifier != null) {
      final verified = await verifier!(
        platform: purchase.platform,
        productId: premiumMonthlyId,
        receipt: purchase.receipt,
        accountToken: token,
      );
      if (verified.valid) {
        await _store.setLocalPremium(
          true,
          expiry: verified.expiry ?? DateTime.now().add(const Duration(days: 30)),
          source: 'restore:${purchase.platform}',
        );
      }
    }
    return current;
  }

  Future<void> clearPremium() => _store.setLocalPremium(false);

  /// Pulls the authoritative server entitlement from `accounts/{uid}` in
  /// Firestore and updates the local offline cache.
  Future<Entitlement> refreshFromServer(
    String uid, {
    Future<Entitlement?> Function(String uid)? fetcher,
  }) async {
    if (uid.isEmpty || (!isFirebaseInitialized && fetcher == null)) {
      return current;
    }
    final remote = await (fetcher ?? fetchServerEntitlement)(uid);
    if (remote == null) return current;
    await _store.setLocalPremium(
      remote.isPremium,
      expiry: remote.entitlementExpiry,
      source: 'firestore',
    );
    return current;
  }
}

final entitlementServiceProvider = Provider<EntitlementService>(
  (ref) => EntitlementService(
    ref.watch(offlineStoreProvider),
    verifier: isFirebaseInitialized ? verifyStoreReceiptCallable : null,
  ),
);
