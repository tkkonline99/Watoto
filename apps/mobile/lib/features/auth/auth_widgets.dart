import 'package:flutter/material.dart';

import '../../core/theme/watoto_theme.dart';
import '../onboarding/savanna_background.dart';

/// The pieces every grown-up auth surface is built from — the login gate, the
/// account screen, and both recovery screens. They were private to
/// `account_screen.dart` while it was the only such surface; the login gate
/// split them out so the two screens cannot drift apart visually.

/// Shared field styling for the auth screens (rounded, cream-filled).
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

/// A white card floating on the savanna — the frame shared by the login gate
/// and the account screen.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.topRight});

  final Widget child;
  final Widget? topRight;

  @override
  Widget build(BuildContext context) {
    return SavannaScaffold(
      topRight: topRight,
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
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Emoji badge + title + optional subtitle at the top of an auth card.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
  });

  final String emoji;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthAvatar(emoji: emoji),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: WatotoColors.deep,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: WatotoColors.deep.withValues(alpha: 0.6),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class AuthAvatar extends StatelessWidget {
  const AuthAvatar({super.key, required this.emoji});
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

class AuthFilledButton extends StatelessWidget {
  const AuthFilledButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // A bare GestureDetector has no role: this reads as plain text, and its
    // disabled state was invisible to assistive tech.
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(child: _button(enabled)),
    );
  }

  Widget _button(bool enabled) {
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

class AuthOutlineButton extends StatelessWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = WatotoColors.berry,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      side: BorderSide(color: color, width: 1.5),
      foregroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      textStyle: const TextStyle(
          fontFamily: 'Baloo2', fontSize: 18, fontWeight: FontWeight.w800),
    );
    if (icon == null) {
      return OutlinedButton(onPressed: onTap, style: style, child: Text(label));
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      style: style,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

/// One "label / value" line of the family's own information.
///
/// Carries either an [icon] or an [emoji] in its badge — children show their
/// own animal, everything else shows a glyph.
class AuthInfoRow extends StatelessWidget {
  const AuthInfoRow({
    super.key,
    this.icon,
    this.emoji,
    required this.label,
    required this.value,
  }) : assert(icon != null || emoji != null, 'needs an icon or an emoji');

  final IconData? icon;
  final String? emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WatotoColors.sun.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: icon != null
                ? Icon(icon, size: 20, color: WatotoColors.deep)
                : Text(emoji!, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: WatotoColors.deep.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: WatotoColors.deep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable "go and do this" line — change password, add an email. Rows
/// rather than buttons on purpose: the account screen already ends in two
/// weighty buttons, and a stack of five would leave nothing looking primary.
class AuthActionRow extends StatelessWidget {
  const AuthActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: subtitle == null ? label : '$label. $subtitle',
      child: ExcludeSemantics(child: _row(context)),
    );
  }

  Widget _row(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: WatotoColors.sky.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: WatotoColors.deep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: WatotoColors.deep,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: WatotoColors.deep.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: WatotoColors.deep.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthCloseButton extends StatelessWidget {
  const AuthCloseButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).closeButtonTooltip,
      child: ExcludeSemantics(child: _button()),
    );
  }

  Widget _button() {
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
