/// The block-coding stage: a pretend editor with a RUN button.
///
/// Lives apart from the other stages because it is the only one with a whole
/// interpreter behind it — commands, a runner, an animated turtle — and at ~490
/// lines it was a third of the play screen on its own.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/watoto_theme.dart';
import 'step_play.dart';

class KidCodeStage extends StatefulWidget {
  const KidCodeStage({
    required this.plan,
    required this.onCompleted,
    required this.onTapSound,
  });

  final StepPlayPlan plan;
  final VoidCallback onCompleted;
  final VoidCallback onTapSound;

  @override
  State<KidCodeStage> createState() => KidCodeStageState();
}

class KidCodeStageState extends State<KidCodeStage>
    with SingleTickerProviderStateMixin {
  /// 0 = build, 1 = ready to run, 2 = running animation, 3 = done
  int _phase = 0;
  final List<String> _built = [];
  late List<String> _pool;
  String? _message;
  String? _name;
  int _age = 8;
  int _loopN = 3;
  int _score = 12;
  String _output = '';
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    final challenge = widget.plan.codeChallenge ?? 'print';
    _pool = List<String>.from(widget.plan.codeTokens);
    if (_pool.isEmpty && challenge == 'print') {
      final msg = widget.plan.outputLine ?? 'Hello, world!';
      _pool = ['print', '(', '"$msg"', ')'];
    }
    _pool.shuffle();
    _message = widget.plan.outputLine ?? 'Hello, world!';
    _name = (widget.plan.messageChoices.isNotEmpty)
        ? widget.plan.messageChoices.first
        : 'Sam';
    _loopN = widget.plan.answer ?? 3;
    // Message / variable challenges start ready once a choice is implicit.
    if (challenge == 'message' ||
        challenge == 'variable' ||
        challenge == 'twoLines' ||
        challenge == 'loop' ||
        challenge == 'if') {
      _phase = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _codePreview {
    final c = widget.plan.codeChallenge ?? 'print';
    switch (c) {
      case 'message':
        return 'print("${_message ?? 'Hi!'}")';
      case 'variable':
        return 'name = "${_name ?? 'Sam'}"\nprint(name)';
      case 'twoLines':
        return 'print("${_name ?? 'Amani'}")\nprint($_age)';
      case 'loop':
        return 'for i in range($_loopN):\n  print("Hi")';
      case 'if':
        return 'score = $_score\nif score >= 10:\n  print("You win!")\nelse:\n  print("Try again")';
      default:
        if (_built.isEmpty) return '…';
        return _built.join(' ');
    }
  }

  String get _expectedOutput {
    final c = widget.plan.codeChallenge ?? 'print';
    switch (c) {
      case 'message':
        return _message ?? 'Hi!';
      case 'variable':
        return _name ?? 'Sam';
      case 'twoLines':
        return '${_name ?? 'Amani'}\n$_age';
      case 'loop':
        return List.filled(_loopN, 'Hi').join('\n');
      case 'if':
        return _score >= 10 ? 'You win!' : 'Try again';
      default:
        return widget.plan.outputLine ?? 'Hello, world!';
    }
  }

  bool get _buildComplete {
    final tokens = widget.plan.codeTokens.isNotEmpty
        ? widget.plan.codeTokens
        : ['print', '(', '"${widget.plan.outputLine ?? 'Hello, world!'}"', ')'];
    if (_built.length != tokens.length) return false;
    for (var i = 0; i < tokens.length; i++) {
      if (_built[i] != tokens[i]) return false;
    }
    return true;
  }

  void _tapToken(String token) {
    if (_phase != 0) return;
    final tokens = widget.plan.codeTokens.isNotEmpty
        ? widget.plan.codeTokens
        : ['print', '(', '"${widget.plan.outputLine ?? 'Hello, world!'}"', ')'];
    final next = tokens[_built.length];
    widget.onTapSound();
    if (token == next) {
      HapticFeedback.selectionClick();
      setState(() {
        _built.add(token);
        _pool.remove(token);
        if (_buildComplete) _phase = 1;
      });
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _run() async {
    if (_phase != 1) return;
    setState(() {
      _phase = 2;
      _output = '';
    });
    HapticFeedback.mediumImpact();
    final full = _expectedOutput;
    // Typewriter output — addictive "it worked!" moment.
    for (var i = 1; i <= full.length; i++) {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 28));
      setState(() => _output = full.substring(0, i));
    }
    if (!mounted) return;
    setState(() => _phase = 3);
    HapticFeedback.lightImpact();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.plan.codeChallenge ?? 'print';
    return Column(
      children: [
        // Mascot reacts to phase.
        Text(
          _phase >= 3
              ? '🎉'
              : _phase == 2
                  ? '🤖'
                  : '🧑‍💻',
          style: const TextStyle(fontSize: 48),
        ),
        const SizedBox(height: 8),
        Text(
          _phase == 0
              ? 'Tap blocks in order!'
              : _phase == 1
                  ? 'Ready — smash RUN!'
                  : _phase == 2
                      ? 'Running…'
                      : 'It worked!',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: WatotoColors.deep,
          ),
        ),
        const SizedBox(height: 12),

        // Challenge-specific choosers — each challenge gets the controls it needs.
        if (c == 'twoLines') ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '1. Your name',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final m in widget.plan.messageChoices)
                ChoiceChip(
                  label: Text(m),
                  selected: _name == m,
                  selectedColor: WatotoColors.sun,
                  onSelected: _phase >= 2
                      ? null
                      : (_) => setState(() {
                            _name = m;
                            _phase = 1;
                          }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '2. Your age: $_age',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          Slider(
            value: _age.toDouble(),
            min: 5,
            max: 12,
            divisions: 7,
            label: '$_age',
            activeColor: WatotoColors.mango,
            onChanged: _phase >= 2
                ? null
                : (v) => setState(() {
                      _age = v.round();
                      _phase = 1;
                    }),
          ),
          // Age quick-picks (slider alone is easy to miss on web).
          Wrap(
            spacing: 6,
            children: [
              for (final a in [6, 7, 8, 9, 10, 11])
                ActionChip(
                  label: Text('$a'),
                  backgroundColor: _age == a
                      ? WatotoColors.mango.withValues(alpha: 0.35)
                      : null,
                  onPressed: _phase >= 2
                      ? null
                      : () => setState(() {
                            _age = a;
                            _phase = 1;
                          }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Will print:\n${_name ?? 'Amani'}\n$_age',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: WatotoColors.leaf,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
        ] else if (c == 'message' || c == 'variable') ...[
          Text(
            c == 'message' ? 'What should it say?' : 'What goes in the box?',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final m in widget.plan.messageChoices)
                ChoiceChip(
                  label: Text(m),
                  selected: c == 'variable' ? _name == m : _message == m,
                  selectedColor: WatotoColors.sun,
                  onSelected: _phase >= 2
                      ? null
                      : (_) => setState(() {
                            if (c == 'message') {
                              _message = m;
                            } else {
                              _name = m;
                            }
                            _phase = 1;
                          }),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (c == 'loop') ...[
          Text(
            'Repeat $_loopN times',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final n in [2, 3, 4, 5])
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: _loopN == n,
                    onSelected: _phase >= 2
                        ? null
                        : (_) => setState(() {
                              _loopN = n;
                              _phase = 1;
                            }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (c == 'if') ...[
          Text(
            'score = $_score',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final n in [4, 8, 12, 15])
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: _score == n,
                    onSelected: _phase >= 2
                        ? null
                        : (_) => setState(() {
                              _score = n;
                              _phase = 1;
                            }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Token build tray (print assembly).
        if (c == 'print' || c == 'fix') ...[
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WatotoColors.sky, width: 2),
            ),
            child: Text(
              _built.isEmpty ? '⬇ drop blocks here' : _built.join(' '),
              style: TextStyle(
                fontFamily: 'monospace',
                color: _built.isEmpty
                    ? Colors.white38
                    : const Color(0xFF7DD3FC),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final t in _pool)
                Material(
                  color: WatotoColors.sun,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _tapToken(t),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          color: WatotoColors.deep,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Live code preview for non-token modes.
        if (c != 'print' && c != 'fix') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _codePreview,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF7DD3FC),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Output console
        if (_phase >= 2) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF14532D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OUTPUT',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _output.isEmpty ? ' ' : _output,
                  style: const TextStyle(
                    color: Color(0xFFBBF7D0),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Big pulsing RUN
        if (_phase == 1 || _phase == 0)
          ScaleTransition(
            scale: Tween(begin: 1.0, end: _phase == 1 ? 1.08 : 1.0).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    _phase == 1 ? WatotoColors.mango : Colors.black26,
                foregroundColor: WatotoColors.deep,
                minimumSize: const Size(200, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _phase == 1 ? _run : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 32),
              label: const Text(
                'RUN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        if (_phase >= 3)
          const Text(
            '⭐ You made the computer talk! ⭐',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: WatotoColors.leaf,
            ),
          ),
      ],
    );
  }
}
