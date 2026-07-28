import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../router/return_to.dart';
import '../onboarding/savanna_background.dart';

/// Parent session screen — every family gets a login/log-out option here,
/// whichever grown-up gate they chose:
///   * account families log in/out with email + password (persistent);
///   * PIN families log in/out with their PIN (unlocks/locks the grown-up
///     session for this run).
/// Reached from the home account button (and any time). Local-only for now — a
/// Firebase backend drops in behind [SessionController]/[OfflineStore] later.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showCreate = false; // PIN family upgrading to an account

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(offlineStoreProvider).accountEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final e = _email.text.trim();
    return e.contains('@') && e.contains('.') && e.length >= 5;
  }

  Future<void> _createOrLogin({required bool creating}) async {
    final l10n = AppLocalizations.of(context);
    if (!_emailValid) return setState(() => _error = l10n.invalidEmail);
    if (_password.text.length < 6) {
      return setState(() => _error = l10n.passwordTooShort);
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final session = ref.read(sessionProvider.notifier);
    if (creating) {
      await session.createAccount(_email.text, _password.text);
    } else if (!await session.signIn(_email.text, _password.text)) {
      return setState(() {
        _error = l10n.wrongPassword;
        _busy = false;
      });
    }
    // Session is now active -> the screen rebuilds into the signed-in view,
    // unless the family was sent here by a gate, in which case hand them back
    // to what they were opening.
    if (!mounted) return;
    setState(() => _busy = false);
    _resumeIfGated();
  }

  Future<void> _pinLogin() async {
    final l10n = AppLocalizations.of(context);
    final store = ref.read(offlineStoreProvider);
    final result = await store.tryPin(_pin.text);
    if (!mounted) return;
    if (result == 'locked') {
      final secs = store.pinLockRemaining?.inSeconds ?? 0;
      return setState(() => _error = 'Too many tries. Wait ${secs}s.');
    }
    if (result != 'ok') {
      return setState(() => _error = l10n.wrongPin);
    }
    ref.read(sessionProvider.notifier).unlockParent();
    setState(() {
      _error = null;
      _pin.clear();
    });
    _resumeIfGated();
  }

  /// The router sends signed-out families here with `?from=…` when they try to
  /// open something parent-gated. Once they are in, continue to it.
  void _resumeIfGated() {
    final back = returnTo(context);
    if (back != null) context.go(back);
  }

  void _logOut() {
    final session = ref.read(sessionProvider.notifier);
    final store = ref.read(offlineStoreProvider);
    if (store.hasAccount && ref.read(sessionProvider).loggedIn) {
      session.signOutAccount();
    } else {
      session.lockParent(); // PIN session
    }
    // Signing out returns to the welcome / "Choose your language" screen.
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(sessionProvider);
    final store = ref.watch(offlineStoreProvider);
    final hasAccount = store.hasAccount;
    final hasPin = store.hasPin;

    final Widget view;
    if (s.parentAccessAllowed) {
      view = _signedIn(l10n, hasAccount && s.loggedIn, store.accountEmail ?? '');
    } else if (_showCreate || (!hasAccount && !hasPin)) {
      view = _createForm(l10n, canCancel: hasPin);
    } else if (hasAccount) {
      view = _accountLogin(l10n);
    } else {
      view = _pinLoginForm(l10n);
    }

    return SavannaScaffold(
      topRight: _CloseButton(onTap: () => context.go('/')),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
              child: view,
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String emoji, String title, [String? subtitle]) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(emoji: emoji),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: WatotoColors.deep.withValues(alpha: 0.6))),
          ],
          const SizedBox(height: 20),
        ],
      );

  Widget _signedIn(AppLocalizations l10n, bool viaAccount, String email) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('👋', l10n.parentAccount,
            viaAccount ? l10n.signedInAs(email) : l10n.loggedInPin),
        _OutlineButton(label: l10n.logOut, onTap: _logOut),
      ],
    );
  }

  Widget _accountLogin(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('🔑', l10n.parentAccount),
        TextField(
          controller: _email,
          enabled: false, // log back in to the stored account
          decoration: accountFieldDecoration(l10n.emailLabel, l10n.emailHint),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: accountFieldDecoration(l10n.passwordLabel, l10n.passwordHint)
              .copyWith(errorText: _error),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _busy ? null : _createOrLogin(creating: false),
        ),
        const SizedBox(height: 20),
        _FilledButton(
          label: l10n.logIn,
          onTap: _busy ? null : () => _createOrLogin(creating: false),
        ),
      ],
    );
  }

  Widget _pinLoginForm(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('🔢', l10n.parentAccount, l10n.enterPinSubtitle),
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, letterSpacing: 4),
          decoration: accountFieldDecoration(l10n.parentPin, null)
              .copyWith(errorText: _error),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _pinLogin(),
        ),
        const SizedBox(height: 16),
        _FilledButton(
          label: l10n.logIn,
          onTap: _pin.text.isEmpty ? null : _pinLogin,
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _showCreate = true;
              _error = null;
            }),
            child: Text(l10n.createAccountInstead),
          ),
        ),
      ],
    );
  }

  Widget _createForm(AppLocalizations l10n, {required bool canCancel}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('🔑', l10n.createAccount, l10n.createAccountSubtitle),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: accountFieldDecoration(l10n.emailLabel, l10n.emailHint),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: accountFieldDecoration(l10n.passwordLabel, l10n.passwordHint)
              .copyWith(errorText: _error),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _busy ? null : _createOrLogin(creating: true),
        ),
        const SizedBox(height: 20),
        _FilledButton(
          label: l10n.createAccount,
          onTap: _busy ? null : () => _createOrLogin(creating: true),
        ),
        if (canCancel) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _showCreate = false;
                _error = null;
              }),
              child: Text(l10n.usePinInstead),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared field styling for the account screen (rounded, cream-filled).
InputDecoration accountFieldDecoration(String label, String? hint) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFBF6EA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE7DEC9), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: WatotoColors.sun, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE7DEC9), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: WatotoColors.berry, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: WatotoColors.berry, width: 2),
      ),
    );

class _Avatar extends StatelessWidget {
  const _Avatar({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 74,
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: WatotoColors.sun.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 34)),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [WatotoColors.sun, WatotoColors.mango])
              : null,
          color: enabled ? null : const Color(0xFFE7DDC9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: enabled ? WatotoColors.deep : const Color(0xFFB3A488),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: WatotoColors.berry, width: 1.5),
        foregroundColor: WatotoColors.berry,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(
            fontFamily: 'Baloo2', fontSize: 18, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.close_rounded, color: WatotoColors.deep),
        ),
      ),
    );
  }
}
