/// The circuit builder: drag a battery, a wire and a bulb into the loop.
///
/// `build-circuit` is an authored action in the content (s10.science.lesson.01
/// opens with it) that had no stage of its own, so the planner fell through to
/// a two-option multiple choice — "A broken wire" / "A complete loop". That
/// asks a ten-year-old to *recall* the answer to the very thing the step exists
/// to let them *discover*. This makes the loop the thing they handle: nothing
/// lights until all three parts are in, and the gap step that follows reads as
/// a consequence rather than a new question.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';

/// The three parts, each with exactly one socket that will take it.
enum CircuitPart { battery, wire, bulb }

/// The draggable token for [part] in the tray. Named so tests can reach the
/// part itself rather than the caption printed under it.
Key circuitPartKey(CircuitPart part) => ValueKey('circuit-part-${part.name}');

/// The same part once it is sitting in the loop.
Key circuitSocketKey(CircuitPart part) =>
    ValueKey('circuit-socket-${part.name}');

/// Track geometry. The sockets straddle the track, so the board's inset is
/// half the difference between them — that is what lines a socket's centre up
/// with the centre of the wire it interrupts.
const double _trackWidth = 14;
const double _socketThickness = 46;
const double _boardInset = (_socketThickness - _trackWidth) / 2;

const Size _batterySize = Size(128, _socketThickness);
const Size _bulbSize = Size(96, _socketThickness);
const Size _wireSize = Size(_socketThickness, 104);

Size _sizeOf(CircuitPart part) => switch (part) {
      CircuitPart.battery => _batterySize,
      CircuitPart.wire => _wireSize,
      CircuitPart.bulb => _bulbSize,
    };

String _labelOf(AppLocalizations l10n, CircuitPart part) => switch (part) {
      CircuitPart.battery => l10n.circuitBattery,
      CircuitPart.wire => l10n.circuitWire,
      CircuitPart.bulb => l10n.circuitBulb,
    };

/// Unlit track: a slate that reads as metal against the warm page.
final Color _trackColor = Color.lerp(WatotoColors.deep, Colors.white, 0.28)!;
const Color _wireCore = Color(0xFFC8892F);

class CircuitBuildStage extends StatefulWidget {
  const CircuitBuildStage({
    super.key,
    required this.onCompleted,
    required this.onTapSound,
    this.gap = false,
  });

  final VoidCallback onCompleted;
  final VoidCallback onTapSound;

  /// Start from a lit loop and ask the child to break it, rather than from
  /// loose parts to join.
  final bool gap;

  @override
  State<CircuitBuildStage> createState() => CircuitBuildStageState();
}

class CircuitBuildStageState extends State<CircuitBuildStage> {
  late final Set<CircuitPart> _placed = widget.gap
      ? {...CircuitPart.values}
      : <CircuitPart>{};

  bool _finished = false;

  bool get _lit => _placed.length == CircuitPart.values.length;

  /// Built when the loop closes; broken when any part leaves it.
  bool get _solved => widget.gap ? !_lit : _lit;

