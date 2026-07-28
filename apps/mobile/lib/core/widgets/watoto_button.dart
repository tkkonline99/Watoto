import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/watoto_theme.dart';

/// Primary child-friendly pill button (design system §8.5).
///
/// Large tap target, optional squash animation, optional haptic on press.
class WatotoButton extends StatefulWidget {
  const WatotoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.secondary = false,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool secondary;
  final bool haptic;

  @override
  State<WatotoButton> createState() => _WatotoButtonState();
}

class _WatotoButtonState extends State<WatotoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final child = AnimatedScale(
      scale: _pressed && enabled ? 0.96 : 1,
      duration: const Duration(milliseconds: 80),
      child: widget.secondary
          ? OutlinedButton(
              onPressed: enabled ? _tap : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                foregroundColor: WatotoColors.deep,
                side: const BorderSide(color: WatotoColors.deep, width: 2),
                textStyle: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _labelRow(),
            )
          : FilledButton(
              onPressed: enabled ? _tap : null,
              style: FilledButton.styleFrom(
                backgroundColor: WatotoColors.sun,
                foregroundColor: WatotoColors.deep,
                disabledBackgroundColor: WatotoColors.sun.withValues(alpha: 0.4),
                minimumSize: const Size(120, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _labelRow(),
            ),
    );
    if (!widget.expanded) return child;
    return SizedBox(width: double.infinity, child: child);
  }

  Widget _labelRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 22),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
      ],
    );
  }

  void _tap() {
    if (widget.haptic) HapticFeedback.lightImpact();
    setState(() => _pressed = true);
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _pressed = false);
    });
    widget.onPressed?.call();
  }
}
