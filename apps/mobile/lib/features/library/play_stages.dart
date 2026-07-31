/// The interactive stages a lesson step can be played as.
///
/// One widget per [StepMechanic]: tap, count, drag, choose, type a number,
/// build an array, or read an explanation. Each is a leaf — it takes a plan and
/// some callbacks and knows nothing about lessons, progress or XP — which is
/// what lets the lesson player stay a dispatcher rather than a 3,000-line file.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'content_lexicon.dart';
import 'play_stage_code.dart';
import 'step_motion.dart';
import 'step_play.dart';

class DivisionWorkspace extends StatelessWidget {
  const DivisionWorkspace({
    required this.workspace,
    this.filledDigit,
  });

  final MathWorkspace workspace;
  final int? filledDigit;

  @override
  Widget build(BuildContext context) {
    final divStr = '${workspace.dividend}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WatotoColors.deep.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quotient line
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 36),
              ...List.generate(divStr.length, (i) {
                final show = filledDigit != null && i == 0;
                return Container(
                  width: 28,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: WatotoColors.deep.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    show ? '$filledDigit' : '',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: WatotoColors.mango,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${workspace.divisor}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: WatotoColors.deep, width: 3),
                    top: BorderSide(color: WatotoColors.deep, width: 3),
                  ),
                ),
                child: Text(
                  divStr,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: WatotoColors.deep,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Routes a [StepPlayPlan] to the matching fun mechanic.
class SmartInteractionStage extends StatelessWidget {
  const SmartInteractionStage({
    super.key,
    this.prompt,
    required this.plan,
    required this.emoji,
    required this.onCompleted,
    required this.onTapSound,
    required this.onWrong,
    required this.done,
    this.choice,
  });

  final StepPlayPlan plan;

  /// The localized instruction for this step, already resolved by the view.
  /// The plan's own hint is English — using it here would put an English line
  /// under a Swahili caption.
  final String? prompt;
  final String emoji;
  final void Function({int? answer}) onCompleted;
  final VoidCallback onTapSound;
  final VoidCallback onWrong;
  final bool done;
  final ChoicePlan? choice;

  @override
  Widget build(BuildContext context) {
    if (choice != null) {
      return ChoiceStage(
        plan: choice!,
        onCompleted: () => onCompleted(),
      );
    }
    return switch (plan.mechanic) {
      StepMechanic.numberAnswer => NumberAnswerStage(
          plan: plan,
          done: done,
          onCorrect: (n) => onCompleted(answer: n),
          onWrong: onWrong,
        ),
      StepMechanic.buildArray => ArrayBuildStage(
          rows: plan.rows,
          cols: plan.cols,
          onCompleted: () => onCompleted(answer: plan.answer),
        ),
      StepMechanic.codeRun => KidCodeStage(
          plan: plan,
          onCompleted: () => onCompleted(),
          onTapSound: onTapSound,
        ),
      StepMechanic.explain => ExplainStage(
          emoji: emoji,
          prompt: prompt,
          onCompleted: () => onCompleted(),
        ),
      StepMechanic.celebrate => TapStage(
          emoji: emoji,
          prompt: prompt,
          onCompleted: () => onCompleted(),
        ),
      StepMechanic.count => CountStage(
          emoji: emoji,
          prompt: prompt,
          count: plan.count,
          onCompleted: () => onCompleted(),
          onTapSound: onTapSound,
        ),
      StepMechanic.drag => DragStage(
          emoji: emoji,
          prompt: prompt,
          onCompleted: () => onCompleted(),
        ),
      StepMechanic.tap || StepMechanic.multiChoice => TapStage(
          emoji: emoji,
          prompt: prompt,
          onCompleted: () => onCompleted(),
        ),
    };
  }
}

/// Big digit buttons or a mini pad — never a dead "write it" prompt.
class NumberAnswerStage extends StatefulWidget {
  const NumberAnswerStage({
    required this.plan,
    required this.onCorrect,
    required this.onWrong,
    required this.done,
  });

  final StepPlayPlan plan;
  final void Function(int answer) onCorrect;
  final VoidCallback onWrong;
  final bool done;

  @override
  State<NumberAnswerStage> createState() => NumberAnswerStageState();
}

class NumberAnswerStageState extends State<NumberAnswerStage> {
  String _buf = '';
  int? _wrongFlash;

  void _pickDigit(int d) {
    if (widget.done) return;
    final answer = widget.plan.answer;
    if (answer == null) return;

    // Choice mode (big buttons with pre-made options).
    if (widget.plan.choices.isNotEmpty) {
      if (d == answer) {
        HapticFeedback.lightImpact();
        widget.onCorrect(d);
      } else {
        setState(() => _wrongFlash = d);
        HapticFeedback.heavyImpact();
        widget.onWrong();
        Timer(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _wrongFlash = null);
        });
      }
      return;
    }

    // Pad mode — build multi-digit then check.
    final next = _buf.length < 3 ? '$_buf$d' : _buf;
    setState(() => _buf = next);
    final typed = int.tryParse(_buf);
    if (typed == null) return;
    final target = '$answer';
    if (typed == answer) {
      HapticFeedback.lightImpact();
      widget.onCorrect(typed);
      return;
    }
    // Not a prefix of the answer, or already as long as the answer → reset.
    // (Avoids the stuck "typed 1, answer is 21" dead-end.)
    final isPrefix = target.startsWith(_buf);
    if (!isPrefix || _buf.length >= target.length) {
      HapticFeedback.heavyImpact();
      widget.onWrong();
      Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _buf = '');
      });
    }
  }

  void _backspace() {
    if (widget.done || _buf.isEmpty) return;
    setState(() => _buf = _buf.substring(0, _buf.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.plan.answer ?? 0;
    final useChoices = widget.plan.choices.isNotEmpty;

    if (useChoices) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final c in widget.plan.choices)
            DigitChip(
              label: c,
              highlight: widget.done && c == '$answer',
              wrong: _wrongFlash != null && c == '$_wrongFlash',
              onTap: widget.done ? null : () => _pickDigit(int.parse(c)),
            ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: WatotoColors.sky.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _buf.isEmpty ? '·' : _buf,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: WatotoColors.deep,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
          [-1, 0, -2], // -1 spacer visual, -2 backspace
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: d == -1
                        ? const SizedBox(width: 64)
                        : d == -2
                            ? DigitChip(
                                label: '⌫',
                                onTap: widget.done ? null : _backspace,
                              )
                            : DigitChip(
                                label: '$d',
                                onTap:
                                    widget.done ? null : () => _pickDigit(d),
                              ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class DigitChip extends StatelessWidget {
  const DigitChip({
    required this.label,
    this.onTap,
    this.highlight = false,
    this.wrong = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool highlight;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? WatotoColors.leaf
        : wrong
            ? WatotoColors.berry
            : WatotoColors.sky;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tap empty cells to fill an m×n array — multiplication made tactile.
class ArrayBuildStage extends StatefulWidget {
  const ArrayBuildStage({
    required this.rows,
    required this.cols,
    required this.onCompleted,
  });

  final int rows;
  final int cols;
  final VoidCallback onCompleted;

  @override
  State<ArrayBuildStage> createState() => ArrayBuildStageState();
}

class ArrayBuildStageState extends State<ArrayBuildStage> {
  late final List<bool> _filled =
      List.filled(widget.rows * widget.cols, false);

  void _tap(int i) {
    if (_filled[i]) return;
    setState(() => _filled[i] = true);
    HapticFeedback.selectionClick();
    if (_filled.every((f) => f)) {
      HapticFeedback.lightImpact();
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _filled.where((f) => f).length;
    final total = widget.rows * widget.cols;
    return Column(
      children: [
        Text(
          '$n / $total',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: WatotoColors.mango,
          ),
        ),
        const SizedBox(height: 10),
        for (var r = 0; r < widget.rows; r++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var c = 0; c < widget.cols; c++)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: GestureDetector(
                    onTap: () => _tap(r * widget.cols + c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _filled[r * widget.cols + c]
                            ? WatotoColors.mango
                            : WatotoColors.sky.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: WatotoColors.deep.withValues(alpha: 0.15),
                        ),
                      ),
                      child: _filled[r * widget.cols + c]
                          ? const Icon(Icons.circle, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class ChoiceStage extends StatefulWidget {
  const ChoiceStage({
    super.key,
    required this.plan,
    required this.onCompleted,
    this.onWrong,
  });

  final ChoicePlan plan;
  final VoidCallback onCompleted;

  /// Fired on each new wrong pick, so callers can score first-attempt
  /// accuracy. The child is never blocked — they keep trying either way.
  final VoidCallback? onWrong;

  @override
  State<ChoiceStage> createState() => ChoiceStageState();
}

class ChoiceStageState extends State<ChoiceStage> {
  final _wrong = <int>{};
  bool _done = false;

  void _pick(int i) {
    if (_done) return;
    if (i == widget.plan.targetIndex) {
      setState(() => _done = true);
      HapticFeedback.lightImpact();
      widget.onCompleted();
    } else if (_wrong.add(i)) {
      setState(() {});
      widget.onWrong?.call();
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < widget.plan.options.length; i++)
              Semantics(
                button: true,
                label: widget.plan.options[i].word,
                child: GestureDetector(
                  onTap: () => _pick(i),
                  child: AnimatedScale(
                    scale: _done && i == widget.plan.targetIndex
                        ? 1.2
                        : (_wrong.contains(i) ? 0.85 : 1.0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity:
                          _wrong.contains(i) ||
                              (_done && i != widget.plan.targetIndex)
                          ? 0.35
                          : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 92,
                          minHeight: 92,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _done && i == widget.plan.targetIndex
                                ? WatotoColors.leaf
                                : WatotoColors.sky.withValues(alpha: 0.25),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: WatotoColors.deep.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        // Reading choices ("cap" vs "cape") render as words,
                        // not emoji-sized glyphs.
                        child: isWordOption(widget.plan.options[i].emoji)
                            ? Text(
                                widget.plan.options[i].emoji,
                                style: const TextStyle(
                                  fontFamily: 'Baloo2',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: WatotoColors.deep,
                                ),
                              )
                            : Text(
                                widget.plan.options[i].emoji,
                                style: const TextStyle(fontSize: 48),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_wrong.isNotEmpty && !_done) ...[
          const SizedBox(height: 12),
          Text(
            l10n.tryAgain,
            style: const TextStyle(fontSize: 15, color: WatotoColors.berry),
          ),
        ],
      ],
    );
  }
}

/// A multi-letter alphabetic option is a word to read, not an emoji/symbol.
/// True for anything meant to be *read* — a word, a number, "80 and 12" — as
/// opposed to a single pictorial glyph.
bool isWordOption(String s) =>
    s.length > 1 && RegExp(r'[A-Za-z0-9]').hasMatch(s);

/// The stage's hero glyph. Breathes, because on most steps this *is* the
/// picture — the decorative slot above it is empty until per-step art exists.
///
/// Only the hero: the choice options render their own [Text] and stay still, so
/// a grid of answers does not shimmer while a child is trying to read it. The
/// scale swing is 3.5%, which is visible at 88pt but does not meaningfully move
/// the tap target; reduce-motion stops it entirely.
Widget bigEmoji(String emoji) => BreathingArt(
      child: Text(emoji, style: const TextStyle(fontSize: 88)),
    );


class ExplainStage extends StatelessWidget {
  const ExplainStage({
    required this.emoji,
    required this.onCompleted,
    this.prompt,
  });
  final String emoji;
  final VoidCallback onCompleted;

  /// Button label when the step asks for something specific ("Think… then tap
  /// to check!"). Plain exposition just says "Got it!".
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        ExcludeSemantics(child: bigEmoji(emoji)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onCompleted,
          child: Text(prompt ?? l10n.gotIt),
        ),
      ],
    );
  }
}

/// Tap the big picture to make it pop — bounce + stars so plain taps still feel fun.
class TapStage extends StatefulWidget {
  const TapStage({
    required this.emoji,
    required this.onCompleted,
    this.prompt,
  });
  final String emoji;
  final VoidCallback onCompleted;

  /// What the child is being asked to do, from the step plan ("Tap the little
  /// a!", "Shake it — then tap!"). Falls back to the generic invitation only
  /// when the step named nothing.
  final String? prompt;
  @override
  State<TapStage> createState() => TapStageState();
}

class TapStageState extends State<TapStage> {
  bool _done = false;

  void _tap() {
    if (_done) return;
    setState(() => _done = true);
    HapticFeedback.lightImpact();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prompt = widget.prompt;
    return Column(
      children: [
        Semantics(
          button: true,
          // Screen readers still need a name for the target even when the
          // caption above carries the visible instruction.
          label: prompt ?? l10n.tapEachPrompt,
          child: GestureDetector(
            onTap: _tap,
            child: AnimatedScale(
              scale: _done ? 1.28 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_done ? WatotoColors.leaf : WatotoColors.sun)
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  bigEmoji(widget.emoji),
                  if (_done)
                    const Positioned(
                      top: 0,
                      right: 8,
                      child: Text('⭐', style: TextStyle(fontSize: 28)),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_done || prompt != null) ...[
          const SizedBox(height: 12),
          Text(
            _done ? 'Yes!' : prompt!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _done ? WatotoColors.leaf : WatotoColors.sky,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tap every object to count it — the `tap-to-count` / number family.
class CountStage extends StatefulWidget {
  const CountStage({
    required this.emoji,
    required this.count,
    required this.onCompleted,
    required this.onTapSound,
    this.prompt,
  });
  final String emoji;
  final String? prompt;
  final int count;
  final VoidCallback onCompleted;
  final VoidCallback onTapSound;
  @override
  State<CountStage> createState() => CountStageState();
}

class CountStageState extends State<CountStage> {
  late final List<bool> _counted = List.filled(widget.count, false);
  int get _n => _counted.where((c) => c).length;

  void _tap(int i) {
    if (_counted[i]) return;
    setState(() => _counted[i] = true);
    HapticFeedback.lightImpact();
    if (_n == widget.count) {
      widget.onCompleted(); // completion chime handled by the parent
    } else {
      widget.onTapSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          widget.prompt ?? l10n.tapEachPrompt,
          style: const TextStyle(fontSize: 15, color: WatotoColors.sky),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < widget.count; i++)
              Semantics(
                button: true,
                label: '${i + 1}',
                child: GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedScale(
                    scale: _counted[i] ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Badge(
                      isLabelVisible: _counted[i],
                      backgroundColor: WatotoColors.leaf,
                      label: Text(
                        '${_counted.take(i + 1).where((c) => c).length}',
                      ),
                      child: Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 56),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Drag the object into the basket — the `drag` / build / trace family. Also
/// completes on a tap so it stays reachable for screen-reader users.
class DragStage extends StatefulWidget {
  const DragStage({
    required this.emoji,
    required this.onCompleted,
    this.prompt,
  });
  final String emoji;
  final String? prompt;
  final VoidCallback onCompleted;
  @override
  State<DragStage> createState() => DragStageState();
}

class DragStageState extends State<DragStage> {
  bool _done = false;

  void _finish() {
    if (_done) return;
    setState(() => _done = true);
    HapticFeedback.mediumImpact();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          widget.prompt ?? l10n.dragToBasket,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: WatotoColors.sky),
        ),
        const SizedBox(height: 16),
        if (!_done)
          Semantics(
            button: true,
            label: l10n.dragToBasket,
            child: Draggable<int>(
              data: 1,
              feedback: bigEmoji(widget.emoji),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: bigEmoji(widget.emoji),
              ),
              // Tap also completes, so the step is doable without a drag.
              child: GestureDetector(
                onTap: _finish,
                child: bigEmoji(widget.emoji),
              ),
            ),
          ),
        const SizedBox(height: 24),
        DragTarget<int>(
          onAcceptWithDetails: (_) => _finish(),
          builder: (context, candidate, rejected) => Container(
            width: 120,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WatotoColors.sky.withValues(
                alpha: candidate.isNotEmpty ? 0.3 : 0.12,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _done ? '✅' : '🧺',
              style: const TextStyle(fontSize: 44),
            ),
          ),
        ),
      ],
    );
  }
}