  void _move(CircuitPart part, {required bool into}) {
    if (_placed.contains(part) == into) return;
    setState(() => into ? _placed.add(part) : _placed.remove(part));
    widget.onTapSound();
    if (!_solved || _finished) return;
    _finished = true;
    HapticFeedback.mediumImpact();
    // A beat so the bulb is seen to light (or go dark) before the player moves
    // on: that moment is the whole point of the step.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _board(context, l10n),
        const SizedBox(height: 20),
        _tray(context, l10n),
        if (_solved) ...[
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.gap ? l10n.circuitBroken : l10n.circuitComplete,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: widget.gap ? WatotoColors.sky : WatotoColors.mango,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _board(BuildContext context, AppLocalizations l10n) {
    final muted = WatotoColors.deep.withValues(alpha: 0.45);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(240.0, 340.0);
        return SizedBox(
          width: width,
          height: 300,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(_boardInset),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _lit ? WatotoColors.sun : _trackColor,
                        width: _trackWidth,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.circuitBoard.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Once the board is solved the instruction is telling
                      // the child to do a thing they have just done.
                      if (!_solved)
                        Text(
                          widget.gap
                              ? l10n.circuitGapHint
                              : l10n.circuitDropHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: _socket(l10n, CircuitPart.bulb),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _socket(l10n, CircuitPart.wire),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _socket(l10n, CircuitPart.battery),
              ),
            ],
          ),
        );
      },
    );
  }

  /// A gap in the track that will take exactly one part.
  ///
  /// It is filled with the page colour rather than left transparent so the
  /// track visibly *stops* here — an empty socket has to read as a break in
  /// the loop, which is the idea the whole lesson turns on.
  Widget _socket(AppLocalizations l10n, CircuitPart part) {
    final size = _sizeOf(part);
    final filled = _placed.contains(part);
    final glyph = _PartGlyph(part: part, lit: _lit);
    return DragTarget<CircuitPart>(
      onWillAcceptWithDetails: (details) => details.data == part && !filled,
      onAcceptWithDetails: (details) => _move(details.data, into: true),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: _SocketPainter(
              fill: Theme.of(context).scaffoldBackgroundColor,
              dash: filled
                  ? null
                  : WatotoColors.deep.withValues(alpha: hovering ? 0.55 : 0.25),
              radius: part == CircuitPart.wire ? 22 : 16,
            ),
            child: Center(
              child: filled
                  // A placed part can always come back out — that is what
                  // makes "open a gap" the same board run the other way.
                  ? Semantics(
                      button: true,
                      label: _labelOf(l10n, part),
                      child: Draggable<CircuitPart>(
                        data: part,
                        feedback:
                            Material(color: Colors.transparent, child: glyph),
                        childWhenDragging:
                            Opacity(opacity: 0.3, child: glyph),
                        child: GestureDetector(
                          key: circuitSocketKey(part),
                          onTap: () => _move(part, into: false),
                          child: ExcludeSemantics(child: glyph),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _tray(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: WatotoColors.deep.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.circuitPartsTray.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: WatotoColors.deep.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final part in CircuitPart.values)
                Flexible(child: _trayPart(l10n, part)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trayPart(AppLocalizations l10n, CircuitPart part) {
    final label = _labelOf(l10n, part);
    final placed = _placed.contains(part);
    // Every part is shown in the same footprint so the tray does not reflow as
    // parts leave it.
    const slot = Size(112, 104);
    final glyph = _PartGlyph(part: part, lit: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DragTarget<CircuitPart>(
            // The tray takes a part back out of the loop, which is how a gap
            // gets opened.
            onWillAcceptWithDetails: (d) => d.data == part && placed,
            onAcceptWithDetails: (d) => _move(d.data, into: false),
            builder: (context, candidate, rejected) => Container(
              width: slot.width,
              height: slot.height,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: placed && candidate.isEmpty ? 0.0 : 0.7,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: placed
                  ? const SizedBox.shrink()
                  : Semantics(
                      button: true,
                      label: label,
                      hint: l10n.circuitDropHint,
                      child: Draggable<CircuitPart>(
                        data: part,
                        feedback: Material(
                          color: Colors.transparent,
                          child: glyph,
                        ),
                        childWhenDragging:
                            Opacity(opacity: 0.3, child: glyph),
                        // Tapping places it too, so the step is doable
                        // without a drag — the bargain DragStage makes.
                        child: GestureDetector(
                          key: circuitPartKey(part),
                          onTap: () => _move(part, into: true),
                          child: ExcludeSemantics(child: glyph),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: WatotoColors.deep.withValues(alpha: placed ? 0.3 : 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuts the track and, while empty, outlines the gap with a dashed capsule.
class _SocketPainter extends CustomPainter {
  const _SocketPainter({
    required this.fill,
    required this.dash,
    required this.radius,
  });

  final Color fill;
  final Color? dash;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, Paint()..color = fill);
    if (dash == null) return;

    final stroke = Paint()
      ..color = dash!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(rect.deflate(1));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 7).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), stroke);
        distance = end + 6;
      }
    }
  }

  @override
  bool shouldRepaint(_SocketPainter old) =>
      old.fill != fill || old.dash != dash || old.radius != radius;
}

/// The drawn part itself — same widget in the tray and in the socket, so what
/// a child picks up is exactly what lands.
class _PartGlyph extends StatelessWidget {
  const _PartGlyph({required this.part, required this.lit});

  final CircuitPart part;
  final bool lit;

  @override
  Widget build(BuildContext context) => switch (part) {
        CircuitPart.battery => const _Battery(),
        CircuitPart.wire => const _Wire(),
        CircuitPart.bulb => _Bulb(lit: lit),
      };
}

/// Short stubs where a part meets the track, on both ends.
Widget _terminal({bool vertical = false}) => Container(
      width: vertical ? 20 : 12,
      height: vertical ? 12 : 20,
      decoration: BoxDecoration(
        color: _trackColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );

class _Battery extends StatelessWidget {
  const _Battery();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _batterySize.width,
      height: _batterySize.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _terminal(),
          Expanded(
            child: Container(
              height: _batterySize.height,
              decoration: BoxDecoration(
                color: _trackColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '+',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          width: 26,
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: WatotoColors.sun,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  const Text(
                    '−',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _terminal(),
        ],
      ),
    );
  }
}

class _Wire extends StatelessWidget {
  const _Wire();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _wireSize.width,
      height: _wireSize.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _terminal(vertical: true),
          Expanded(
            child: Container(
              width: 11,
              decoration: BoxDecoration(
                color: _wireCore,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          _terminal(vertical: true),
        ],
      ),
    );
  }
}

class _Bulb extends StatelessWidget {
  const _Bulb({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _bulbSize.width,
      height: _bulbSize.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _terminal(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit ? WatotoColors.sun : Colors.transparent,
              border: Border.all(color: _trackColor, width: 3),
              boxShadow: [
                if (lit)
                  BoxShadow(
                    color: WatotoColors.sun.withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
              ],
            ),
            child: CustomPaint(
              painter: _FilamentPainter(
                color: lit ? WatotoColors.deep : _trackColor,
              ),
            ),
          ),
          _terminal(),
        ],
      ),
    );
  }
}

/// The little U of filament inside the bulb.
class _FilamentPainter extends CustomPainter {
  const _FilamentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.32, h * 0.28)
      ..lineTo(w * 0.32, h * 0.55)
      ..arcToPoint(
        Offset(w * 0.68, h * 0.55),
        radius: Radius.circular(w * 0.18),
        clockwise: false,
      )
      ..lineTo(w * 0.68, h * 0.28);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FilamentPainter old) => old.color != color;
}
