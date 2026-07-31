import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'auth_widgets.dart';

/// The family's own account (route `/account`), reached from the person button
/// in the home's top chrome.
///
/// Shows the grown-up what this device holds about them — how they sign in,
/// which children are on the device, and what they consented to — and gives
/// them the two actions that dispose of it: **log out** and **delete account**.
///
/// Logging in is *not* here; that is [LoginScreen] at `/login`, which the
/// router has already made everyone pass. So this screen can assume an
/// authenticated grown-up and offer destructive controls safely.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final store = ref.watch(offlineStoreProvider);
    // Rebuild when a profile is added/renamed/removed so the list stays true.
    ref.watch(sessionProvider.select((s) => s.profilesRev));

    final email = store.accountEmail;
    final children = store.children;
    final consent = store.consent;

    return AuthCard(
      topRight: AuthCloseButton(onTap: () => context.go('/')),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            emoji: '👤',
            title: l10n.myAccount,
            subtitle: email == null ? null : l10n.signedInAs(email),
          ),
          _SectionLabel(l10n.personalInfo),
          AuthInfoRow(
            icon: Icons.mail_rounded,
            label: l10n.emailLabel,
            value: email ?? l10n.noEmailSaved,
          ),
          AuthInfoRow(
            icon: Icons.lock_rounded,
            label: l10n.signInMethod,
            value: store.hasAccount && store.hasAccountPassword
                ? l10n.signInMethodPassword
                : l10n.signInMethodPin,
          ),
          if (consent.recordedAt != null)
            AuthInfoRow(
              icon: Icons.verified_user_rounded,
              label: l10n.consentRecorded,
              value: _formatDate(consent.recordedAt!.toLocal()),
            ),
          const SizedBox(height: 10),
          _SectionLabel(l10n.children),
          if (children.isEmpty)
            AuthInfoRow(
              icon: Icons.child_care_rounded,
              label: l10n.children,
              value: l10n.noChildrenYet,
            )
          else
            for (final child in children)
              AuthInfoRow(
                icon: Icons.child_care_rounded,
                label: child.emoji,
                value: l10n.childNameAge(
                  child.nickname,
                  DateTime.now().year - child.birthYear,
                ),
              ),
          const SizedBox(height: 24),
          AuthFilledButton(label: l10n.logOut, onTap: () => _logOut(ref, context)),
          const SizedBox(height: 12),
          AuthOutlineButton(
            label: l10n.deleteAccount,
            icon: Icons.delete_forever_rounded,
            onTap: () => _confirmDelete(context, ref),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.deleteAccountBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: WatotoColors.deep.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  /// Ends the run's session (account *and* PIN) and returns to the welcome
  /// screen — from there "Let's go" asks for the password again.
  void _logOut(WidgetRef ref, BuildContext context) {
    ref.read(sessionProvider.notifier).logOut();
    context.go('/welcome');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Text(l10n.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: WatotoColors.berry),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(sessionProvider.notifier).deleteAccount();
    // Everything is gone, including the onboarding flag, so the app is back at
    // first run; the router would redirect anyway, this just skips the bounce.
    if (context.mounted) context.go('/onboarding');
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: WatotoColors.deep.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
