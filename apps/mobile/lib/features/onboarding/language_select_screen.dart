import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';

/// First impression for children (many pre-readers): a bright savanna scene
/// where a lion mascot asks the child to pick the language it should speak.
/// This is step 0 of onboarding ([OnboardingScreen]); tapping "Let's go"
/// calls [onStart] to advance to the grown-up gate.
///
/// Motion rule (see redesign brief): every entrance animation moves
/// *transform only* and never holds content at opacity 0, so the whole scene
/// stays visible even when the animation clock is frozen (first paint, exports,
/// screenshots).
class LanguageSelectScreen extends ConsumerStatefulWidget {
  const LanguageSelectScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  ConsumerState<LanguageSelectScreen> createState() =>
      _LanguageSelectScreenState();
}

/// A selectable language: the disc colour + animal that greets in it, the
/// native greeting, and a flag code. Flag *codes* (not 🇬🇧 emoji) are used on
/// purpose — country-flag emoji don't render on Windows/desktop Flutter.
class _Lang {
  const _Lang(this.code, this.name, this.greeting, this.animal, this.flag,
      this.color);
  final String code;
  final String name;
  final String greeting;
  final String animal;
  final String flag;
  final Color color;
}

const _languages = <_Lang>[
  _Lang('en', 'English', 'Hello!', '🦁', 'GB', WatotoColors.sky),
  _Lang('sw', 'Kiswahili', 'Habari!', '🐘', 'KE', WatotoColors.leaf),
  _Lang('fr', 'Français', 'Bonjour!', '🦒', 'FR', WatotoColors.berry),
];

/// The mascot's speech bubble, spoken in the language currently selected so the
/// child gets immediate "it understood me" feedback when they tap a card.
const _bubblePrompt = <String, String>{
  'en': 'Tap one so I know how to talk to you! 💬',
  'sw': 'Gusa moja nijue lugha ya kukuongelesha! 💬',
  'fr': 'Touche-en une pour que je sache te parler ! 💬',
};

const _letsGo = <String, String>{
  'en': "Let's go!",
  'sw': 'Twende!',
  'fr': "C'est parti !",
};

// Savanna scene colours, kept local to this screen.
const _bgTop = Color(0xFFFFF7E6);
const _bgBottom = Color(0xFFFFE0A0);
const _groundBack = Color(0xFFC2DD9C);
const _groundFront = Color(0xFFA7CE7C);
const _flagChipBg = Color(0xFFF3E9CF);

class _LanguageSelectScreenState extends ConsumerState<LanguageSelectScreen>
    with TickerProviderStateMixin {
  // One always-running clock drives all the ambient drift (mascot bob, clouds,
  // butterfly, bird) via phase-shifted sine waves — cheap and only one ticker.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  // Plays once on open: slides each element up into place (transform only).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  // Bumped on every selection so the sparkle burst replays.
  int _sparkTick = 0;

  @override
  void dispose() {
    _ambient.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _select(String code) {
    if (ref.read(localeProvider).languageCode == code) return;
    ref.read(localeProvider.notifier).set(Locale(code));
    setState(() => _sparkTick++);
  }

  /// Slides [child] up into place along a staggered window of the intro clock.
  /// Frozen at t=0 the child sits a little low but is fully opaque — never hidden.
  Widget _enter(double begin, double end, Widget child) {
    final curved = CurvedAnimation(
      parent: _intro,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, c) =>
          Transform.translate(offset: Offset(0, (1 - curved.value) * 24), child: c),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;

    return Scaffold(
      body: Stack(
        children: [
          // Radial cream -> gold sky filling the screen.
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
          // Sparse, gently drifting ambient decor behind the content.
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) => _SavannaDecor(t: _ambient.value),
          ),
          // Brand wordmark, top-left.
          const Positioned(top: 14, left: 18, child: SafeArea(child: _Wordmark())),
          // Foreground: mascot, prompt, cards, button — centred and scrollable.
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 84),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _enter(0.0, 0.5, _Mascot(t: _ambient)),
                          const SizedBox(height: 14),
                          _enter(0.1, 0.6, _SpeechBubble(text: _bubblePrompt[lang]!)),
                          const SizedBox(height: 22),
                          _enter(
                            0.15,
                            0.65,
                            Text(
                              l10n.chooseLanguage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Baloo2',
                                fontSize: 30,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                color: WatotoColors.deep,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          for (var i = 0; i < _languages.length; i++) ...[
                            _enter(
                              0.25 + i * 0.08,
                              0.75 + i * 0.08,
                              _LanguageCard(
                                lang: _languages[i],
                                selected: _languages[i].code == lang,
                                sparkTick: _sparkTick,
                                onTap: () => _select(_languages[i].code),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          const SizedBox(height: 12),
                          _enter(
                            0.55,
                            1.0,
                            _LetsGoButton(
                              label: _letsGo[lang]!,
                              onTap: widget.onStart,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

/// The lion star: enlarged, sitting on a soft glow, doing a gentle idle bob.
class _Mascot extends StatelessWidget {
  const _Mascot({required this.t});
  final Animation<double> t;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) {
        final dy = math.sin(t.value * 2 * math.pi * 2) * 5;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Container(
        width: 116,
        height: 116,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.55),
          boxShadow: [
            BoxShadow(
              color: WatotoColors.sun.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Text('🦁', style: TextStyle(fontSize: 64)),
      ),
    );
  }
}

/// White rounded speech bubble with a little downward tail.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: WatotoColors.deep.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WatotoColors.deep,
            ),
          ),
        ),
        CustomPaint(size: const Size(20, 10), painter: _TailPainter()),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One big, child-friendly language card. Selecting it lifts the card, fills
/// the check green, and bursts sparkles from the check.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.lang,
    required this.selected,
    required this.sparkTick,
    required this.onTap,
  });

  final _Lang lang;
  final bool selected;
  final int sparkTick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? lang.color : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? lang.color : WatotoColors.deep)
                    .withValues(alpha: selected ? 0.28 : 0.10),
                blurRadius: selected ? 20 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Animal disc.
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lang.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(lang.animal, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              // Name + native greeting.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.name,
                      style: const TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: WatotoColors.deep,
                      ),
                    ),
                    Text(
                      lang.greeting,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: lang.color,
                      ),
                    ),
                  ],
                ),
              ),
              // Flag code chip.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _flagChipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lang.flag,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.deep,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Check indicator with sparkle burst on selection.
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (selected) _SparkleBurst(tick: sparkTick),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? WatotoColors.leaf : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? WatotoColors.leaf
                            : WatotoColors.deep.withValues(alpha: 0.25),
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 20, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short, replayable ⭐✨🌟 burst centred on the selected card's check.
class _SparkleBurst extends StatelessWidget {
  const _SparkleBurst({required this.tick});
  final int tick;

