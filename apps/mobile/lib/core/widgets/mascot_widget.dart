import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/watoto_theme.dart';

/// When true, Kibo's perpetual bounce is held still. Tests set this so
/// `pumpAndSettle` doesn't wait forever on an animation that never completes.
/// Reduce-motion users get the same treatment automatically.
bool debugDisableMascotAnimation = false;

/// Kibo the lion cub — lightweight mascot without Rive dependency.
///
/// States: idle bounce, cheer, think, sleep. Swap for a Rive state machine
/// later behind the same [MascotMood] API.
enum MascotMood { idle, cheer, think, sleep }

class MascotWidget extends StatefulWidget {
  const MascotWidget({
    super.key,
    this.mood = MascotMood.idle,
    this.size = 96,
    this.label,
  });

  final MascotMood mood;
  final double size;
  final String? label;

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  static Duration _beatFor(MascotMood mood) => switch (mood) {
        MascotMood.cheer => const Duration(milliseconds: 400),
        MascotMood.sleep => const Duration(milliseconds: 2200),
        MascotMood.idle || MascotMood.think => const Duration(milliseconds: 1200),
      };

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: _beatFor(widget.mood));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBounce();
  }

  @override
  void didUpdateWidget(covariant MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBounce();
  }

  /// Runs (or holds) the bounce for the current mood. Held still under
  /// reduce-motion and in tests, where a perpetual controller would stall
  /// `pumpAndSettle`.
  void _syncBounce() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (debugDisableMascotAnimation || reduce) {
      if (_ctl.isAnimating) _ctl.stop();
      _ctl.value = 0;
      return;
    }
    final beat = _beatFor(widget.mood);
    if (_ctl.duration != beat || !_ctl.isAnimating) {
      _ctl.duration = beat;
      _ctl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String get _emoji => switch (widget.mood) {
        MascotMood.idle => '🦁',
        MascotMood.cheer => '🎉',
        MascotMood.think => '🤔',
        MascotMood.sleep => '😴',
      };

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: widget.label ?? 'Kibo the lion cub',
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, child) {
          final t = reduce ? 0.0 : _ctl.value;
          final dy = switch (widget.mood) {
            MascotMood.cheer => -8 * math.sin(t * math.pi),
            MascotMood.sleep => 2 * math.sin(t * math.pi),
            MascotMood.think => 0.0,
            MascotMood.idle => -4 * math.sin(t * math.pi),
          };
          final scale = widget.mood == MascotMood.cheer ? 1 + 0.08 * t : 1.0;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                WatotoColors.sun.withValues(alpha: 0.35),
                WatotoColors.cloud,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: WatotoColors.deep.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(_emoji, style: TextStyle(fontSize: widget.size * 0.5)),
        ),
      ),
    );
  }
}
