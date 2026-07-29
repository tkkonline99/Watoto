import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'savanna_background.dart';

/// Standalone welcome/landing screen (route `/welcome`): the same language
/// screen shown after signing out. Picking a language and tapping "Let's go"
/// re-enters the app at the home.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      LanguageSelectScreen(onStart: () => context.go('/'));
}

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

const _flagChipBg = Color(0xFFF3E9CF);

class _LanguageSelectScreenState extends ConsumerState<LanguageSelectScreen>
    with TickerProviderStateMixin {
  // Drives the mascot's idle bob. Gated below so it doesn't run in tests /
  // reduce-motion (a perpetual repeat() would hang pumpAndSettle).
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  // Plays once on open: slides each element up into place (transform only).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  int _sparkTick = 0;

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

    return SavannaScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 36).clamp(0, double.infinity),
            ),
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
                      _LetsGoButton(label: _letsGo[lang]!, onTap: widget.onStart),
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
    // Read as-is, this card announces an animal emoji, a country code and a
    // decorative check before the language name. State (chosen or not) was not
    // conveyed at all — the only cue was a green fill.
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '${lang.name}. ${lang.greeting}',
      child: ExcludeSemantics(child: _card()),
    );
  }

  Widget _card() {
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
              for (var i = 0; i < _emoji.length; i++) _sparkle(_emoji[i], i, v),
            ],
          ),
        );
      },
    );
  }

  Widget _sparkle(String emoji, int i, double v) {
    final angle = -math.pi / 2 + (i - 2) * 0.5;
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
    // The label carries a rocket emoji; strip it so the button is announced as
    // an action rather than "Let's go rocket".
    return Semantics(
      button: true,
      label: label.replaceAll(RegExp(r'[^\p{L}\p{N}\s!?.,\x27-]', unicode: true), '')
          .trim(),
      child: ExcludeSemantics(child: _pill()),
    );
  }

  Widget _pill() {
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
