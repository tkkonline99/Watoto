/// Drawn circuit diagrams used as answer options.
///
/// Steps 3–6 of s10.science.lesson.01 ask real questions — what happens when
/// the loop is cut, which material closes a gap, what is missing, why a switch
/// goes *in* the wire — and every one of them was a bare `tap` on the item's
/// emoji. The child tapped a picture of a battery to "answer" a question about
/// a bulb, and could not get it wrong.
///
/// The answers are circuits, so the options are circuits. Each figure is a
/// complete little diagram: a loop, a battery, a bulb, and whatever the
/// question turns on. Drawn rather than photographed so the three language
/// builds stay identical and the bundle stays small.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The diagrams a question can offer. Names are the ids the content uses, so
/// a step declares `figures: ["loop-lit", "loop-cut"]` and gets these.
enum CircuitFigure {
  /// A closed loop: the bulb is lit.
  loopLit,

  /// The same loop cut open on one side: the bulb is dark.
  loopCut,

  /// A gap bridged by metal — the only material here that closes the circuit.
  gapMetal,

  /// A gap bridged by wood.
  gapWood,

  /// A gap bridged by plastic.
  gapPlastic,

  /// The parts on their own, for "what is missing?".
  partBattery,
  partBulb,
  partWire,

  /// A switch cut into the loop, where it can break it.
  switchInLoop,

  /// A switch sitting beside the loop, wired to nothing.
  switchBeside,
}

/// Parses a content-side figure id. Null for anything unknown, so a typo in
/// the content shows a plain word option rather than crashing the lesson.
CircuitFigure? circuitFigureFor(String id) {
  final key = id.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  for (final f in CircuitFigure.values) {
    if (f.name.toLowerCase() == key) return f;
  }
  return null;
}

/// Whether [figure] shows its bulb lit.
///
/// Deliberately a named list rather than "lit whenever the loop is closed".
/// Metal in the gap *does* close the circuit, but lighting that bulb would
/// answer step 4 — "which material will let the circuit work?" — inside the
/// very picture the child is choosing between. All three gap materials stay
/// dark so the question survives.
///
/// [CircuitFigure.switchBeside] is lit for the opposite reason: it is the
/// whole point of step 6. A switch beside the wire does nothing, so the bulb
/// it does nothing to is still on — next to an in-loop switch that has broken
/// its own loop and gone dark. Without that contrast the two options differ
/// only by where a small lever sits.
bool circuitFigureIsLit(CircuitFigure figure) =>
    figure == CircuitFigure.loopLit || figure == CircuitFigure.switchBeside;

// The palette is the diagram's own, not the app chrome's: a wire has to read
// as a wire, and a AA battery as a battery, before it reads as Watoto.
const _wire = Color(0xFF1C3D5E);
const _sand = Color(0xFFEBE1CE);
const _batteryBody = Color(0xFF7FBF3F);
const _batteryDark = Color(0xFF6BA834);
const _metalGrey = Color(0xFFB9BDC0);
const _metalBridge = Color(0xFF8E9498);
const _bulbLit = Color(0xFFFFD23F);
const _bulbDark = Color(0xFFD9D9D9);
const _ray = Color(0xFFF2B01E);
const _wood = Color(0xFFB07B4B);
const _plastic = Color(0xFF4E93C8);

/// A single diagram, sized to fit its box.
class CircuitFigureView extends StatelessWidget {
  const CircuitFigureView({super.key, required this.figure, this.size = 168});

