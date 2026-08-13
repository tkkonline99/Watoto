/// Cause-and-effect stages for the story pages whose own text promises a touch.
///
/// "Tap the seed... a flower grows!" is printed under every page of
/// `s01.cause.story.01`, and until now nothing happened when a child tapped:
/// the stage was a flat PNG of a flower that was *already grown*. The page
/// asked for something, gave no way to do it, and showed the answer up front.
/// For the 0–1 band, where cause and effect is the whole lesson, that is the
/// lesson missing.
///
/// Two tiers, deliberately:
///
///  * the four Cause & Effect pages get a **drawn** scene that starts at the
///    cause (a seed in the earth) and grows to the effect (a flower) — the
///    child's press is what moves it, so the picture cannot give the answer
///    away before they act;
///  * every other page whose text promises a tap keeps the art it already
///    ships with and gains the press, the pop and the label. No new art, and
///    no page left saying "tap" to a picture that ignores it.
///
/// A page that never asks for a touch is left alone. A press target with
/// nothing behind it teaches that pressing does nothing, which is worse than
/// no target at all.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/watoto_theme.dart';

/// The drawn scenes, chosen by the art a page already ships with.
enum PressScene { seedFlower, skySun, cloudRain, star }

const _sceneByAsset = <String, PressScene>{
  'img/s01/seed_flower.png': PressScene.seedFlower,
  'img/s01/sky_sun.png': PressScene.skySun,
  'img/s01/cloud_rain.png': PressScene.cloudRain,
  'img/s01/star.png': PressScene.star,
};

/// The drawn scene for [assetRef], or null where the page keeps its own art.
PressScene? pressSceneForAsset(String? assetRef) =>
    assetRef == null ? null : _sceneByAsset[assetRef];

/// Whether this page's text promises the child a touch.
///
/// Read off the narration rather than a flag on the item, because the
/// narration is the promise: it is what the child is told, and it is the thing
/// that was going unanswered. 29 pages across 24 stories say one of these.
bool pageInvitesPress(String narration) =>
    RegExp(r'\b(tap|press|touch|poke|shake)\b', caseSensitive: false)
        .hasMatch(narration);

/// A stage that answers a press.
///
/// Before the press it shows the cause — a drawn [scene] at rest, or the
/// page's own art. The press runs it to the effect and calls [onPressed] once,
/// so the caller can speak the line and show its banner. Pressing again
/// replays it, because a one-year-old's way of confirming that they caused
/// something is to do it repeatedly.
///
/// **Give it a key that changes with the page.** The growth lives in this
/// State, and the caller rebuilds on the very press that starts it — so
/// without a per-page key the next page opens already grown, and comparing
/// the incoming `child` instead would reset the animation on that first
/// rebuild and nothing would ever move.
class PressableStage extends StatefulWidget {
  const PressableStage({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.scene,
    this.onPressed,
  });

  /// The page's own art. Shown as the resting state where there is no [scene],
  /// and kept as the fallback if a drawn scene is ever removed.
  final Widget child;

  /// Announced on the tap target. The stage's own label is suppressed by the
  /// scaffold when it is interactive, so this is the only thing read out.
  final String semanticLabel;

  final PressScene? scene;

  /// Fired on the press that starts the growth, not on every frame.
  final VoidCallback? onPressed;

  @override
  State<PressableStage> createState() => _PressableStageState();
}

class _PressableStageState extends State<PressableStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _press() {
    widget.onPressed?.call();
    _c
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: _press,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeOutBack.transform(_c.value.clamp(0.0, 1.0));
            if (scene != null) {
              // Fills the stage rather than sitting at a fixed 150: the
              // picture *is* the activity on these pages, and a flower a
              // thumb-width across is not something a one-year-old is going
              // to reach for. Square, and taken from the smaller side, so it
              // grows with the stage without ever overflowing it.
              return LayoutBuilder(
                builder: (context, box) {
                  final side = math.min(
                    box.hasBoundedWidth ? box.maxWidth : 300.0,
                    box.hasBoundedHeight ? box.maxHeight : 300.0,
                  );
                  return CustomPaint(
                    painter: _ScenePainter(scene, t),
                    size: Size.square(side),
                  );
                },
              );
            }
            // No drawn scene: the page's own art answers with a pop. Scale is
            // eased so it settles rather than snapping back.
            final pop = 1 + 0.12 * math.sin(math.pi * _c.value);
            return Transform.scale(scale: pop, child: widget.child);
          },
        ),
      ),
    );
  }
}

