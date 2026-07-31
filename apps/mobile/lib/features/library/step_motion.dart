/// Gentle motion for the picture above a lesson stage.
///
/// The illustration is a still — one emoji, or a PNG once art exists for the
/// step. A slow breathe-and-bob makes it read as alive without costing a byte,
/// which matters here: the app is offline-first, so animated assets would have
/// to be bundled and the audio pack already accounts for 184 MB.
///
/// Deliberately calm, and deliberately only on the *decorative* picture. The
/// interactive emoji a child aims at stays perfectly still — a moving tap
/// target is harder for small hands and slower for anyone with a motor
/// difficulty.
library;

import 'package:flutter/material.dart';

/// Set in tests so `pumpAndSettle` doesn't wait forever on an animation that
/// never completes. Reduce-motion users get the same treatment automatically.
bool debugDisableStepMotion = false;

/// Breathes [child] — a slow scale and rise, reversing forever.
///
/// Pass [restartKey] (the step index) so the entry fade replays when the child
/// moves to the next step and the picture changes.
class BreathingArt extends StatefulWidget {
  const BreathingArt({super.key, required this.child, this.restartKey});

  final Widget child;
  final Object? restartKey;

  @override
  State<BreathingArt> createState() => _BreathingArtState();
}

class _BreathingArtState extends State<BreathingArt>
    with TickerProviderStateMixin {
  /// The perpetual breathe.
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// A one-shot settle when the step's picture first appears.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BreathingArt old) {
    super.didUpdateWidget(old);
    if (old.restartKey != widget.restartKey) {
      _enter.forward(from: 0);
    }
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (debugDisableStepMotion || reduce) {
      if (_breathe.isAnimating) _breathe.stop();
      _breathe.value = 0;
      _enter.value = 1;
      return;
    }
    if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathe, _enter]),
      builder: (context, child) {
        final breathe = Curves.easeInOut.transform(_breathe.value);
        final enter = Curves.easeOutBack.transform(_enter.value.clamp(0, 1));
        // Breathe is small on purpose: big enough to notice out of the corner
        // of an eye, small enough to read past while working.
        final scale = (0.96 + 0.04 * enter) * (1 + 0.035 * breathe);
        return Opacity(
          opacity: _enter.value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, -3 * breathe),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
