import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../onboarding/savanna_background.dart';
import 'account_screen.dart' show accountFieldDecoration;
import 'parent_gate_dialog.dart';

/// Forgot-PIN flow for parent zone recovery.
///
/// - Account families: parent gate + password → new PIN
/// - PIN-only families: parent gate (FTC adult check) → new PIN
class PinResetScreen extends ConsumerStatefulWidget {
  const PinResetScreen({super.key});

  @override
  ConsumerState<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends ConsumerState<PinResetScreen> {
  final _password = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final store = ref.read(offlineStoreProvider);
    final pin = _pin.text.trim();
    final confirm = _confirm.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      setState(() => _error = l10n.pinLengthHint);
      return;
    }
    if (pin != confirm) {
      setState(() => _error = l10n.pinMismatch);
      return;
    }
    if (!await showParentGateDialog(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (store.hasAccount) {
        await store.resetPinWithPassword(
          password: _password.text,
          newPin: pin,
        );
      } else {
        // PIN-only: physical device + adult gate is the recovery path.
        await store.resetPin(pin);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pinResetSuccess)),
      );
      context.go('/parent/pin');
    } catch (e) {
      setState(() {
        _error = e is StateError
            ? (e.message.contains('Wrong password')
                ? l10n.wrongPassword
                : e.message)
            : l10n.pinResetFailed;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasAccount = ref.watch(offlineStoreProvider).hasAccount;

    return SavannaScaffold(
      topRight: IconButton(
        icon: const Icon(Icons.close, color: WatotoColors.deep),
        onPressed: () => context.go('/parent/pin'),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: WatotoColors.deep.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔐',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    l10n.forgotPinTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasAccount
                        ? l10n.forgotPinBodyAccount
                        : l10n.forgotPinBodyPinOnly,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: WatotoColors.deep.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: WatotoColors.berry,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (hasAccount) ...[
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: accountFieldDecoration(
                        l10n.passwordLabel,
                        l10n.passwordHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: accountFieldDecoration(l10n.newPinLabel, null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration:
                        accountFieldDecoration(l10n.confirmPinLabel, null),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(l10n.setNewPin),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
