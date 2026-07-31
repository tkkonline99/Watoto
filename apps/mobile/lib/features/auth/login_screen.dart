import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../router/return_to.dart';
import 'auth_widgets.dart';

/// The way back into the app (route `/login`).
///
/// Watoto keeps **no session across launches**: the family's email is
/// remembered so they never retype it, but the password (or PIN) is asked for
/// every single run. "Let's go" on the welcome screen lands here, and the
/// router sends any other location here until this screen has been passed.
///
/// Deliberately a *pure gate* — it can log a family in and hand them off to
/// recovery, and nothing else. Creating or replacing an account now lives on
/// [AccountScreen], behind a grown-up who has already proved who they are;
/// offering it here let anyone holding the device overwrite the family's
/// credentials without knowing the old ones.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _password = TextEditingController();
  final _pin = TextEditingController();
  /// Display-only: holds the remembered email for the disabled field.
  late final TextEditingController _email;
  String? _error;
  bool _busy = false;

  /// PIN families with an email on file can still be shown the PIN form; this
  /// flips an account family over to their PIN when they have both.
  bool _usePin = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: ref.read(offlineStoreProvider).accountEmail ?? '',
    );
  }

  @override
  void dispose() {
    _password.dispose();
    _pin.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Where to go once the family is in: whatever they were opening, or home.
  void _enter() {
    final back = returnTo(context);
    context.go(back ?? '/');
  }

  Future<void> _passwordLogin() async {
    final l10n = AppLocalizations.of(context);
    final email = ref.read(offlineStoreProvider).accountEmail ?? '';
    setState(() {
      _error = null;
      _busy = true;
    });
    final ok = await ref.read(sessionProvider.notifier).signIn(
          email,
          _password.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return setState(() => _error = l10n.wrongPassword);
    _enter();
  }

  Future<void> _pinLogin() async {
    final l10n = AppLocalizations.of(context);
    final store = ref.read(offlineStoreProvider);
    final result = await store.tryPin(_pin.text);
    if (!mounted) return;
    if (result == 'locked') {
      final secs = store.pinLockRemaining?.inSeconds ?? 0;
      return setState(() => _error = l10n.pinLockedFor(secs));
    }
    if (result != 'ok') return setState(() => _error = l10n.wrongPin);
    ref.read(sessionProvider.notifier).unlockParent();
    _pin.clear();
    _enter();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = ref.watch(offlineStoreProvider);
    // An account is only usable if its password hash survived onto this device
    // — a restored backup carries the email but never the credentials.
    final canUsePassword = store.hasAccount && store.hasAccountPassword;

    final Widget view;
    if (canUsePassword && !(_usePin && store.hasPin)) {
      view = _passwordForm(l10n, offerPin: store.hasPin);
    } else if (store.hasPin) {
      view = _pinForm(l10n, offerPassword: canUsePassword);
    } else {
      view = _noCredentials(l10n);
    }

    return AuthCard(child: view);
  }

  Widget _passwordForm(AppLocalizations l10n, {required bool offerPin}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader(
          emoji: '👋',
          title: l10n.welcomeBack,
          subtitle: l10n.loginSubtitle,
        ),
        // Read-only on purpose: the remembered email *is* the account on this
        // device, and an editable field only invites typos that read as a
        // wrong password.
        TextField(
          controller: _email,
          enabled: false,
          decoration: accountFieldDecoration(l10n.emailLabel, l10n.emailHint),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: true,
          autofocus: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration:
              accountFieldDecoration(l10n.passwordLabel, l10n.passwordHint)
                  .copyWith(errorText: _error),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _busy ? null : _passwordLogin(),
        ),
        const SizedBox(height: 20),
        AuthFilledButton(
          label: l10n.logIn,
          onTap: _busy || _password.text.isEmpty ? null : _passwordLogin,
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => context.push('/password-reset'),
            child: Text(l10n.forgotPasswordTitle),
          ),
        ),
        if (offerPin)
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _usePin = true;
                _error = null;
              }),
              child: Text(l10n.usePinToLogIn),
            ),
          ),
      ],
    );
  }

  Widget _pinForm(AppLocalizations l10n, {required bool offerPassword}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader(
          emoji: '🔢',
          title: l10n.welcomeBack,
          subtitle: l10n.enterPinSubtitle,
        ),
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, letterSpacing: 4),
          decoration: accountFieldDecoration(l10n.parentPin, null)
              .copyWith(errorText: _error),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _pinLogin(),
        ),
        const SizedBox(height: 16),
        AuthFilledButton(
          label: l10n.logIn,
          onTap: _pin.text.isEmpty ? null : _pinLogin,
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => context.push('/pin-reset'),
            child: Text(l10n.forgotPinTitle),
          ),
        ),
        if (offerPassword)
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _usePin = false;
                _error = null;
              }),
              child: Text(l10n.usePasswordToLogIn),
            ),
          ),
      ],
    );
  }

  /// A device that has profiles but no credentials — the shape a restored
  /// backup lands in, since backups deliberately leave the PIN and password
  /// hashes behind. Recovery sets a fresh PIN behind the grown-up gate.
  Widget _noCredentials(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader(
          emoji: '🔑',
          title: l10n.welcomeBack,
          subtitle: l10n.noCredentialsSubtitle,
        ),
        AuthFilledButton(
          label: l10n.setPinTitle,
          onTap: () => context.push('/pin-reset'),
        ),
      ],
    );
  }
}
