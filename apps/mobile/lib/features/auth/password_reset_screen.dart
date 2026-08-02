import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/l10n/store_error_text.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../onboarding/savanna_background.dart';
import 'auth_widgets.dart' show accountFieldDecoration;
import 'auth_service.dart';
import 'parent_gate_dialog.dart';

/// Forgot-password flow: email a reset code/link, then set a new password.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _sent = false;
  bool _busy = false;
  String? _error;
  String? _info;
  String? _localCode; // offline handoff for device-owner recovery

  @override
  void initState() {
    super.initState();
    final stored = ref.read(offlineStoreProvider).accountEmail;
    if (stored != null) _email.text = stored;
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!email.contains('@') || email.length < 5) {
      setState(() => _error = l10n.invalidEmail);
      return;
    }
    if (!await showParentGateDialog(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      if (auth is LocalAuthService) {
        auth.bindStore(ref.read(offlineStoreProvider));
        final result = await auth.requestLocalPasswordReset(email);
        _localCode = result.localResetCode;
        // Copy mailto body to clipboard so the parent can paste into mail.
        if (result.mailtoUri != null) {
          await Clipboard.setData(
            ClipboardData(
              text: 'Watoto reset code: ${result.localResetCode}\n\n'
                  'Send this to yourself at ${result.email} or enter the code in the app.',
            ),
          );
        }
        setState(() {
          _sent = true;
          _info = l10n.passwordResetEmailSent;
          if (kDebugMode && _localCode != null) {
            _info = '${l10n.passwordResetEmailSent}\n'
                '${l10n.passwordResetDevCode(_localCode!)}';
          }
        });
      } else {
        await auth.sendPasswordResetEmail(email);
        setState(() {
          _sent = true;
          _info = l10n.passwordResetEmailSent;
        });
      }
      // The email address is stripped by the service's PII filter; only the
      // fact that recovery was attempted is useful anyway.
      ref.read(analyticsProvider).log(AnalyticsEvents.passwordResetRequest);
    } catch (e) {
      // Generic copy — avoid account enumeration in UI for cloud; local may fail.
      setState(() {
        _error = storeErrorText(l10n, e, fallback: l10n.passwordResetFailed);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    final l10n = AppLocalizations.of(context);
    if (_password.text.length < 6) {
      setState(() => _error = l10n.passwordTooShort);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = l10n.passwordMismatch);
      return;
    }
    if (_code.text.trim().length < 4) {
      setState(() => _error = l10n.passwordResetCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      if (auth is LocalAuthService) {
        auth.bindStore(ref.read(offlineStoreProvider));
      }
      await auth.confirmPasswordReset(
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordResetSuccess)),
      );
      context.go('/account');
    } catch (e) {
      setState(() {
        _error = storeErrorText(l10n, e, fallback: l10n.passwordResetFailed);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SavannaScaffold(
      topRight: IconButton(
        icon: const Icon(Icons.close, color: WatotoColors.deep),
        onPressed: () => context.go('/account'),
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
                  const Text('✉️',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    l10n.forgotPasswordTitle,
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
                    _sent
                        ? l10n.forgotPasswordEnterCodeBody
                        : l10n.forgotPasswordBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: WatotoColors.deep.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_info != null) ...[
                    Text(
                      _info!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: WatotoColors.leaf,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                  TextField(
                    controller: _email,
                    enabled: !_sent,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        accountFieldDecoration(l10n.emailLabel, l10n.emailHint),
                  ),
                  if (!_sent) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _send,
                      child: Text(l10n.sendResetEmail),
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: accountFieldDecoration(
                        l10n.passwordResetCodeLabel,
                        l10n.passwordResetCodeHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: accountFieldDecoration(
                        l10n.newPasswordLabel,
                        l10n.passwordHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: true,
                      decoration: accountFieldDecoration(
                        l10n.confirmPasswordLabel,
                        l10n.passwordHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _confirmReset,
                      child: Text(l10n.setNewPassword),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _send,
                      child: Text(l10n.resendResetEmail),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