  final CircuitFigure figure;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size * 0.80,
        child: CustomPaint(painter: _CircuitPainter(figure)),
      );
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter(this.figure);

  final CircuitFigure figure;

  bool get _hasSwitch =>
      figure == CircuitFigure.switchInLoop ||
      figure == CircuitFigure.switchBeside;

  bool get _isPart => switch (figure) {
        CircuitFigure.partBattery ||
        CircuitFigure.partBulb ||
        CircuitFigure.partWire =>
          true,
        _ => false,
      };

  /// Which material sits in the gap, if any.
  Color? get _bridge => switch (figure) {
        CircuitFigure.gapMetal => _metalBridge,
        CircuitFigure.gapWood => _wood,
        CircuitFigure.gapPlastic => _plastic,
        _ => null,
      };

  /// The loop is open — cut, or broken by a switch, or bridged by something.
  bool get _open => switch (figure) {
        CircuitFigure.loopCut ||
        CircuitFigure.gapMetal ||
        CircuitFigure.gapWood ||
        CircuitFigure.gapPlastic ||
        CircuitFigure.switchInLoop =>
          true,
        _ => false,
      };

  bool get _bulbIsLit => circuitFigureIsLit(figure);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Every figure sits on the same sand oval, so a row of options reads as
    // one set rather than a scrapbook.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.54),
        width: w * 0.98,
        height: h * 0.86,
      ),
      Paint()..color = _sand,
    );

    if (_isPart) {
      _paintPart(canvas, size);
      return;
    }

    final rect = Rect.fromLTRB(w * 0.19, h * 0.40, w * 0.81, h * 0.84);
    const radius = 12.0;
    final stroke = Paint()
      ..color = _wire
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.042
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The gap always sits mid-way down the right-hand edge.
    final gapHalf = _open ? h * (_hasSwitch ? 0.17 : 0.12) : 0.0;
    final midY = rect.center.dy;
    _drawLoop(canvas, rect, radius, stroke, gapHalf, midY);

    if (_bridge case final colour?) {
      final bridge = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rect.right, midY),
          width: w * 0.11,
          height: gapHalf * 2.1,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(bridge, Paint()..color = colour);
      canvas.drawRRect(
        bridge,
        Paint()
          ..color = _wire.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (figure == CircuitFigure.switchInLoop) {
      _drawSwitch(canvas, Offset(rect.right, midY + gapHalf), w, gapHalf * 2);
    }
    if (figure == CircuitFigure.switchBeside) {
      // Off to the side and wired to nothing: the loop behind it is unbroken.
      const span = 0.15;
      _drawSwitch(
        canvas,
        Offset(rect.right + w * 0.11, midY + w * span / 2),
        w,
        w * span,
      );
    }

    _drawBattery(canvas, Offset(rect.center.dx, rect.bottom), w);
    _drawBulb(canvas, Offset(rect.center.dx, rect.top), w, lit: _bulbIsLit);
  }

  /// The loop, optionally interrupted on the right edge. Drawn segment by
  /// segment rather than as an RRect so the cut lands exactly on the edge
  /// mid-point in every figure.
  void _drawLoop(
    Canvas canvas,
    Rect r,
    double radius,
    Paint stroke,
    double gapHalf,
    double midY,
  ) {
    final path = Path();
    // Right edge, upper half — start below the top-right corner.
    path.moveTo(r.right, r.top + radius);
    if (gapHalf > 0) {
      path.lineTo(r.right, midY - gapHalf);
      path.moveTo(r.right, midY + gapHalf);
    }
    path.lineTo(r.right, r.bottom - radius);
    path.arcToPoint(
      Offset(r.right - radius, r.bottom),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    path.lineTo(r.left + radius, r.bottom);
    path.arcToPoint(
      Offset(r.left, r.bottom - radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    path.lineTo(r.left, r.top + radius);
    path.arcToPoint(
      Offset(r.left + radius, r.top),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    path.lineTo(r.right - radius, r.top);
    path.arcToPoint(
      Offset(r.right, r.top + radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    canvas.drawPath(path, stroke);

    // A plain gap reads as a drawing mistake; hooked ends read as a cut.
    if (gapHalf > 0 && _bridge == null && !_hasSwitch) {
      final hook = r.width * 0.07;
      final upper = Path()
        ..moveTo(r.right, midY - gapHalf)
        ..quadraticBezierTo(
          r.right + hook, midY - gapHalf,
          r.right + hook, midY - gapHalf * 0.25,
        );
      final lower = Path()
        ..moveTo(r.right, midY + gapHalf)
        ..quadraticBezierTo(
          r.right + hook, midY + gapHalf,
          r.right + hook, midY + gapHalf * 0.25,
        );
      canvas.drawPath(upper, stroke);
      canvas.drawPath(lower, stroke);
    }
  }

  void _drawBattery(Canvas canvas, Offset centre, double w) {
    final bw = w * 0.36;
    final bh = w * 0.115;
    final body = Rect.fromCenter(center: centre, width: bw, height: bh);
    final rrect =
        RRect.fromRectAndRadius(body, Radius.circular(bh * 0.28));
    canvas.drawRRect(rrect, Paint()..color = _batteryBody);
    // Darker minus end, so the poles are legible without reading the signs.
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTRB(body.left, body.top, body.left + bw * 0.42, body.bottom),
      Paint()..color = _batteryDark,
    );
    canvas.restore();
    // Positive terminal nub.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(body.right + bw * 0.06, centre.dy),
          width: bw * 0.10,
          height: bh * 0.52,
        ),
        Radius.circular(bh * 0.14),
      ),
      Paint()..color = _metalGrey,
    );

    final bar = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    final signW = bw * 0.11;
    final minusX = body.left + bw * 0.21;
    final plusX = body.right - bw * 0.21;
    canvas.drawLine(
      Offset(minusX - signW / 2, centre.dy),
      Offset(minusX + signW / 2, centre.dy),
      bar,
    );
    canvas.drawLine(
      Offset(plusX - signW / 2, centre.dy),
      Offset(plusX + signW / 2, centre.dy),
      bar,
    );
    canvas.drawLine(
      Offset(plusX, centre.dy - signW / 2),
      Offset(plusX, centre.dy + signW / 2),
      bar,
    );
  }

  void _drawBulb(Canvas canvas, Offset centre, double w, {required bool lit}) {
    final r = w * 0.105;
    // The glass sits above the wire and the screw base bridges down to it;
    // centred on the wire the bulb looked half-buried in the loop.
    final glassCentre = Offset(centre.dx, centre.dy - r * 1.15);

    if (lit) {
      canvas.drawCircle(
        glassCentre,
        r * 1.75,
        Paint()..color = _bulbLit.withValues(alpha: 0.28),
      );
      final rayPaint = Paint()
        ..color = _ray
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round;
      for (final deg in [-125.0, -90.0, -55.0]) {
        final a = deg * math.pi / 180;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          glassCentre + dir * (r * 1.95),
          glassCentre + dir * (r * 2.55),
          rayPaint,
        );
      }
    }

    canvas.drawCircle(
      glassCentre,
      r,
      Paint()..color = lit ? _bulbLit : _bulbDark,
    );
    canvas.drawCircle(
      glassCentre,
      r,
      Paint()
        ..color = _wire
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.030,
    );
    // Screw base, sitting on the wire.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centre.dx, centre.dy - r * 0.16),
          width: r * 1.15,
          height: r * 0.62,
        ),
        Radius.circular(r * 0.16),
      ),
      Paint()..color = _metalGrey,
    );
  }

  /// A lever on a pivot. [up] draws it open (angled away), which is what a
  /// switch in a loop looks like when the loop is broken.
  /// A switch: two terminals with an open lever hinged on the lower one.
  /// [span] is the distance between the terminals.
  void _drawSwitch(Canvas canvas, Offset lower, double w, double span) {
    final stroke = Paint()
      ..color = _wire
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.040
      ..strokeCap = StrokeCap.round;
    final upper = Offset(lower.dx, lower.dy - span);
    // Hinged on the lower contact and swung out towards the upper one without
    // reaching it. That space between lever tip and contact is what "off"
    // looks like, and it is the whole difference between these two figures.
    final lever = Offset(lower.dx + span * 0.50, lower.dy - span * 0.80);
    canvas.drawLine(lower, lever, stroke);
    final dot = Paint()..color = _wire;
    canvas.drawCircle(lower, w * 0.030, dot);
    canvas.drawCircle(upper, w * 0.030, dot);
  }

  void _paintPart(Canvas canvas, Size size) {
    final w = size.width;
    final centre = Offset(w / 2, size.height * 0.54);
    switch (figure) {
      case CircuitFigure.partBattery:
        _drawBattery(canvas, centre, w * 1.25);
      case CircuitFigure.partBulb:
        _drawBulb(canvas, centre, w * 1.5, lit: false);
      case CircuitFigure.partWire:
        final stroke = Paint()
          ..color = _wire
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.052
          ..strokeCap = StrokeCap.round;
        final path = Path()
          ..moveTo(w * 0.24, centre.dy + size.height * 0.10)
          ..cubicTo(
            w * 0.40, centre.dy - size.height * 0.26,
            w * 0.60, centre.dy + size.height * 0.26,
            w * 0.76, centre.dy - size.height * 0.10,
          );
        canvas.drawPath(path, stroke);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_CircuitPainter old) => old.figure != figure;
}
