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

/// Forgot-password flow: get a reset code, then set a new password.
///
/// Two very different situations wear the same screen, and conflating them was
/// the bug. With a cloud account the code really is emailed. With the local
/// account — which is every shipped build, since no `firebase_*` package is in
/// pubspec — there is no mail server and no `url_launcher`: the `mailto:` URI
/// [LocalAuthService.requestLocalPasswordReset] builds is discarded, nothing
/// is sent, and the code used to go silently to the clipboard while the screen
/// said "Check your email for the reset code." A parent who had genuinely
/// forgotten their password waited for mail that could never arrive.
///
/// So the local branch now says what it is: your account is on this device,
/// here is your code, on screen. That is not a weakening — the code was always
/// reachable by whoever held the phone, via the clipboard.
///
/// The barrier that does the work is knowing the account email, which is why
/// this screen no longer pre-fills it. It used to, which meant a child could
/// open the one screen that sits outside the login gate, pass a spelled-digit
/// parent gate designed to stop a *young* child, read the code off the screen,
/// and own the Parent Zone — screen-time limits, data export, erase-all. The
/// app's audience runs to ten years old.
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

  // Deliberately no initState pre-fill. The account email was pre-filled here
  // "so the family doesn't retype it", which also handed it to anyone who
  // picked up the phone. A parent knows their own address; a child usually
  // does not, and on a device-local account it is the only secret standing
  // between them and the Parent Zone.

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
        final code = result.localResetCode;
        // Show the code first. It is the thing the parent came for, and the
        // clipboard is a convenience on top — a platform that refuses the
        // write (or has no clipboard at all) must not cost them their code,
        // which is exactly what happened while this ran the other way round.
        setState(() {
          _localCode = code;
          _sent = true;
          _info = null; // the code block below carries the message now
        });
        if (code != null) {
          try {
            await Clipboard.setData(ClipboardData(text: code));
          } catch (_) {
            // Nothing to tell the family: the code is already on screen.
          }
        }
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
    // Which of the two flows this really is. Every shipped build is local;
    // the cloud branch is here for when Firebase is switched on.
    final isLocal = ref.read(authServiceProvider) is LocalAuthService;
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
                    switch ((isLocal, _sent)) {
                      (true, false) => l10n.passwordResetLocalBody,
                      (true, true) => l10n.passwordResetLocalEnterCodeBody,
                      (false, false) => l10n.forgotPasswordBody,
                      (false, true) => l10n.forgotPasswordEnterCodeBody,
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: WatotoColors.deep.withValues(alpha: 0.65),
                    ),
                  ),
                  // A family with a PIN never needed this screen: the PIN is a
                  // way in on its own. Say so before they reset anything.
                  if (!_sent && ref.read(offlineStoreProvider).hasPin) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(l10n.passwordResetKnowPin),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // The code itself, on screen, where the copy now says it is.
                  if (isLocal && _sent && _localCode != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: WatotoColors.sky.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            l10n.passwordResetLocalCode(_localCode!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: WatotoColors.deep,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.passwordResetLocalCopied} '
                            '${l10n.passwordResetLocalWhy}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: WatotoColors.deep.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                      child: Text(isLocal ? l10n.sendResetEmailLocal : l10n.sendResetEmail),
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
                        isLocal
                            ? l10n.passwordResetCodeHintLocal
                            : l10n.passwordResetCodeHint,
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
                      child: Text(isLocal ? l10n.resendResetEmailLocal : l10n.resendResetEmail),
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
