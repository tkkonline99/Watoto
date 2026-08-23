import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/watoto_theme.dart';

/// When true, the perpetual ambient drift (drifting clouds, butterfly, bird) is
/// held still. Tests set this so `pumpAndSettle` doesn't wait forever on an
/// animation that never completes. Reduce-motion users get the same treatment
/// automatically via [MediaQueryData.disableAnimations] (see [_SavannaSceneState]).
bool debugDisableSavannaAmbient = false;

// Savanna scene colours, shared by every screen so the chrome stays identical.
const _bgTop = Color(0xFFFFF7E6);
const _bgBottom = Color(0xFFFFE0A0);
const _groundBack = Color(0xFFC2DD9C);
const _groundFront = Color(0xFFA7CE7C);

/// Full-screen savanna backdrop: radial cream→gold sky, a glowing sun, drifting
/// clouds, a grassy ground, a tree, a butterfly and a bird. Drop it at the back
/// of a [Stack] (it sizes to its parent). Shared by the language, onboarding and
/// home screens via [SavannaScaffold].
class SavannaScene extends StatefulWidget {
  const SavannaScene({super.key, this.extras = const []});

  /// Decorations the child has earned or bought. Onboarding passes none; the
  /// home passes the child's world so the backdrop reflects their progress
  /// instead of being the same wallpaper for everyone.
  final List<SceneDecoration> extras;

  @override
  State<SavannaScene> createState() => _SavannaSceneState();
}

/// A decoration to draw, in scene-relative coordinates.
///
/// Deliberately a plain value type rather than the gamification model: this
/// file stays a dumb renderer with no dependency on progress rules, which
/// keeps it usable from onboarding (where there is no child yet).
class SceneDecoration {
  const SceneDecoration({
    required this.emoji,
    required this.x,
    required this.y,
    this.scale = 1.0,
  });

  /// 0..1 across the scene.
  final double x;

  /// 0..1 down the ground band.
  final double y;
  final String emoji;
  final double scale;
}

class _SavannaSceneState extends State<SavannaScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (debugDisableSavannaAmbient || reduce) {
      if (_ambient.isAnimating) _ambient.stop();
      _ambient.value = 0;
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.55),
                radius: 1.25,
                colors: [_bgTop, _bgBottom],
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _ambient,
          builder: (context, _) => _SavannaDecor(t: _ambient.value),
        ),
        if (widget.extras.isNotEmpty)
          Positioned.fill(
            child: _EarnedDecorLayer(extras: widget.extras),
          ),
      ],
    );
  }
}

/// The child's own savanna, laid out along the grass at the foot of the scene.
///
/// Decorative only — it never takes pointer events, so the content above it
/// stays fully tappable.
///
/// Confined to the grass band deliberately. An earlier version spread these
/// across the lower 45% of the screen, which is exactly where the home's card
/// stack sits: animals ended up floating over the cards and reading as render
/// bugs rather than as scenery.
class _EarnedDecorLayer extends StatelessWidget {
  const _EarnedDecorLayer({required this.extras});

  final List<SceneDecoration> extras;

