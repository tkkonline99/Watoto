import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../router/return_to.dart';

/// The grown-up gate in front of the Parent Zone, the paywall and the account
/// screen (route `/parent/unlock`, docs/16 §16.1).
///
/// Asks for whichever secret the family holds — the PIN if they set one,
/// otherwise the account password. It used to be PIN-only, which left account
/// families with no gate at all: they were let through on the strength of
/// being signed in, and a signed-in session belongs to the child for the rest
/// of the afternoon.
///
/// Passing it sets `parentUnlocked` for the run; backgrounding the app clears
/// it again.
class ParentZoneGateScreen extends ConsumerStatefulWidget {
  const ParentZoneGateScreen({super.key});

  @override
  ConsumerState<ParentZoneGateScreen> createState() =>
      _ParentZoneGateScreenState();
}

class _ParentZoneGateScreenState extends ConsumerState<ParentZoneGateScreen> {
  final _secret = TextEditingController();
  bool _error = false;
  bool _locked = false;
  String? _lockMessage;

  /// PIN wins when the family has both: it is the secret they chose
  /// specifically to keep this door shut.
  bool get _usePin => ref.read(offlineStoreProvider).hasPin;

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  void _passed() {
    ref.read(sessionProvider.notifier).unlockParent();
    // Back to whatever the family was opening (a locked lesson, the paywall);
    // the dashboard is only the destination when they came for the dashboard.
    context.go(returnTo(context) ?? '/parent');
  }

  Future<void> _submit() async {
    final store = ref.read(offlineStoreProvider);
    if (!_usePin) {
      // No lockout counter on the password path: the PIN's exists because a
      // 4-digit secret is brute-forceable in a way a password is not.
      if (store.verifyAccount(_secret.text)) return _passed();
      setState(() => _error = true);
      _secret.clear();
      return;
    }

    // Drop expired lockout before attempting.
    if (_locked && !store.isPinLocked) {
      setState(() {
        _locked = false;
        _lockMessage = null;
      });
    }
    final result = await store.tryPin(_secret.text);
    if (!mounted) return;
    if (result == 'ok') return _passed();
    if (result == 'locked') {
      final secs = store.pinLockRemaining?.inSeconds ?? 0;
      setState(() {
        _locked = true;
        _error = false;
        _lockMessage = _lockedFor(secs);
      });
      _secret.clear();
      return;
    }
    setState(() {
      _error = true;
      _locked = false;
      _lockMessage = null;
    });
    _secret.clear();
  }

  String _lockedFor(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return 'Too many tries. Wait ${m}m ${s}s.';
    return 'Too many tries. Wait ${s}s.';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = ref.watch(offlineStoreProvider);
    final usePin = store.hasPin;
    final pinLocked = store.isPinLocked;

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
                Text(
                  usePin ? l10n.enterPinSubtitle : l10n.enterPasswordSubtitle,
                  textAlign: TextAlign.center,
                ),
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
                  controller: _secret,
                  keyboardType: usePin ? TextInputType.number : null,
                  obscureText: true,
                  enabled: !usePin || !pinLocked,
                  // obscureText + number keyboard drops keystrokes on many
                  // Android IMEs unless suggestions/autocorrect are off
                  // (flutter#67391).
                  enableSuggestions: false,
                  autocorrect: false,
                  inputFormatters:
                      usePin ? [FilteringTextInputFormatter.digitsOnly] : null,
                  maxLength: usePin ? 6 : null,
                  textAlign: usePin ? TextAlign.center : TextAlign.start,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: _error
                        ? (usePin ? l10n.wrongPin : l10n.wrongPassword)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: usePin && pinLocked ? null : _submit,
                  child: Text(l10n.unlock),
                ),
                const SizedBox(height: 4),
                // Stays enabled while the PIN is locked out: a lockout is
                // exactly when a grown-up needs the way back in.
                TextButton(
                  onPressed: () =>
                      context.push(usePin ? '/pin-reset' : '/password-reset'),
                  child: Text(
                    usePin ? l10n.forgotPinTitle : l10n.forgotPasswordTitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
