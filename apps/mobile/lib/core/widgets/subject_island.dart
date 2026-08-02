import 'package:flutter/material.dart';

import '../theme/watoto_theme.dart';

/// Home-screen subject entry: colour tile, emoji, label, optional progress.
class SubjectIsland extends StatelessWidget {
  const SubjectIsland({
    super.key,
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
    this.progress,
    this.locked = false,
    this.semanticsHint,
  });

  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;
  final double? progress; // 0–1
  final bool locked;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: semanticsHint,
      enabled: !locked,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: locked ? color.withValues(alpha: 0.45) : color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: WatotoColors.deep.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // The tile's spoken name is the Semantics label above, plus the
            // hint. Everything below it is how the tile *looks* — the emoji,
            // the padlock, the label repeated as visible text — and a reader
            // that walks into it announces "Maths, lion face, locked, Maths".
            // Excluded here rather than on the Semantics above so the InkWell
            // keeps its own tap action for the reader to activate.
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (progress != null)
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              value: progress!.clamp(0.0, 1.0),
                              strokeWidth: 4,
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                            ),
                          ),
                        Text(emoji, style: const TextStyle(fontSize: 36)),
                        if (locked)
                          const Positioned(
                            right: 0,
                            top: 0,
                            child: Text('🔒', style: TextStyle(fontSize: 16)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Baloo2',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
