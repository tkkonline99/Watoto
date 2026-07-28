import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../router/return_to.dart';
import 'entitlements.dart';

/// Parent-only paywall. Never shown to children mid-activity.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _buy(String productId) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    ref.read(analyticsProvider).log(
          AnalyticsEvents.purchaseAttempt,
          {'product': productId},
        );
    try {
      await ref.read(entitlementServiceProvider).subscribe(productId);
      ref.read(sessionProvider.notifier).touchSession();
      ref.read(analyticsProvider).log(
            AnalyticsEvents.purchaseSuccess,
            {'product': productId},
          );
      if (!mounted) return;
      setState(() => _message = 'ok');
      _leave();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hand back to the activity the family came from, if any; otherwise behave
  /// like the old dialog and pop to whoever pushed the paywall.
  void _leave() {
    final back = returnTo(context);
    if (back != null) {
      context.go(back);
    } else {
      context.pop(true);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final e = await ref.read(entitlementServiceProvider).restore();
      ref.read(sessionProvider.notifier).touchSession();
      if (!mounted) return;
      if (e.isPremium) {
        _leave();
      } else {
        setState(() => _message = 'none');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final premium = ref.watch(isPremiumProvider);
    final sandbox = ref.watch(entitlementServiceProvider).isSandbox;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.premiumTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(false),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('🌟', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              l10n.premiumTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: WatotoColors.deep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.premiumBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            _Bullet(l10n.premiumBullet1),
            _Bullet(l10n.premiumBullet2),
            _Bullet(l10n.premiumBullet3),
            const SizedBox(height: 12),
            Text(
              freePremiumMapSummary(isPremium: premium),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (sandbox) ...[
              const SizedBox(height: 8),
              Text(
                l10n.premiumSandboxNote,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Store billing is not configured in this build. '
                'Use a debug build or ALLOW_SANDBOX_IAP for testing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
            const SizedBox(height: 24),
            if (premium)
              Card(
                color: WatotoColors.leaf.withValues(alpha: 0.15),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: WatotoColors.leaf),
                  title: Text(l10n.premiumActive),
                ),
              )
            else ...[
              FilledButton(
                onPressed: _busy ? null : () => _buy(premiumMonthlyId),
                child: Text(l10n.premiumMonthly),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : () => _buy(premiumAnnualId),
                child: Text(l10n.premiumAnnual),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy ? null : _restore,
                child: Text(l10n.restorePurchases),
              ),
            ],
            if (_message != null && _message != 'ok') ...[
              const SizedBox(height: 12),
              Text(
                _message == 'none' ? l10n.restoreNone : _message!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✓  ', style: TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.leaf)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