  /// Height of the painted ground, matching the `_Ground` box below.
  static const double _groundHeight = 200;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            // Sit on the grass: the top of the band is the ground line, and
            // decorations spread through its upper two-thirds so none of them
            // hang off the bottom of the screen.
            final bandTop = (h - _groundHeight * 0.82).clamp(0.0, h);
            final bandHeight = _groundHeight * 0.52;
            return Stack(
              children: [
                for (final d in extras)
                  Positioned(
                    left: (w * d.x).clamp(0.0, w - 40),
                    top: bandTop + bandHeight * d.y,
                    child: Opacity(
                      opacity: 0.92,
                      child: Text(
                        d.emoji,
                        style: TextStyle(fontSize: 30 * d.scale),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Scaffold whose body is the [SavannaScene] with a top chrome bar (the Watoto
/// wordmark on the left, an optional [topRight] action) and [child] filling the
/// space below. Used by every full-screen savanna screen.
class SavannaScaffold extends StatelessWidget {
  const SavannaScaffold({
    super.key,
    required this.child,
    this.topRight,
    this.extras = const [],
  });

  final Widget child;

  /// Optional top-right action (e.g. the parent-zone lock on the home).
  final Widget? topRight;

  /// The child's earned/bought savanna decorations. Empty during onboarding.
  final List<SceneDecoration> extras;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: SavannaScene(extras: extras)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 14, 0),
                  child: Row(
                    children: [
                      // The wordmark is a logo, not content, and it used to be
                      // laid out at whatever width it wanted. "Text size" goes
                      // to 1.6 and stacks on the device's own setting, so at
                      // around 2x it grew wider than the bar and pushed the
                      // account, language and parent-zone buttons off the
                      // right edge — the top bar overflowed on every screen
                      // built on this scaffold, including onboarding.
                      //
                      // The controls take their size first and the mark takes
                      // what is left, shrinking only when there is not enough.
                      // At ordinary text sizes nothing moves; a reader who
                      // needs large text keeps the buttons instead of losing
                      // them to the brand.
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _Wordmark(),
                          ),
                        ),
                      ),
                      ?topRight,
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White circular lock that opens the parent zone on the home. When [onTap] is
/// null it is a non-interactive badge (used during onboarding, where there is no
/// parent zone yet) so the chrome still matches the design.
class SavannaLockButton extends StatelessWidget {
  const SavannaLockButton({super.key, this.onTap, this.tooltip});

  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: WatotoColors.deep.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text('🔒', style: TextStyle(fontSize: 20)),
    );
    if (onTap == null) return circle;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: circle,
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text('🦁', style: TextStyle(fontSize: 26)),
        SizedBox(width: 8),
        Text(
          'Watoto',
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: WatotoColors.deep,
          ),
        ),
      ],
    );
  }
}

/// Sun, drifting clouds, a grassy ground, a tree, a butterfly and a bird. All
/// movement is sine-driven off the shared ambient clock [t] (0..1).
class _SavannaDecor extends StatelessWidget {
  const _SavannaDecor({required this.t});
  final double t;

  double _wave(double phase, double amp) =>
      math.sin((t + phase) * 2 * math.pi) * amp;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -36,
          right: -28,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD166),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.5),
                  blurRadius: 50,
                  spreadRadius: 12,
                ),
              ],
            ),
          ),
        ),
        Positioned(top: 70, left: 24 + _wave(0.0, 12), child: const _Cloud(width: 92)),
        Positioned(top: 130, right: 30 + _wave(0.5, 14), child: const _Cloud(width: 64)),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SizedBox(height: 200, child: _Ground()),
        ),
        Positioned(
          bottom: 18,
          left: 12,
          child: Text('🌳', style: TextStyle(fontSize: 72 + _wave(0.2, 1.5))),
        ),
        Positioned(
          top: 150 + _wave(0.1, 10),
          left: 26 + _wave(0.35, 8),
          child: Transform.rotate(
            angle: _wave(0.0, 0.15),
            child: const Text('🦋', style: TextStyle(fontSize: 30)),
          ),
        ),
        Positioned(
          bottom: 46 + _wave(0.6, 6),
          right: 40 + _wave(0.25, 10),
          child: const Text('🐦', style: TextStyle(fontSize: 30)),
        ),
      ],
    );
  }
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 0.42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(width),
        boxShadow: [
          BoxShadow(
            color: WatotoColors.deep.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _Ground extends StatelessWidget {
  const _Ground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GroundPainter(), size: Size.infinite);
  }
}

class _GroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final back = Paint()..color = _groundBack;
    final backPath = Path()
      ..moveTo(0, h * 0.45)
      ..quadraticBezierTo(w * 0.5, h * 0.18, w, h * 0.42)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(backPath, back);

    final front = Paint()..color = _groundFront;
    final frontPath = Path()
      ..moveTo(0, h * 0.62)
      ..quadraticBezierTo(w * 0.5, h * 0.42, w, h * 0.6)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(frontPath, front);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
