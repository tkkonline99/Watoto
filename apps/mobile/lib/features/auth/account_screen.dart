import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'auth_widgets.dart';
import 'entitlements.dart';
import 'parent_gate_dialog.dart';

/// The family's own account (route `/account`), reached from the person button
/// in the home's top chrome.
///
/// Shows the grown-up what this device holds about them — how they sign in,
/// what they consented to, what plan they are on, where their child's progress
/// actually lives, and which children are here — then lets them act on it:
/// change the password or PIN, attach an email, upgrade, log out, or delete
/// everything.
///
/// Logging in is *not* here; that is [LoginScreen] at `/login`, which the
/// router has already made everyone pass. So this screen can assume an
/// authenticated grown-up and offer destructive controls safely.
///
/// Deliberately does **not** duplicate the Parent Zone: children editing,
/// screen time, accessibility, insights, export and legal all live there, and
/// two places to change one setting is worse than one.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final store = ref.watch(offlineStoreProvider);
    // Rebuild when a profile is added/renamed/removed so the list stays true.
    ref.watch(sessionProvider.select((s) => s.profilesRev));

    final email = store.accountEmail;
    final hasPassword = store.hasAccount && store.hasAccountPassword;
    final children = store.children;
    final consent = store.consent;
    final premium = ref.watch(isPremiumProvider);
    final freeMax = ref.watch(freeStageMaxProvider);
    // During a free-only launch every stage is already free, so there is
    // nothing to sell and the upgrade call-to-action would be a lie.
    final everythingFree = freeMax >= 10;
    final pending = store.pendingOps.length;

    return AuthCard(
      topRight: AuthCloseButton(onTap: () => context.go('/')),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No "signed in as <email>" subtitle: the email row below says the
          // same thing, and printing an address twice reads as a bug.
          AuthHeader(emoji: '👤', title: l10n.myAccount),

          _SectionLabel(l10n.personalInfo),
          AuthInfoRow(
            icon: Icons.mail_rounded,
            label: l10n.emailLabel,
            value: email ?? l10n.noEmailSaved,
          ),
          AuthInfoRow(
            icon: Icons.lock_rounded,
            label: l10n.signInMethod,
            value: hasPassword
                ? l10n.signInMethodPassword
                : l10n.signInMethodPin,
          ),
          if (consent.recordedAt != null)
            AuthInfoRow(
              icon: Icons.verified_user_rounded,
              label: l10n.consentRecorded,
              value: _formatDate(consent.recordedAt!.toLocal()),
            ),
          // A date alone tells a parent nothing about what they agreed to.
          AuthInfoRow(
            icon: Icons.tune_rounded,
            label: l10n.consentEnabled,
            value: _consentSummary(l10n, consent.aiFeatures,
                consent.voiceRecording),
          ),

          const SizedBox(height: 10),
          _SectionLabel(l10n.yourPlan),
          AuthInfoRow(
            icon: premium ? Icons.workspace_premium_rounded : Icons.star_rounded,
            label: l10n.yourPlan,
            value: premium
                ? l10n.planPremium
                : everythingFree
                    ? l10n.planFreeAll
                    : l10n.planFreeUpTo(freeMax),
          ),

          const SizedBox(height: 10),
          _SectionLabel(l10n.yourData),
          AuthInfoRow(
            icon: Icons.smartphone_rounded,
            label: l10n.whereItIsSaved,
            value: l10n.dataOnThisDevice,
          ),
          AuthInfoRow(
            icon: pending > 0 ? Icons.sync_rounded : Icons.cloud_done_rounded,
            label: l10n.syncStatus,
            value: pending > 0 ? l10n.syncPending(pending) : l10n.dataAllSaved,
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
                // The child's own animal, not a generic glyph.
                emoji: child.emoji,
                label: l10n.childProfileLabel,
                value: l10n.childNameAge(
                  child.nickname,
                  DateTime.now().year - child.birthYear,
                ),
              ),

          const Divider(height: 32),
          if (hasPassword)
            AuthActionRow(
              icon: Icons.password_rounded,
              label: l10n.changePassword,
              onTap: () => context.go('/account/password'),
            ),
          if (store.hasPin)
            AuthActionRow(
              icon: Icons.pin_rounded,
              label: l10n.changePin,
              onTap: () => context.go('/account/pin'),
            ),
          if (!store.hasAccount)
            AuthActionRow(
              icon: Icons.alternate_email_rounded,
              label: l10n.addEmail,
              subtitle: l10n.addEmailBody,
              onTap: () => context.go('/account/email'),
            ),

          const SizedBox(height: 20),
          // Gold is the app's "do the main thing" colour; pointing it at the
          // exit made logging out look like the point of the screen.
          if (!premium && !everythingFree) ...[
            AuthFilledButton(
              label: l10n.premiumTitle,
              onTap: () => context.go('/paywall'),
            ),
            const SizedBox(height: 12),
          ],
          AuthOutlineButton(
            label: l10n.logOut,
            color: WatotoColors.deep,
            onTap: () => _logOut(ref, context),
          ),
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
    if (!ref.read(sessionProvider).parentAccessAllowed &&
        !await showParentGateDialog(context, ref)) {
      return;
    }
    if (!context.mounted) return;
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

  /// What the family actually turned on, in their words — not a bare date.
  static String _consentSummary(AppLocalizations l10n, bool ai, bool voice) {
    final on = [
      if (ai) l10n.consentAi,
      if (voice) l10n.consentVoice,
    ];
    return on.isEmpty ? l10n.consentProgressOnly : on.join(' · ');
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
