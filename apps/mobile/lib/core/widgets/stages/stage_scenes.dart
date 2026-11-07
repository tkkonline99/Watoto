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
  'arithmetic.number-sentence',
  'fraction.bars',
  'shape.loose-objects',
  'glyph.trace',
  'audio.waveform',
  'colour.field',
  'sentence.card',
};

/// The widget for [ref], or null when nothing is registered under that id —
/// or when a registered scene cannot honestly draw *this* part. The second
/// case is why the return stays nullable: `arithmetic.number-sentence` reads
/// its numbers out of the part's own text, and a scene that guessed when the
/// text held no sum would state something false. Both nulls land on the same
/// `?? _TokenDisc(...)` in VisualStage, so the stage is still never empty.
Widget? buildScene(String ref, {SceneData data = const SceneData()}) =>
    switch (ref) {
      'counting.array' => _Scene(painter: _CountingArrayPainter(data)),
      'counting.tens-and-units' => _Scene(painter: _TensAndUnitsPainter(data)),
      'arithmetic.number-sentence' => _numberSentence(data),
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

  int get _value {
    if (data.count != null) return data.count!;
    final t = data.text;
    if (t != null) {
      final m = RegExp(r'\b([1-9]\d)\b').firstMatch(t);
      if (m != null) return int.parse(m.group(1)!);
    }
    return 34;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final value = _value;
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
      old.data.count != data.count || old.data.text != data.text;
}

/// The first `a + b` or `a − b` in [text], when both operands fit base-ten
/// blocks.
///
/// Two digits is the ceiling because a third rank stops being countable at
/// stage size, and `×`/`÷` are deliberately not read: an array says those,
/// and `math.multiplication-division` already proposes `counting.array`.
///
/// The `/` guards keep fractions out. Without them "1/2 + 1/4" reads as
/// "2 + 1" and the stage would draw two blocks beside one for a question
/// about quarters.
({int a, String op, int b})? _sumInText(String? text) {
  if (text == null) return null;
  final m = RegExp(r'(?<![\d/])(\d{1,2})\s*([+\-−])\s*(\d{1,2})(?![\d/])')
      .firstMatch(text);
  if (m == null) return null;
  return (
    a: int.parse(m.group(1)!),
    op: m.group(2)! == '+' ? '+' : '−',
    b: int.parse(m.group(3)!),
  );
}

Widget? _numberSentence(SceneData data) {
  final sum = _sumInText(data.text);
  if (sum == null) return null;
  return _NumberSentence(a: sum.a, op: sum.op, b: sum.b);
}

/// A number sentence drawn as quantity: each operand in tens rods and unit
/// squares, with the operator between them.
///
/// It draws the *problem* and never the result — finding that is what the
/// child is being asked to do. This is also why the operands are read out of
/// the part's own text instead of [SceneData.count]: on a quiz `count` is
/// derived from the correct answer, so drawing it would hand the answer over.
class _NumberSentence extends StatelessWidget {
  const _NumberSentence({required this.a, required this.op, required this.b});

  final int a;
  final String op;
  final int b;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, box) {
            // One rod width for both operands, worked out here rather than
            // inside each painter. Sized apart, "63 − 28" drew a wider ten on
            // the small side than on the big one, and a rod that changes size
            // between the two halves of a sum stops reading as ten.
            const opW = 44.0;
            final blocks = math.max(box.maxHeight - 30, 24.0);
            final rodW = math.min(
              (box.maxWidth - opW) / (_slotsFor(a) + _slotsFor(b) + 1.2),
              blocks * 0.2,
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Operand(value: a, rodW: rodW),
                SizedBox(
                  width: opW,
                  child: Center(
                    child: Text(
                      op,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: WatotoColors.deep,
                      ),
                    ),
                  ),
                ),
                _Operand(value: b, rodW: rodW),
              ],
            );
          },
        ),
      );
}

/// How wide [v] is in rod-widths: a rod and its gap each, plus the two-column
/// stack the loose units sit in. Mirrors the geometry [_BaseTenPainter] draws.
double _slotsFor(int v) => (v ~/ 10) * 1.55 + (v % 10 > 0 ? 2.13 : 0);

/// One operand: its blocks, and its numeral underneath.
///
/// The numeral is here so the symbol and the quantity are learned against each
/// other, and so the scene still says something exact to a child who cannot
/// yet count six rods at a glance.
class _Operand extends StatelessWidget {
  const _Operand({required this.value, required this.rodW});

  final int value;
  final double rodW;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _slotsFor(value) * rodW,
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: _BaseTenPainter(value, rodW),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: WatotoColors.deep,
              ),
            ),
          ],
        ),
      );
}

/// [value] as tens rods and unit squares, centred in the space it is given.
///
/// Proportions and notching follow [_TensAndUnitsPainter] so a child meets the
/// same rod in both scenes.
class _BaseTenPainter extends CustomPainter {
  _BaseTenPainter(this.value, this.rodW);

  final int value;

  /// Handed down by [_NumberSentence] so both operands share one scale.
  final double rodW;

  @override
  void paint(Canvas canvas, Size size) {
    final tens = (value ~/ 10).clamp(0, 9);
    final units = value % 10;

    final slots = tens * 1.55 + (units > 0 ? 2.13 : 0);
    if (slots <= 0) return;
    final gap = rodW * 0.55;
    final unitS = rodW * 0.82;
    final rodH = size.height * 0.84;
    final baseY = size.height;

    var x = (size.width - slots * rodW) / 2;

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
      // Ten notches, so the rod reads as ten and not as a colour (§26.6).
      for (var n = 1; n < 10; n++) {
        final y = baseY - rodH * n / 10;
        canvas.drawLine(Offset(x, y), Offset(x + rodW, y), edge);
      }
      x += rodW + gap;
    }
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
  bool shouldRepaint(covariant _BaseTenPainter old) =>
      old.value != value || old.rodW != rodW;
}

