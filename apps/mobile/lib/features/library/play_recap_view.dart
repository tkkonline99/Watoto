/// "What did we learn?" — the authored recap question a lesson ends on.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'content_i18n.dart';
import 'content_lexicon.dart';
import 'lesson_recap.dart';
import 'play_celebration.dart';
import 'play_stages.dart';
import 'play_shared.dart';

class LessonRecapView extends ConsumerStatefulWidget {
  const LessonRecapView({
    super.key,
    required this.title,
    required this.localized,
    required this.questions,
    required this.onWrong,
    required this.onFinished,
  });

  final String title;

  /// Supplies the translated prompt and options for authored questions.
  final LocalizedItem localized;

  final List<RecapQuestion> questions;
  final VoidCallback onWrong;
  final VoidCallback onFinished;

  @override
  ConsumerState<LessonRecapView> createState() => LessonRecapViewState();
}

class LessonRecapViewState extends ConsumerState<LessonRecapView> {
  int _index = 0;
  bool _answered = false;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  /// The question as the child sees it: translated when authored, the English
  /// extraction otherwise (which only ever reaches an English-speaking child).
  String _promptFor(int i) {
    final q = widget.questions[i];
    final r = q.recapIndex;
    return r == null ? q.prompt : widget.localized.recapPrompt(r);
  }

  List<String> _optionsFor(int i) {
    final q = widget.questions[i];
    final r = q.recapIndex;
    return r == null ? q.options : widget.localized.recapOptions(r);
  }

  void _speak() {
    if (!mounted) return;
    final lang = ref.read(localeProvider).languageCode;
    // Read the choices out after the question. A child who is still learning
    // to read can hear the options rather than having to decode three written
    // answers under time pressure — the recap is testing what they learned in
    // the lesson, not how fast they read.
    final options = _optionsFor(_index).join('. ');
    ref.read(narrationProvider.notifier).speak(
          '${_promptFor(_index)} $options',
          lang,
          style: SpeakStyle.hint,
        );
  }

  void _onCorrect() {
    if (_answered) return;
    setState(() => _answered = true);
    ref.read(soundEffectsProvider).correct();
    _advance?.cancel();
    _advance = Timer(const Duration(milliseconds: 900), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    _advance?.cancel();
    if (_index >= widget.questions.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() {
      _index++;
      _answered = false;
    });
    _speak();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = widget.questions[_index];
    final total = widget.questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: false,
        actions: const [NarrationButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.recapTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.recapProgress(_index + 1, total),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WatotoColors.deep.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ProgressDots(count: total, active: _index),
                  const SizedBox(height: 20),
                  Text(
                    _promptFor(_index),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: WatotoColors.deep,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ChoiceStage(
                    key: ValueKey('recap-$_index'),
                    plan: ChoicePlan(
                      [for (final o in _optionsFor(_index)) ChoiceOption(o, o)],
                      q.answerIndex,
                    ),
                    onCompleted: _onCorrect,
                    onWrong: widget.onWrong,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _answered ? _goNext : null,
                    child: Text(
                      _index >= total - 1 ? l10n.done : l10n.next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
