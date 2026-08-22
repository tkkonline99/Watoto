/// Renders a declared [Visual] into the stage of the question skeleton
/// (docs/26 §26.3).
///
/// Three modes, one fallback. The fallback matters as much as the modes: for
/// content authored before the visual contract, and for any part whose mode
/// this build does not understand, the old `step_visuals.dart` ladder still
/// produces a glyph — so a stage is never empty, which §26.3 forbids.
///
/// A `slot` whose file is not bundled is the *normal* case, not an error:
/// 1,573 parts carry a brief for art nobody has drawn. Those render as the
/// striped placeholder carrying the brief text, so an unfinished asset looks
/// unfinished instead of silently resolving to something wrong. That is the
/// whole reason the mode exists.
library;

import 'package:flutter/material.dart';

import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/stages/stage_scenes.dart';
import 'content_lexicon.dart';
import 'library_models.dart';
import 'option_photos.dart';

class VisualStage extends StatelessWidget {
  const VisualStage({
    super.key,
    required this.visual,
    required this.fallbackEmoji,
    this.data = const SceneData(),
  });

  final Visual? visual;

  /// What the step_visuals ladder produced — used when nothing was declared.
  final String fallbackEmoji;

  /// Numbers and text a scene needs to draw itself.
  final SceneData data;

  @override
  Widget build(BuildContext context) => switch (visual) {
        // A photographed word shows its photograph here too. `dog` is a token
        // visual on 28 parts, so without this a lesson would put a real dog in
        // the answers and 🐶 on the stage above them — the same animal, twice,
        // in two registers.
        TokenVisual(:final ref) => _TokenDisc(
            glyph: tokenGlyph(ref) ?? fallbackEmoji,
            photoAsset: optionPhotoAsset(ref),
          ),
        SceneVisual(:final ref) =>
          buildScene(ref, data: data) ?? _TokenDisc(glyph: fallbackEmoji),
        SlotVisual(:final assetPath, :final alt) =>
          _Slot(path: assetPath, brief: alt),
        _ => _TokenDisc(glyph: fallbackEmoji),
      };
}

/// A vetted glyph on a tinted disc, 150dp (§26.3) — or the word's photograph,
/// where one is bundled. The glyph remains the fallback, so the stage still
/// cannot be empty.
class _TokenDisc extends StatelessWidget {
  const _TokenDisc({required this.glyph, this.photoAsset});

  final String glyph;
  final String? photoAsset;

  @override
  Widget build(BuildContext context) {
    final glyphChild = Text(glyph, style: const TextStyle(fontSize: 86));
    return Container(
      width: 150,
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: WatotoColors.sun.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: photoAsset == null
          ? glyphChild
          : Image.asset(
              photoAsset!,
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => glyphChild,
            ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.path, required this.brief});

  final String path;
  final String brief;

  @override
  Widget build(BuildContext context) => Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => StripedPlaceholder(brief: brief),
      );
}

/// The framed brief for art that has not been drawn yet.
///
/// Deliberately plain and deliberately visible. It carries the brief so the
/// screen is still usable — the alt text describes what the picture would show
/// — and so anyone looking at the app can see exactly what is outstanding.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({super.key, required this.brief});

  final String brief;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _StripePainter(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Text(
            brief,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: WatotoColors.deep.withValues(alpha: 0.75),
            ),
          ),
        ),
      );
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = WatotoColors.cloud,
    );
    final stripe = Paint()
      ..color = WatotoColors.sun.withValues(alpha: 0.16)
      ..strokeWidth = 12;
    for (var x = -size.height; x < size.width; x += 26) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
