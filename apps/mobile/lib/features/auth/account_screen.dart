import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../onboarding/savanna_background.dart';

/// Parent account: log in or create a local account. Families with an account
/// skip the PIN and reach the parent zone without re-entering anything. Reached
/// from the home (and usable any time). Local-only for now — a Firebase backend
/// drops in behind [SessionController]/[OfflineStore] later.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the email when logging back in to an existing account.
    _email.text = ref.read(offlineStoreProvider).accountEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final e = _email.text.trim();
    return e.contains('@') && e.contains('.') && e.length >= 5;
  }

  Future<void> _submit({required bool creating}) async {
    final l10n = AppLocalizations.of(context);
    if (!_emailValid) {
      setState(() => _error = l10n.invalidEmail);
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = l10n.passwordTooShort);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final session = ref.read(sessionProvider.notifier);
    if (creating) {
      await session.createAccount(_email.text, _password.text);
    } else {
      final ok = await session.signIn(_email.text, _password.text);
      if (!ok) {
        setState(() {
          _error = l10n.wrongPassword;
          _busy = false;
        });
        return;
      }
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loggedIn = ref.watch(sessionProvider.select((s) => s.loggedIn));
    final store = ref.watch(offlineStoreProvider);
    final hasAccount = store.hasAccount;

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
              child: loggedIn
                  ? _signedIn(context, l10n, store.accountEmail ?? '')
                  : _form(context, l10n, creating: !hasAccount),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signedIn(BuildContext context, AppLocalizations l10n, String email) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Avatar(emoji: '👋'),
        const SizedBox(height: 14),
        Text(l10n.parentAccount,
            style: const TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: WatotoColors.deep)),
        const SizedBox(height: 8),
        Text(l10n.signedInAs(email),
            textAlign: TextAlign.center,
            style: TextStyle(color: WatotoColors.deep.withValues(alpha: 0.7))),
        const SizedBox(height: 24),
        _OutlineButton(
          label: l10n.logOut,
          onTap: () async {
            await ref.read(sessionProvider.notifier).signOutAccount();
            if (context.mounted) setState(() {});
          },
        ),
      ],
    );
  }

  Widget _form(BuildContext context, AppLocalizations l10n,
      {required bool creating}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Avatar(emoji: '🔑'),
        const SizedBox(height: 14),
        Text(
          creating ? l10n.createAccount : l10n.logIn,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: WatotoColors.deep),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.createAccountSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: WatotoColors.deep.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          enabled: creating, // returning users log in with the stored email
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
          decoration:
              accountFieldDecoration(l10n.passwordLabel, l10n.passwordHint)
                  .copyWith(errorText: _error),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _busy ? null : _submit(creating: creating),
        ),
        const SizedBox(height: 20),
        _FilledButton(
          label: creating ? l10n.createAccount : l10n.logIn,
          onTap: _busy ? null : () => _submit(creating: creating),
        ),
      ],
    );
  }
}

/// Shared field styling for the account screen (rounded, cream-filled).
InputDecoration accountFieldDecoration(String label, String hint) =>
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
