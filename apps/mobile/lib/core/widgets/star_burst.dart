import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/watoto_theme.dart';

/// Lightweight celebration burst (no Lottie dependency).
///
/// Particles rise and fade for ~1.6s. Respects [MediaQuery.disableAnimations].
class StarBurst extends StatefulWidget {
  const StarBurst({
    super.key,
    this.particleCount = 18,
    this.size = 220,
  });

  final int particleCount;
  final double size;

  @override
  State<StarBurst> createState() => _StarBurstState();
}

class _StarBurstState extends State<StarBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _particles = List.generate(widget.particleCount, (i) {
      final angle = (i / widget.particleCount) * math.pi * 2 + rng.nextDouble();
      return _Particle(
        angle: angle,
        speed: 40 + rng.nextDouble() * 70,
        spin: rng.nextDouble() * math.pi,
        emoji: const ['⭐', '✨', '🌟', '💛', '🎉'][i % 5],
        size: 14 + rng.nextDouble() * 12,
      );
    });
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: Text('🎉', style: TextStyle(fontSize: 48)),
        ),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_ctl.value);
          final fade = (1 - _ctl.value).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final p in _particles)
                Transform.translate(
                  offset: Offset(
                    math.cos(p.angle) * p.speed * t,
                    math.sin(p.angle) * p.speed * t - 20 * t,
                  ),
                  child: Transform.rotate(
                    angle: p.spin * t,
                    child: Opacity(
                      opacity: fade,
                      child: Text(
                        p.emoji,
                        style: TextStyle(fontSize: p.size),
                      ),
                    ),
                  ),
                ),
              // Soft glow core
              Container(
                width: 72 * (1 + 0.15 * math.sin(_ctl.value * math.pi)),
                height: 72 * (1 + 0.15 * math.sin(_ctl.value * math.pi)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      WatotoColors.sun.withValues(alpha: 0.55 * fade),
                      WatotoColors.sun.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.emoji,
    required this.size,
  });
  final double angle;
  final double speed;
  final double spin;
  final String emoji;
  final double size;
}
