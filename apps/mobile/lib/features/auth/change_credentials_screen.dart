import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../l10n/gen/app_localizations.dart';
import 'auth_widgets.dart';

/// Deliberate credential changes, reached from the account screen by a
/// grown-up who has already passed `/login`.
///
/// Separate from the two recovery screens on purpose: those answer "I have
/// forgotten this" and charge a parent gate or an emailed code for it. These
/// answer "I know it and want a different one", which only needs the current
/// secret. Before this existed the only way to change a password was to claim
/// you had forgotten it.

/// `/account/password` — current password → new password.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_next.text.length < 6) {
      return setState(() => _error = l10n.passwordTooShort);
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final ok = await ref.read(offlineStoreProvider).changeAccountPassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return setState(() => _error = l10n.wrongCurrentPassword);
    _done(context, l10n.passwordChanged);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthCard(
      topRight: AuthCloseButton(onTap: () => context.go('/account')),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(emoji: '🔑', title: l10n.changePassword),
          TextField(
            controller: _current,
            obscureText: true,
            autofocus: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration:
                accountFieldDecoration(l10n.currentPasswordLabel, null),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _next,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: accountFieldDecoration(
                    l10n.newPasswordLabel, l10n.passwordHint)
                .copyWith(errorText: _error),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: 20),
          AuthFilledButton(
            label: l10n.save,
            onTap: _busy || _current.text.isEmpty || _next.text.isEmpty
                ? null
                : _submit,
          ),
        ],
      ),
    );
  }
}

/// `/account/pin` — current PIN → new PIN (confirmed).
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_next.text.length < 4) {
      return setState(() => _error = l10n.pinTooShort);
    }
    if (_next.text != _confirm.text) {
      return setState(() => _error = l10n.pinMismatch);
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final ok = await ref.read(offlineStoreProvider).changePin(
          currentPin: _current.text,
          newPin: _next.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return setState(() => _error = l10n.wrongCurrentPin);
    _done(context, l10n.pinChanged);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthCard(
      topRight: AuthCloseButton(onTap: () => context.go('/account')),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(emoji: '🔢', title: l10n.changePin),
          _pinField(_current, l10n.currentPinLabel, autofocus: true),
          const SizedBox(height: 14),
          _pinField(_next, l10n.newPinLabel),
          const SizedBox(height: 14),
          _pinField(_confirm, l10n.confirmPinLabel, error: _error),
          const SizedBox(height: 20),
          AuthFilledButton(
            label: l10n.save,
            onTap: _busy ||
                    _current.text.isEmpty ||
                    _next.text.isEmpty ||
                    _confirm.text.isEmpty
                ? null
                : _submit,
          ),
        ],
      ),
    );
  }

  Widget _pinField(
    TextEditingController controller,
    String label, {
    bool autofocus = false,
    String? error,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      autofocus: autofocus,
      enableSuggestions: false,
      autocorrect: false,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, letterSpacing: 4),
      decoration:
          accountFieldDecoration(label, null).copyWith(errorText: error),
      onChanged: (_) => setState(() => _error = null),
    );
  }
}

/// `/account/email` — a PIN family attaches an email and password.
///
/// The point is recovery: a PIN family has nothing on file, so forgetting the
/// PIN leaves only the parent gate between them and their child's history.
/// It is also what a cloud account will later be keyed on.
class AddEmailScreen extends ConsumerStatefulWidget {
  const AddEmailScreen({super.key});

  @override
  ConsumerState<AddEmailScreen> createState() => _AddEmailScreenState();
}

class _AddEmailScreenState extends ConsumerState<AddEmailScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!(email.contains('@') && email.contains('.') && email.length >= 5)) {
      return setState(() => _error = l10n.invalidEmail);
    }
    if (_password.text.length < 6) {
      return setState(() => _error = l10n.passwordTooShort);
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    // The family keeps their PIN: createAccount only adds the email side, and
    // the login screen lets them use whichever they remember.
    await ref.read(sessionProvider.notifier).createAccount(email, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    _done(context, l10n.emailSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthCard(
      topRight: AuthCloseButton(onTap: () => context.go('/account')),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            emoji: '✉️',
            title: l10n.addEmail,
            subtitle: l10n.addEmailBody,
          ),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            autocorrect: false,
            decoration: accountFieldDecoration(l10n.emailLabel, l10n.emailHint),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration:
                accountFieldDecoration(l10n.passwordLabel, l10n.passwordHint)
                    .copyWith(errorText: _error),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: 20),
          AuthFilledButton(
            label: l10n.save,
            onTap: _busy || _email.text.isEmpty || _password.text.isEmpty
                ? null
                : _submit,
          ),
        ],
      ),
    );
  }
}

/// Confirm the change where the grown-up is looking, then hand them back.
void _done(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  context.go('/account');
}