  static const _emoji = ['⭐', '✨', '🌟', '✨', '⭐'];

  @override
  Widget build(BuildContext context) {
    // A fresh key on every selection restarts the one-shot tween.
    return TweenAnimationBuilder<double>(
      key: ValueKey(tick),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, v, _) {
        return SizedBox(
          width: 1,
          height: 1,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < _emoji.length; i++)
                _sparkle(_emoji[i], i, v),
            ],
          ),
        );
      },
    );
  }

  Widget _sparkle(String emoji, int i, double v) {
    final angle = -math.pi / 2 + (i - 2) * 0.5; // fan upward
    final dist = 30 * v;
    return Transform.translate(
      offset: Offset(math.cos(angle) * dist, math.sin(angle) * dist),
      child: Opacity(
        opacity: (1 - v).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.5 + v,
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

/// Bouncy "Let's go! 🚀" pill — scales down on press, up on hover.
class _LetsGoButton extends StatelessWidget {
  const _LetsGoButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      hoverScale: 1.04,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [WatotoColors.sun, WatotoColors.mango],
          ),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: WatotoColors.mango.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          '$label 🚀',
          style: const TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: WatotoColors.deep,
          ),
        ),
      ),
    );
  }
}

/// Wraps a child with press (scale down) and hover (scale up) feedback.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    this.hoverScale = 1.02,
  });

  final Widget child;
  final VoidCallback onTap;
  final double hoverScale;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.96 : (_hovered ? widget.hoverScale : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Sun, drifting clouds, a grassy ground, a tree, a butterfly and a bird.
/// All movement is sine-driven off the shared ambient clock [t] (0..1).
class _SavannaDecor extends StatelessWidget {
  const _SavannaDecor({required this.t});
  final double t;

  double _wave(double phase, double amp) =>
      math.sin((t + phase) * 2 * math.pi) * amp;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Sun, tucked into the top-right corner with a warm glow.
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
        // Two clouds drifting slowly left/right.
        Positioned(
          top: 70,
          left: 24 + _wave(0.0, 12),
          child: const _Cloud(width: 92),
        ),
        Positioned(
          top: 130,
          right: 30 + _wave(0.5, 14),
          child: const _Cloud(width: 64),
        ),
        // Grassy ground.
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SizedBox(height: 200, child: _Ground()),
        ),
        // Tree on the ground, bottom-left.
        Positioned(
          bottom: 18,
          left: 12,
          child: Text('🌳', style: TextStyle(fontSize: 72 + _wave(0.2, 1.5))),
        ),
        // Butterfly floating mid-left.
        Positioned(
          top: 150 + _wave(0.1, 10),
          left: 26 + _wave(0.35, 8),
          child: Transform.rotate(
            angle: _wave(0.0, 0.15),
            child: const Text('🦋', style: TextStyle(fontSize: 30)),
          ),
        ),
        // Bird hopping along the ground, bottom-right.
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

/// Two overlapping gentle hills of grass at the bottom of the scene.
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

    // Back hill (lighter), crest a bit higher.
    final back = Paint()..color = _groundBack;
    final backPath = Path()
      ..moveTo(0, h * 0.45)
      ..quadraticBezierTo(w * 0.5, h * 0.18, w, h * 0.42)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(backPath, back);

    // Front hill (deeper green).
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