// -------------------------------------------------------------- fractions

class _FractionBarsPainter extends CustomPainter {
  _FractionBarsPainter(this.data);

  final SceneData data;

  List<({int num, int den})> get _fractions {
    final t = (data.text ?? '').toLowerCase();
    final out = <({int num, int den})>[];
    for (final m in RegExp(r'(\d)\s*/\s*(\d{1,2})').allMatches(t)) {
      final n = int.parse(m.group(1)!);
      final d = int.parse(m.group(2)!);
      if (d >= 2 && d <= 10 && n >= 1 && n <= d) {
        out.add((num: n, den: d));
      }
    }
    if (out.isEmpty) {
      if (t.contains('three quarter') || t.contains('three fourth')) {
        out.add((num: 3, den: 4));
      } else if (t.contains('quarter') || t.contains('fourth')) {
        out.add((num: 1, den: 4));
      }
      if (t.contains('two third')) {
        out.add((num: 2, den: 3));
      } else if (t.contains('third')) {
        out.add((num: 1, den: 3));
      }
      if (t.contains('half') || t.contains('halves')) {
        out.add((num: 1, den: 2));
      }
      if (t.contains('tenth')) {
        out.add((num: 1, den: 10));
      }
    }
    if (out.length >= 2) return out.take(2).toList();
    if (out.length == 1) {
      final first = out.first;
      final second = first.den == 2 ? (num: 1, den: 4) : (num: 1, den: 2);
      return [first, second];
    }
    return const [(num: 1, den: 2), (num: 1, den: 4)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Two bars of the same whole cut differently, so the comparison is visible
    // as length. §26.6: never hue alone.
    final bars = _fractions;
    final barH = size.height * 0.2;
    final barW = size.width * 0.82;
    final left = (size.width - barW) / 2;

    final edge = Paint()
      ..color = WatotoColors.deep.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (var b = 0; b < bars.length; b++) {
      final top = size.height * (b == 0 ? 0.22 : 0.56);
      final parts = bars[b].den;
      final shadedCount = bars[b].num;
      final partW = barW / parts;
      for (var i = 0; i < parts; i++) {
        final rect = Rect.fromLTWH(left + i * partW, top, partW, barH);
        final shaded = i < shadedCount;
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
  bool shouldRepaint(covariant _FractionBarsPainter old) =>
      old.data.text != data.text;
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
    // A stroke with start and end markers: a dotted guide the child follows.
    // Adapts to straight lines, circles, zigzags, wiggly paths, or curves
    // named in the prompt. Tracing is never scored and never timed (§26.4).
    final w = size.width, h = size.height;
    final t = (data.text ?? '').toLowerCase();
    final path = Path();
    late final Offset startPt;
    late final Offset endPt;

    if (t.contains('zigzag') || t.contains('mountain')) {
      startPt = Offset(w * 0.16, h * 0.72);
      endPt = Offset(w * 0.84, h * 0.24);
      path
        ..moveTo(startPt.dx, startPt.dy)
        ..lineTo(w * 0.38, h * 0.24)
        ..lineTo(w * 0.62, h * 0.72)
        ..lineTo(endPt.dx, endPt.dy);
    } else if (t.contains('circle') || t.contains('round')) {
      final r = math.min(w, h) * 0.3;
      final center = Offset(w * 0.5, h * 0.5);
      startPt = Offset(center.dx, center.dy - r);
      endPt = Offset(center.dx - 4, center.dy - r);
      path.addOval(Rect.fromCircle(center: center, radius: r));
    } else if (t.contains('straight') ||
        t.contains('road') ||
        t.contains('edge')) {
      startPt = Offset(w * 0.18, h * 0.5);
      endPt = Offset(w * 0.82, h * 0.5);
      path
        ..moveTo(startPt.dx, startPt.dy)
        ..lineTo(endPt.dx, endPt.dy);
    } else if (t.contains('wiggly') || t.contains('dotted path')) {
      startPt = Offset(w * 0.16, h * 0.55);
      endPt = Offset(w * 0.84, h * 0.45);
      path
        ..moveTo(startPt.dx, startPt.dy)
        ..cubicTo(
          w * 0.36,
          h * 0.12,
          w * 0.64,
          h * 0.88,
          endPt.dx,
          endPt.dy,
        );
    } else {
      startPt = Offset(w * 0.22, h * 0.74);
      endPt = Offset(w * 0.78, h * 0.74);
      path
        ..moveTo(startPt.dx, startPt.dy)
        ..cubicTo(w * 0.34, h * 0.16, w * 0.66, h * 0.16, endPt.dx, endPt.dy);
    }

    final guide = Paint()
      ..color = WatotoColors.sky.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeJoin = StrokeJoin.round
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

    canvas.drawCircle(startPt, 11, Paint()..color = WatotoColors.leaf);
    canvas.drawCircle(endPt, 11, Paint()..color = WatotoColors.berry);
  }

  @override
  bool shouldRepaint(covariant _GlyphTracePainter old) =>
      old.data.text != data.text;
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
    if (t.contains('purple')) return const Color(0xFF9B6ADE);
    if (t.contains('pink')) return const Color(0xFFFF8FAB);
    if (t.contains('brown')) return const Color(0xFFA66E48);
    if (t.contains('black')) return WatotoColors.deep;
    if (t.contains('white')) return Colors.white;
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