/// Draws one [PressScene] at progress [t] — 0 is the cause, 1 the effect.
///
/// Everything is interpolated rather than swapped between two pictures, so the
/// child sees the stem *grow* out of the seed they pressed. A cut would show
/// the same two frames and teach none of the causation.
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.t);

  final PressScene scene;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Scenes that fill their box — sky, hill, cloud — are rounded to sit
    // inside the stage card rather than showing square corners against it.
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
    );
    switch (scene) {
      case PressScene.seedFlower:
        _seedFlower(canvas, size);
      case PressScene.skySun:
        _skySun(canvas, size);
      case PressScene.cloudRain:
        _cloudRain(canvas, size);
      case PressScene.star:
        _star(canvas, size);
    }
  }

  /// A seed in the earth that grows a stem, a leaf and a five-petal flower.
  void _seedFlower(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final groundY = h * 0.86;
    final cx = w / 2;

    // The sun sits behind the whole scene at rest and stays put — it is the
    // seed that answers the press, not the sky.
    canvas.drawCircle(
      Offset(cx, h * 0.34),
      w * 0.30,
      Paint()..color = WatotoColors.sun.withValues(alpha: 0.22),
    );

    // Earth line.
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.18, groundY, w * 0.82, groundY + h * 0.05,
          Radius.circular(h * 0.03)),
      Paint()..color = WatotoColors.leaf.withValues(alpha: 0.35),
    );

    // 0.46 rather than filling the height: the bloom sits a further 2.25 petal
    // radii above this, and `easeOutBack` overshoots past 1 on the way in, so
    // a taller stem clipped the top petal against the card during the bounce.
    final stemTop = groundY - (h * 0.46) * t;
    if (t > 0.02) {
      canvas.drawLine(
        Offset(cx, groundY),
        Offset(cx, stemTop),
        Paint()
          ..color = WatotoColors.leaf
          ..strokeWidth = w * 0.045
          ..strokeCap = StrokeCap.round,
      );
    }

    // A leaf unfurls from halfway up, once there is stem to hang it on.
    if (t > 0.45) {
      final k = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
      final ly = groundY - (groundY - stemTop) * 0.45;
      final path = Path()
        ..moveTo(cx, ly)
        ..quadraticBezierTo(
            cx + w * 0.20 * k, ly - h * 0.10 * k, cx + w * 0.24 * k, ly)
        ..quadraticBezierTo(cx + w * 0.16 * k, ly + h * 0.05 * k, cx, ly);
      canvas.drawPath(path, Paint()..color = WatotoColors.leaf);
    }

    // The seed: always there, shrinking away as the flower takes over so the
    // child can see it became the flower rather than being replaced by one.
    final seed = (1 - t).clamp(0.0, 1.0);
    if (seed > 0.02) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, groundY - h * 0.03 * seed),
          width: w * 0.14 * seed,
          height: h * 0.18 * seed,
        ),
        Paint()..color = const Color(0xFF8D6E63),
      );
    }

    if (t <= 0.35) return;
    final bloom = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    final r = w * 0.13 * bloom;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * (2 * math.pi / 5);
      canvas.drawCircle(
        Offset(cx + math.cos(a) * r * 1.25, stemTop + math.sin(a) * r * 1.25),
        r,
        Paint()..color = WatotoColors.berry,
      );
    }
    canvas.drawCircle(
      Offset(cx, stemTop),
      r * 0.72,
      Paint()..color = WatotoColors.sun,
    );
  }

  /// A dim sky that brightens as the sun climbs above the hill.
  void _skySun(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * 0.72;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()..color = WatotoColors.sky.withValues(alpha: 0.10 + 0.22 * t),
    );
    final cy = horizon - (h * 0.34) * t;
    if (t > 0.25) {
      final k = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
      final ray = Paint()
        ..color = WatotoColors.sun.withValues(alpha: 0.55 * k)
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final r0 = w * 0.20, r1 = w * (0.24 + 0.07 * k);
        canvas.drawLine(
          Offset(w / 2 + math.cos(a) * r0, cy + math.sin(a) * r0),
          Offset(w / 2 + math.cos(a) * r1, cy + math.sin(a) * r1),
          ray,
        );
      }
    }
    canvas.drawCircle(
      Offset(w / 2, cy),
      w * 0.16,
      Paint()..color = WatotoColors.sun,
    );
    canvas.drawArc(
      Rect.fromLTWH(-w * 0.15, horizon - h * 0.06, w * 1.3, h * 0.7),
      math.pi,
      math.pi,
      true,
      Paint()..color = WatotoColors.leaf.withValues(alpha: 0.45),
    );
  }

  /// A cloud that lets go of its rain.
  void _cloudRain(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cy = h * 0.34;
    final cloud = Paint()..color = WatotoColors.sky.withValues(alpha: 0.28);
    for (final o in [
      Offset(w * 0.38, cy),
      Offset(w * 0.50, cy - h * 0.07),
      Offset(w * 0.62, cy),
    ]) {
      canvas.drawCircle(o, w * 0.13, cloud);
    }
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.30, cy, w * 0.70, cy + h * 0.11,
          Radius.circular(h * 0.06)),
      cloud,
    );
    if (t <= 0.05) return;
    final drop = Paint()..color = WatotoColors.sky.withValues(alpha: 0.75);
    for (var i = 0; i < 5; i++) {
      // Each drop starts a little later, so the rain falls rather than
      // appearing all at once.
      final k = ((t - i * 0.07) / 0.7).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final x = w * (0.34 + i * 0.08);
      final y = cy + h * 0.14 + (h * 0.42) * k;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y), width: w * 0.035, height: h * 0.075),
        drop..color = WatotoColors.sky.withValues(alpha: 0.75 * (1 - k * 0.5)),
      );
    }
  }

  /// A star that wakes up and twinkles.
  void _star(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.46);
    final r = w * (0.16 + 0.06 * t);
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = WatotoColors.sun.withValues(alpha: 0.45 + 0.55 * t),
    );
    if (t <= 0.3) return;
    final k = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
    final spark = Paint()
      ..color = WatotoColors.sun.withValues(alpha: 0.8 * (1 - k * 0.4))
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 4 + i * math.pi / 2;
      final r0 = r * 1.35, r1 = r * (1.5 + 0.5 * k);
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r0, c.dy + math.sin(a) * r0),
        Offset(c.dx + math.cos(a) * r1, c.dy + math.sin(a) * r1),
        spark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.t != t || old.scene != scene;
}
