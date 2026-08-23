import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Squash-and-stretch press feedback kids love on tiles and buttons.
class BounceTap extends StatefulWidget {
  const BounceTap({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool haptic;

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    lowerBound: 0.92,
    upperBound: 1,
    value: 1,
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _press(VoidCallback action) async {
    if (widget.haptic) unawaited(HapticFeedback.selectionClick());
    await _ctl.reverse();
    await _ctl.forward();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => reduce ? widget.onTap() : _press(widget.onTap),
      onLongPress: widget.onLongPress == null
          ? null
          : () => reduce
              ? widget.onLongPress!()
              : _press(widget.onLongPress!),
      child: ScaleTransition(scale: _ctl, child: widget.child),
    );
  }
}
