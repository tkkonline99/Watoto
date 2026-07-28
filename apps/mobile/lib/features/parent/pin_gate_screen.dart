import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../router/return_to.dart';

/// PIN gate protecting the parent zone (docs/16 §16.1). Kids can't reach
/// settings, consent, or profile management without the parent PIN.
class PinGateScreen extends ConsumerStatefulWidget {
  const PinGateScreen({super.key});

  @override
  ConsumerState<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends ConsumerState<PinGateScreen> {
  final _pin = TextEditingController();
  bool _error = false;
  bool _locked = false;
  String? _lockMessage;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = ref.read(offlineStoreProvider);
    // Drop expired lockout before attempting.
    if (_locked && !store.isPinLocked) {
      setState(() {
        _locked = false;
        _lockMessage = null;
      });
    }
    final result = await store.tryPin(_pin.text);
    if (!mounted) return;
    if (result == 'ok') {
      ref.read(sessionProvider.notifier).unlockParent();
      // Back to whatever the family was opening (a locked lesson, the
      // paywall); the dashboard is only the destination when the parent came
      // for the dashboard.
      context.go(returnTo(context) ?? '/parent');
      return;
    }
    if (result == 'locked') {
      final left = store.pinLockRemaining;
      final secs = left?.inSeconds ?? 0;
      setState(() {
        _locked = true;
        _error = false;
        _lockMessage = l10nPinLocked(secs);
      });
      _pin.clear();
      return;
    }
    setState(() {
      _error = true;
      _locked = false;
      _lockMessage = null;
    });
    _pin.clear();
  }

  String l10nPinLocked(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return 'Too many tries. Wait ${m}m ${s}s.';
    }
    return 'Too many tries. Wait ${s}s.';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        // Scroll-safe: keyboard + large text sizes must not overflow.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔐', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  l10n.enterPinTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.enterPinSubtitle, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (_lockMessage != null) ...[
                  Text(
                    _lockMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: WatotoColors.berry,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  enabled: !_locked ||
                      !(ref.read(offlineStoreProvider).isPinLocked),
                  // obscureText + number keyboard drops keystrokes on many
                  // Android IMEs unless suggestions/autocorrect are off
                  // (flutter#67391).
                  enableSuggestions: false,
                  autocorrect: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: _error ? l10n.wrongPin : null,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (ref.read(offlineStoreProvider).isPinLocked)
                      ? null
                      : _submit,
                  child: Text(l10n.unlock),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
