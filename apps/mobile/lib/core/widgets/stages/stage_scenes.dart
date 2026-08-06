/// The registered scene builders (docs/26 §26.3).
///
/// A scene is composed shapes that encode the maths or the structure —
/// counting arrays, base-ten columns, fraction bars — rather than a picture of
/// an object. They are drawn rather than bitmapped, so they localise and scale
/// for free, and an author can reach for one without commissioning art.
///
/// The ids here must match `SCENES` in `content/validate_content.py` and
/// `content/author_visuals.py`. A ref in the content with no builder here is a
/// validation error rather than an empty stage, which is what stops a scene
/// shipping with nothing behind it.
///
/// §26.6 holds throughout: colour never carries meaning alone. The fraction
/// bars differ in length as well as hue, the shapes differ in outline as well
/// as fill, and the sorting cues differ in border style.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/watoto_theme.dart';

/// What a scene knows about the part it is drawing for.
///
/// Steps carry `count`/`rows`/`cols` when the content stated them; questions
/// and story pages do not, so every field is optional and every builder has a
/// defensible default. A counting array with no count still has to draw
/// something a child can count.
class SceneData {
  const SceneData({this.count, this.rows, this.cols, this.text});

  final int? count;
  final int? rows;
  final int? cols;

  /// The prompt or narration, for scenes that show words.
  final String? text;
}

const Set<String> registeredScenes = {
  'counting.array',
  'counting.tens-and-units',
  'fraction.bars',
  'shape.loose-objects',
  'glyph.trace',
  'audio.waveform',
  'colour.field',
  'sentence.card',
};

/// The widget for [ref], or null when nothing is registered under that id.
Widget? buildScene(String ref, {SceneData data = const SceneData()}) =>
    switch (ref) {
      'counting.array' => _Scene(painter: _CountingArrayPainter(data)),
      'counting.tens-and-units' => _Scene(painter: _TensAndUnitsPainter(data)),
      'fraction.bars' => _Scene(painter: _FractionBarsPainter(data)),
      'shape.loose-objects' => _Scene(painter: _LooseObjectsPainter(data)),
      'glyph.trace' => _Scene(painter: _GlyphTracePainter(data)),
      'audio.waveform' => _Scene(painter: _WaveformPainter(data)),
      'colour.field' => _Scene(painter: _ColourFieldPainter(data)),
      'sentence.card' => _SentenceCard(data: data),
      _ => null,
    };

class _Scene extends StatelessWidget {
  const _Scene({required this.painter});

  final CustomPainter painter;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: CustomPaint(painter: painter, size: Size.infinite),
      );
}

// --------------------------------------------------------------- counting

class _CountingArrayPainter extends CustomPainter {
  _CountingArrayPainter(this.data);

  final SceneData data;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = data.rows ?? 1;
    final cols = data.cols ?? data.count ?? 5;
    final total = data.rows != null && data.cols != null
        ? rows * cols
        : (data.count ?? 5);
    final perRow = data.cols ?? math.min(total, 5);
    final rowCount = (total / perRow).ceil();

    final cell = math.min(size.width / (perRow + 1), size.height / (rowCount + 1));
    final r = cell * 0.34;
    final originX = (size.width - (perRow - 1) * cell) / 2;
    final originY = (size.height - (rowCount - 1) * cell) / 2;

    final fill = Paint()..color = WatotoColors.sun;
    final edge = Paint()
      ..color = WatotoColors.deep.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    var drawn = 0;
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < perRow && drawn < total; col++, drawn++) {
        final c = Offset(originX + col * cell, originY + row * cell);
        canvas.drawCircle(c, r, fill);
        canvas.drawCircle(c, r, edge);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CountingArrayPainter old) =>
      old.data.count != data.count ||
      old.data.rows != data.rows ||
      old.data.cols != data.cols;
}

class _TensAndUnitsPainter extends CustomPainter {
  _TensAndUnitsPainter(this.data);

  final SceneData data;

  @override
  void paint(Canvas canvas, Size size) {
    final value = data.count ?? 34;
    final tens = (value ~/ 10).clamp(0, 9);
    final units = value % 10;

    final rodW = size.width * 0.055;
    final rodH = size.height * 0.62;
    final gap = rodW * 0.55;
    final unitS = rodW * 0.82;

    final totalW = tens * (rodW + gap) + (units > 0 ? unitS * 2.6 : 0);
    var x = (size.width - totalW) / 2;
    final baseY = size.height * 0.78;

    final rod = Paint()..color = WatotoColors.sky;
    final unit = Paint()..color = WatotoColors.mango;
    final edge = Paint()
      ..color = WatotoColors.deep.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < tens; i++) {
      final rect = RRect.fromLTRBR(
        x, baseY - rodH, x + rodW, baseY, const Radius.circular(5));
      canvas.drawRRect(rect, rod);
      canvas.drawRRect(rect, edge);
      // Ten notches, so the rod reads as ten and not as a colour.
      for (var n = 1; n < 10; n++) {
        final y = baseY - rodH * n / 10;
        canvas.drawLine(Offset(x, y), Offset(x + rodW, y), edge);
      }
      x += rodW + gap;
    }
    x += gap;
    for (var i = 0; i < units; i++) {
      final col = i % 2, row = i ~/ 2;
      final left = x + col * (unitS + 4);
      final top = baseY - (row + 1) * (unitS + 4);
      final rect = RRect.fromLTRBR(
        left, top, left + unitS, top + unitS, const Radius.circular(4));
      canvas.drawRRect(rect, unit);
      canvas.drawRRect(rect, edge);
    }
  }

  @override
  bool shouldRepaint(covariant _TensAndUnitsPainter old) =>
      old.data.count != data.count;
}

