import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';

class _StrokePoint {
  const _StrokePoint(this.offset, this.color, this.width);
  final Offset offset;
  final Color color;
  final double width;
}

/// Creative finger-painting & letter/number stencil blackboard modal sheet
/// ("Savanna Sketchpad").
class SavannaSketchpadSheet extends ConsumerStatefulWidget {
  const SavannaSketchpadSheet({super.key});

  @override
  ConsumerState<SavannaSketchpadSheet> createState() =>
      _SavannaSketchpadSheetState();
}

class _SavannaSketchpadSheetState extends ConsumerState<SavannaSketchpadSheet> {
  static const List<Color> _palette = <Color>[
    Color(0xFFD8572A), // Savanna terracotta
    Color(0xFFF4A236), // Marigold gold
    Color(0xFF1F7A6B), // Oasis teal
    Color(0xFF3E6B48), // Baobab green
    Color(0xFF6B4E9B), // Twilight violet
  ];

  static const List<String> _stencils = <String>[
    '', // Free draw
    'A',
    'E',
    'S',
    '1',
    '2',
    '3',
    '★',
    '♥',
  ];

  final List<List<_StrokePoint>> _strokes = <List<_StrokePoint>>[];
  Color _selectedColor = _palette.first;
  int _stencilIndex = 0;
  bool _celebrated = false;

  void _startStroke(Offset localPosition) {
    setState(() {
      _celebrated = false;
      _strokes.add(<_StrokePoint>[
        _StrokePoint(localPosition, _selectedColor, 7.0),
      ]);
    });
  }

  void _appendStroke(Offset localPosition) {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.last.add(_StrokePoint(localPosition, _selectedColor, 7.0));
    });
  }

  void _clearCanvas() {
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _strokes.clear();
      _celebrated = false;
    });
  }

  void _cycleStencil() {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _stencilIndex = (_stencilIndex + 1) % _stencils.length;
    });
  }

  Future<void> _celebrateArtwork() async {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _celebrated = true);
    await ref.read(soundEffectsProvider).celebrate();
    final locale = ref.read(localeProvider).languageCode;
    final line = switch (locale) {
      'sw' => 'Mchoro mzuri sana! Kibo anapenda rangi zako!',
      'fr' => 'Quel beau dessin ! Kibo adore tes couleurs !',
      _ => 'What a wonderful drawing! Kibo loves your colors!',
    };
    await ref.read(narrationProvider.notifier).speak(
          line,
          locale,
          style: SpeakStyle.cheer,
        );
  }

  @override
  Widget build(BuildContext context) {
    final stencil = _stencils[_stencilIndex];
    return SafeArea(
      child: Padding(
        key: const ValueKey('savanna-sketchpad-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('🎨', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Savanna Sketchpad',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('sketch-stencil-next'),
                  onPressed: _cycleStencil,
                  icon: const Icon(Icons.abc_rounded, size: 20),
                  label: Text(
                    stencil.isEmpty ? 'Stencil: Free' : 'Stencil: $stencil',
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _palette.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: InkWell(
                      key: ValueKey('sketch-color-$i'),
                      customBorder: const CircleBorder(),
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        setState(() => _selectedColor = _palette[i]);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: _selectedColor == _palette[i] ? 36 : 28,
                        height: _selectedColor == _palette[i] ? 36 : 28,
                        decoration: BoxDecoration(
                          color: _palette[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == _palette[i]
                                ? WatotoColors.deep
                                : Colors.white,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: GestureDetector(
                  key: const ValueKey('sketchpad-canvas'),
                  onPanStart: (d) => _startStroke(d.localPosition),
                  onPanUpdate: (d) => _appendStroke(d.localPosition),
                  child: CustomPaint(
                    foregroundPainter: _SketchpadPainter(
                      strokes: _strokes,
                      stencil: stencil,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDF7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: WatotoColors.mango.withValues(alpha: 0.45),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.all(10),
                      child: _celebrated
                          ? const Text(
                              '🌟 Masterpiece! 🌟',
                              key: ValueKey('sketchpad-masterpiece-badge'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: WatotoColors.mango,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('sketchpad-clear'),
                  onPressed: _clearCanvas,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const ValueKey('sketchpad-celebrate'),
                  onPressed: _celebrateArtwork,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Show Kibo! 🎉'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SketchpadPainter extends CustomPainter {
  _SketchpadPainter({
    required this.strokes,
    required this.stencil,
  });

  final List<List<_StrokePoint>> strokes;
  final String stencil;

  @override
  void paint(Canvas canvas, Size size) {
    if (stencil.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: stencil,
          style: TextStyle(
            fontSize: size.height * 0.68,
            fontWeight: FontWeight.w900,
            color: WatotoColors.deep.withValues(alpha: 0.11),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (size.width - tp.width) / 2,
          (size.height - tp.height) / 2,
        ),
      );
    }

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.first.color
        ..strokeWidth = stroke.first.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first.offset,
          stroke.first.width / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path()
          ..moveTo(stroke.first.offset.dx, stroke.first.offset.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].offset.dx, stroke[i].offset.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchpadPainter oldDelegate) => true;
}

Future<void> showSavannaSketchpad(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WatotoColors.cloud,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const SavannaSketchpadSheet(),
  );
}
