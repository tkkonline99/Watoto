import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/watoto_ai_engine.dart';
import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/mascot_widget.dart';

/// App-bar or inline button that opens the child-safe "Ask Kibo ✨" Socratic AI
/// helper sheet.
class AskKiboButton extends StatelessWidget {
  const AskKiboButton({
    super.key,
    required this.subject,
    required this.stage,
    required this.promptContext,
  });

  final String subject;
  final int stage;
  final String promptContext;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IconButton(
        key: const ValueKey('ask-kibo-button'),
        tooltip: 'Ask Kibo AI',
        icon: const Icon(
          Icons.auto_awesome_rounded,
          color: WatotoColors.mango,
        ),
        onPressed: () => showAskKiboSheet(
          context,
          subject: subject,
          stage: stage,
          promptContext: promptContext,
        ),
      ),
    );
  }
}

/// Child-safe Socratic AI helper modal sheet ("Ask Kibo ✨").
/// Uses structured visual curiosity chips (never an open free-text input box).
class AskKiboSheet extends ConsumerStatefulWidget {
  const AskKiboSheet({
    super.key,
    required this.subject,
    required this.stage,
    required this.promptContext,
  });

  final String subject;
  final int stage;
  final String promptContext;

  @override
  ConsumerState<AskKiboSheet> createState() => _AskKiboSheetState();
}

class _AskKiboSheetState extends ConsumerState<AskKiboSheet> {
  AiSocraticReply? _reply;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ask(AiCuriosityKind.simpler);
    });
  }

  Future<void> _ask(AiCuriosityKind kind) async {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _loading = true);
    final locale = ref.read(localeProvider).languageCode;
    final engine = ref.read(watotoAiEngineProvider);
    final reply = await engine.generateSocraticResponse(
      kind: kind,
      subject: widget.subject,
      stage: widget.stage,
      promptContext: widget.promptContext,
      locale: locale,
    );
    if (!mounted) return;
    setState(() {
      _reply = reply;
      _loading = false;
    });
    unawaited(ref.read(soundEffectsProvider).tap());
    unawaited(
      ref.read(narrationProvider.notifier).speak(
            reply.body,
            locale,
            style: SpeakStyle.hint,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final title = switch (locale) {
      'sw' => 'Muulize Kibo ✨ (Msaidizi wa AI)',
      'fr' => 'Demande à Kibo ✨ (Assistant IA)',
      _ => 'Ask Kibo ✨ (AI Learning Helper)',
    };

    final chips = <(Key, AiCuriosityKind, String, String)>[
      (
        const ValueKey('ask-kibo-chip-simpler'),
        AiCuriosityKind.simpler,
        '💡',
        switch (locale) {
          'sw' => 'Eleza Rahisi',
          'fr' => 'Explique Simplement',
          _ => 'Explain Simply',
        },
      ),
      (
        const ValueKey('ask-kibo-chip-clue'),
        AiCuriosityKind.clue,
        '🧩',
        switch (locale) {
          'sw' => 'Nipe Kidokezo',
          'fr' => 'Donne un Indice',
          _ => 'Give Me a Clue',
        },
      ),
      (
        const ValueKey('ask-kibo-chip-fact'),
        AiCuriosityKind.funFact,
        '🌍',
        switch (locale) {
          'sw' => 'Ukweli wa Mbuga',
          'fr' => 'Secret de la Savane',
          _ => 'Savanna Fun Fact',
        },
      ),
      (
        const ValueKey('ask-kibo-chip-trilingual'),
        AiCuriosityKind.trilingualBridge,
        '🗣️',
        switch (locale) {
          'sw' => 'Lugha 3 (EN/SW/FR)',
          'fr' => '3 Langues (EN/SW/FR)',
          _ => '3 Languages (EN/SW/FR)',
        },
      ),
    ];

    final reply = _reply;

    return SafeArea(
      child: Padding(
        key: const ValueKey('ask-kibo-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const MascotWidget(mood: MascotMood.think, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, kind, emoji, label) in chips)
                  ChoiceChip(
                    key: key,
                    avatar: Text(emoji),
                    label: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    selected: reply?.kind == kind,
                    selectedColor: WatotoColors.sun.withValues(alpha: 0.45),
                    onSelected: (_) => _ask(kind),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: WatotoColors.mango.withValues(alpha: 0.45),
                  width: 1.6,
                ),
              ),
              child: _loading && reply == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (reply != null) ...[
                          Text(
                            reply.headline,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: WatotoColors.mango,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reply.body,
                            key: const ValueKey('ask-kibo-response-text'),
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.38,
                              fontWeight: FontWeight.w700,
                              color: WatotoColors.deep,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAskKiboSheet(
  BuildContext context, {
  required String subject,
  required int stage,
  required String promptContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WatotoColors.cloud,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AskKiboSheet(
      subject: subject,
      stage: stage,
      promptContext: promptContext,
    ),
  );
}