// -------------------------------------------------------------- fractions

class _FractionBarsPainter extends CustomPainter {
  _FractionBarsPainter(this.data);

  final SceneData data;

  @override
  void paint(Canvas canvas, Size size) {
    // Two bars of the same whole cut differently, so the comparison is visible
    // as length. §26.6: never hue alone.
    const cuts = [2, 4];
    final barH = size.height * 0.2;
    final barW = size.width * 0.82;
    final left = (size.width - barW) / 2;

    final edge = Paint()
      ..color = WatotoColors.deep.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (var b = 0; b < cuts.length; b++) {
      final top = size.height * (b == 0 ? 0.22 : 0.56);
      final parts = cuts[b];
      final partW = barW / parts;
      for (var i = 0; i < parts; i++) {
        final rect = Rect.fromLTWH(left + i * partW, top, partW, barH);
        // One shaded part per bar: 1/2 against 1/4.
        final shaded = i == 0;
        canvas.drawRect(
          rect,
          Paint()
            ..color = shaded
                ? (b == 0 ? WatotoColors.leaf : WatotoColors.mango)
                : Colors.white,
        );
        canvas.drawRect(rect, edge);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FractionBarsPainter old) => false;
}

// ----------------------------------------------------------------- shapes

class _LooseObjectsPainter extends CustomPainter {
  _LooseObjectsPainter(this.data);

  final SceneData data;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) * 0.13;
    final cy = size.height / 2;
    final xs = [size.width * 0.24, size.width * 0.5, size.width * 0.76];
    final edge = Paint()
      ..color = WatotoColors.deep.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Circle
    canvas.drawCircle(Offset(xs[0], cy), r, Paint()..color = WatotoColors.berry);
    canvas.drawCircle(Offset(xs[0], cy), r, edge);
    // Square
    final sq = Rect.fromCenter(
        center: Offset(xs[1], cy), width: r * 1.9, height: r * 1.9);
    canvas.drawRect(sq, Paint()..color = WatotoColors.sky);
    canvas.drawRect(sq, edge);
    // Triangle
    final tri = Path()
      ..moveTo(xs[2], cy - r)
      ..lineTo(xs[2] + r, cy + r * 0.85)
      ..lineTo(xs[2] - r, cy + r * 0.85)
      ..close();
    canvas.drawPath(tri, Paint()..color = WatotoColors.sun);
    canvas.drawPath(tri, edge);
  }

  @override
  bool shouldRepaint(covariant _LooseObjectsPainter old) => false;
}

// ------------------------------------------------------------------ trace

class _GlyphTracePainter extends CustomPainter {
  _GlyphTracePainter(this.data);

  final SceneData data;

  @override
  void paint(Canvas canvas, Size size) {
    // A generic stroke with start and end markers: a dotted guide the child
    // follows. Tracing is never scored and never timed (§26.4).
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.22, h * 0.74)
      ..cubicTo(w * 0.34, h * 0.16, w * 0.66, h * 0.16, w * 0.78, h * 0.74);

    final guide = Paint()
      ..color = WatotoColors.sky.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, guide);

    final dash = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final metrics = path.computeMetrics().first;
    for (var d = 0.0; d < metrics.length; d += 18) {
      final seg = metrics.extractPath(d, math.min(d + 9, metrics.length));
      canvas.drawPath(seg, dash);
    }

    canvas.drawCircle(Offset(w * 0.22, h * 0.74), 11,
        Paint()..color = WatotoColors.leaf);
    canvas.drawCircle(Offset(w * 0.78, h * 0.74), 11,
        Paint()..color = WatotoColors.berry);
  }

  @override
  bool shouldRepaint(covariant _GlyphTracePainter old) => false;
}

// --------------------------------------------------------------- waveform

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.data);

  final SceneData data;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 21;
    final gap = size.width / (bars * 1.7);
    final barW = gap * 0.7;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = WatotoColors.sky
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    final startX = (size.width - (bars - 1) * gap * 1.7) / 2;
    for (var i = 0; i < bars; i++) {
      // Deterministic envelope — a waveform, not noise, so it looks the same
      // every rebuild.
      final t = i / (bars - 1);
      final amp = (math.sin(t * math.pi) * 0.8 + 0.2) *
          (0.55 + 0.45 * math.sin(t * math.pi * 6));
      final half = (size.height * 0.34) * amp.abs().clamp(0.08, 1.0);
      final x = startX + i * gap * 1.7;
      canvas.drawLine(Offset(x, cy - half), Offset(x, cy + half), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => false;
}

// ----------------------------------------------------------------- colour

class _ColourFieldPainter extends CustomPainter {
  _ColourFieldPainter(this.data);

  final SceneData data;

  /// The colour named in the text, if it names one. Falls back to the sun
  /// token — a field has to be *some* colour, and guessing a wrong one is
  /// worse than a neutral one.
  Color get _colour {
    final t = (data.text ?? '').toLowerCase();
    if (t.contains('red')) return WatotoColors.berry;
    if (t.contains('blue')) return WatotoColors.sky;
    if (t.contains('green')) return WatotoColors.leaf;
    if (t.contains('orange')) return WatotoColors.mango;
    if (t.contains('yellow')) return WatotoColors.sun;
    return WatotoColors.sun;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.72;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side),
      const Radius.circular(28),
    );
    canvas.drawRRect(rect, Paint()..color = _colour);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = WatotoColors.deep.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _ColourFieldPainter old) =>
      old.data.text != data.text;
}

// --------------------------------------------------------------- sentence

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({required this.data});

  final SceneData data;

  @override
  Widget build(BuildContext context) {
    final words = (data.text ?? '').split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(6)
        .toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: WatotoColors.deep,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in words)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    w,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
