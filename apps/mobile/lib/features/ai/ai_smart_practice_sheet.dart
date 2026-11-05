import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/watoto_ai_engine.dart';
import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../domain/rules/review.dart';
import '../library/library_repository.dart';

/// A single question in an AI Smart Practice adaptive micro-quiz.
class SmartPracticeItem {
  const SmartPracticeItem({
    required this.subject,
    required this.stage,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String subject;
  final int stage;
  final String prompt;
  final List<String> options;
  final int correctIndex;
}

/// Builds a 3-question adaptive micro-quiz targeting the child's weakest or
/// retried concepts in [store], falling back to a curated trilingual Savanna
/// practice deck when no library quizzes are loaded yet.
List<SmartPracticeItem> buildSmartPracticeQuestions({
  required String childId,
  required OfflineStore store,
  LibraryRepository? library,
  required String locale,
}) {
  final out = <SmartPracticeItem>[];
  final records = store.reviewRecords(childId).toList()
    ..sort((ReviewRecord a, ReviewRecord b) {
      final byRetries = b.retries.compareTo(a.retries);
      if (byRetries != 0) return byRetries;
      return a.lastScore.compareTo(b.lastScore);
    });

  if (library != null) {
    for (final rec in records) {
      final item = library.byId[rec.itemId];
      if (item != null && item.questions.isNotEmpty) {
        final q = item.questions.first;
        out.add(
          SmartPracticeItem(
            subject: item.subject,
            stage: item.stage,
            prompt: q.prompt,
            options: [for (final o in q.options) o.label],
            correctIndex: q.answer,
          ),
        );
        if (out.length >= 3) return out;
      }
    }
  }

  final fallbacks = switch (locale) {
    'sw' => const <SmartPracticeItem>[
        SmartPracticeItem(
          subject: 'Numeracy',
          stage: 2,
          prompt: 'Twiga ana miguu mingapi? 🦒',
          options: ['🦒 4', '🦩 2', '🐞 6'],
          correctIndex: 0,
        ),
        SmartPracticeItem(
          subject: 'Literacy',
          stage: 2,
          prompt: 'Neno "Simba" linaanza na herufi gani? 🦁',
          options: ['🦁 S', '🐘 M', '🦒 B'],
          correctIndex: 0,
        ),
        SmartPracticeItem(
          subject: 'Science',
          stage: 2,
          prompt: 'Mimea inahitaji nini ili ikue vizuri? 🌱',
          options: ['💧☀️ Maji na Jua', '🪨 Mawe pekee', '🌑 Giza pekee'],
          correctIndex: 0,
        ),
      ],
    'fr' => const <SmartPracticeItem>[
        SmartPracticeItem(
          subject: 'Numeracy',
          stage: 2,
          prompt: 'Combien de pattes a la girafe ? 🦒',
          options: ['🦒 4', '🦩 2', '🐞 6'],
          correctIndex: 0,
        ),
        SmartPracticeItem(
          subject: 'Literacy',
          stage: 2,
          prompt: 'Par quelle lettre commence le mot « Soleil » ? ☀️',
          options: ['☀️ S', '🌙 L', '🌳 M'],
          correctIndex: 0,
        ),
        SmartPracticeItem(
          subject: 'Science',
          stage: 2,
          prompt: 'De quoi une plante a-t-elle besoin pour grandir ? 🌱',
          options: ['💧☀️ D’eau et de soleil', '🪨 De cailloux', '🌑 D’obscurité'],
          correctIndex: 0,
        ),
      ],
    _ => const <SmartPracticeItem>[
        SmartPracticeItem(
          subject: 'Numeracy',
          stage: 2,
          prompt: 'How many legs does a giraffe have? 🦒',
          options: ['🦒 4', '🦩 2', '🐞 6'],
          correctIndex: 0,
        ),
        SmartPracticeItem(
          subject: 'Literacy',
          stage: 2,
          prompt: 'Which letter does "Sun" start with? ☀️',
          options: ['☀️ S', '🌙 M', '🌳 T'],
          correctIndex: 0,
        ),
        SmartPracticeItem(
          subject: 'Science',
          stage: 2,
          prompt: 'What helps a little savanna sprout grow tall? 🌱',
          options: ['💧☀️ Water and sunlight', '🪨 Rocks only', '🌑 Darkness only'],
          correctIndex: 0,
        ),
      ],
  };

  for (final f in fallbacks) {
    if (out.length >= 3) break;
    out.add(f);
  }
  return out;
}

/// Interactive AI "Smart Practice" adaptive micro-quiz modal sheet.
class AiSmartPracticeSheet extends ConsumerStatefulWidget {
  const AiSmartPracticeSheet({super.key});

  @override
  ConsumerState<AiSmartPracticeSheet> createState() =>
      _AiSmartPracticeSheetState();
}

class _AiSmartPracticeSheetState extends ConsumerState<AiSmartPracticeSheet> {
  List<SmartPracticeItem>? _questions;
  int _index = 0;
  String? _explanation;
  bool _answeredRight = false;
  bool _completed = false;

  List<SmartPracticeItem> _resolveQuestions() {
    if (_questions != null) return _questions!;
    final child = ref.read(activeChildProvider);
    final store = ref.read(offlineStoreProvider);
    final lib = ref.read(libraryProvider).asData?.value;
    final locale = ref.read(localeProvider).languageCode;
    _questions = buildSmartPracticeQuestions(
      childId: child?.id ?? '',
      store: store,
      library: lib,
      locale: locale,
    );
    return _questions!;
  }

  Future<void> _pickOption(SmartPracticeItem q, int optionIndex) async {
    unawaited(HapticFeedback.selectionClick());
    final locale = ref.read(localeProvider).languageCode;
    final ai = ref.read(watotoAiEngineProvider);
    final correct = optionIndex == q.correctIndex;

    if (correct) {
      unawaited(ref.read(soundEffectsProvider).correct());
      final reply = await ai.generateSocraticResponse(
        kind: AiCuriosityKind.funFact,
        subject: q.subject,
        stage: q.stage,
        promptContext: q.prompt,
        locale: locale,
      );
      if (!mounted) return;
      setState(() {
        _answeredRight = true;
        _explanation = '✅ ${reply.body}';
      });
      unawaited(
        ref.read(narrationProvider.notifier).speak(
              reply.body,
              locale,
              style: SpeakStyle.cheer,
            ),
      );
    } else {
      unawaited(ref.read(soundEffectsProvider).retry());
      final clue = await ai.generateSocraticResponse(
        kind: AiCuriosityKind.clue,
        subject: q.subject,
        stage: q.stage,
        promptContext: q.prompt,
        locale: locale,
      );
      if (!mounted) return;
      setState(() {
        _answeredRight = false;
        _explanation = '💡 ${clue.body}';
      });
      unawaited(
        ref.read(narrationProvider.notifier).speak(
              clue.body,
              locale,
              style: SpeakStyle.hint,
            ),
      );
    }
  }

  Future<void> _nextQuestion(List<SmartPracticeItem> questions) async {
    if (_index < questions.length - 1) {
      setState(() {
        _index++;
        _explanation = null;
        _answeredRight = false;
      });
    } else {
      final child = ref.read(activeChildProvider);
      if (child != null) {
        await ref.read(offlineStoreProvider).grantCoins(child.id, 5);
        ref.read(economyTickProvider.notifier).state++;
      }
      if (!mounted) return;
      setState(() => _completed = true);
      unawaited(ref.read(soundEffectsProvider).celebrate());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final questions = _resolveQuestions();
    final q = questions[_index];

    final title = switch (locale) {
      'sw' => '🎯🤖 Mazoezi Mahiri ya AI (${_index + 1}/${questions.length})',
      'fr' => '🎯🤖 Pratique Intelligente IA (${_index + 1}/${questions.length})',
      _ => '🎯🤖 AI Smart Practice (${_index + 1}/${questions.length})',
    };

    return SafeArea(
      child: Padding(
        key: const ValueKey('ai-smart-practice-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
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
            if (_completed)
              Container(
                key: const ValueKey('smart-practice-complete'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('🧠✨🏆', style: TextStyle(fontSize: 34)),
                    const SizedBox(height: 8),
                    Text(
                      switch (locale) {
                        'sw' => 'Umekamilisha Mazoezi Mahiri! +5 Sarafu 🪙',
                        'fr' => 'Pratique IA Terminée ! +5 Pièces 🪙',
                        _ => 'AI Smart Practice Complete! +5 Bonus Coins 🪙',
                      },
                      style: const TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: WatotoColors.deep,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                q.prompt,
                key: const ValueKey('smart-practice-prompt'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    key: ValueKey('smart-practice-option-$i'),
                    onPressed: () => _pickOption(q, i),
                    child: Text(q.options[i]),
                  ),
                ),
              if (_explanation != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _answeredRight
                          ? WatotoColors.leaf
                          : WatotoColors.mango,
                    ),
                  ),
                  child: Text(
                    _explanation!,
                    key: const ValueKey('smart-practice-explanation'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: WatotoColors.deep,
                    ),
                  ),
                ),
              ],
              if (_answeredRight) ...[
                const SizedBox(height: 10),
                FilledButton(
                  key: const ValueKey('smart-practice-next'),
                  onPressed: () => _nextQuestion(questions),
                  child: Text(
                    _index < questions.length - 1 ? 'Next Question' : 'Finish! 🎉',
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showAiSmartPractice(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WatotoColors.cloud,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const AiSmartPracticeSheet(),
  );
}
