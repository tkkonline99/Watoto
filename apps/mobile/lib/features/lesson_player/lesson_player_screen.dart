import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/content_key_resolver.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'lesson_models.dart';
import 'lesson_repository.dart';

class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  int _blockIndex = 0;
  bool _finished = false;
  final Stopwatch _elapsed = Stopwatch()..start();

  void _advance(LessonBody lesson) {
    if (_blockIndex < lesson.blocks.length - 1) {
      setState(() => _blockIndex++);
    } else {
      setState(() => _finished = true);
      _elapsed.stop();
      // Persist + enqueue sync; the celebration never waits on the network.
      unawaited(ref.read(learningServiceProvider).completeLesson(
            lesson,
            scorePct: 100,
            timeSpentS: _elapsed.elapsed.inSeconds,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lessonAsync = ref.watch(lessonProvider(widget.slug));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
        title: lessonAsync.maybeWhen(
          data: (lesson) => Text(
            resolveContentKey(l10n, lesson.titleKey),
            style: const TextStyle(color: WatotoColors.deep, fontWeight: FontWeight.w800),
          ),
          orElse: () => null,
        ),
      ),
      body: lessonAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (lesson) => _finished
            ? _CelebrationView(
                xp: lesson.completion.xp,
                quizSlug: lesson.quizSlug,
                onDone: () => context.go('/'),
              )
            : Column(
                children: [
                  _ProgressDots(count: lesson.blocks.length, active: _blockIndex),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _BlockView(
                        key: ValueKey(_blockIndex),
                        block: lesson.blocks[_blockIndex],
                        onCompleted: () => _advance(lesson),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= active ? WatotoColors.mango : Colors.black12,
            ),
          ),
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({super.key, required this.block, required this.onCompleted});

  final LessonBlock block;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      final ConceptBlock b => _ConceptView(block: b, onCompleted: onCompleted),
      final TapToCountBlock b => _TapToCountView(block: b, onCompleted: onCompleted),
      final CheckBlock b => _CheckView(block: b, onCompleted: onCompleted),
    };
  }
}

class _ConceptView extends StatelessWidget {
  const _ConceptView({required this.block, required this.onCompleted});

  final ConceptBlock block;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(block.emoji, style: const TextStyle(fontSize: 96)),
        const SizedBox(height: 24),
        Text(
          resolveContentKey(l10n, block.textKey),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 40),
        FilledButton(onPressed: onCompleted, child: Text(l10n.next)),
      ],
    );
  }
}

class _TapToCountView extends StatefulWidget {
  const _TapToCountView({required this.block, required this.onCompleted});

  final TapToCountBlock block;
  final VoidCallback onCompleted;

  @override
  State<_TapToCountView> createState() => _TapToCountViewState();
}

class _TapToCountViewState extends State<_TapToCountView> {
  late final List<bool> _counted = List.filled(widget.block.items, false);

  int get _count => _counted.where((c) => c).length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allCounted = _count == widget.block.items;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.tapToCountPrompt,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          children: [
            for (var i = 0; i < widget.block.items; i++)
              GestureDetector(
                onTap: _counted[i] ? null : () => setState(() => _counted[i] = true),
                child: AnimatedScale(
                  scale: _counted[i] ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Badge(
                    isLabelVisible: _counted[i],
                    backgroundColor: WatotoColors.leaf,
                    label: Text('${_counted.take(i + 1).where((c) => c).length}'),
                    child: const Text('🥭', style: TextStyle(fontSize: 64)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: allCounted ? widget.onCompleted : null,
          child: Text(l10n.next),
        ),
      ],
    );
  }
}

class _CheckView extends StatefulWidget {
  const _CheckView({required this.block, required this.onCompleted});

  final CheckBlock block;
  final VoidCallback onCompleted;

  @override
  State<_CheckView> createState() => _CheckViewState();
}

class _CheckViewState extends State<_CheckView> {
  int? _wrongIndex;

  void _select(int index) {
    if (widget.block.options[index].correct) {
      widget.onCompleted();
    } else {
      setState(() => _wrongIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          resolveContentKey(l10n, widget.block.promptKey),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        if (_wrongIndex != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.tryAgain,
            style: const TextStyle(fontSize: 18, color: WatotoColors.berry),
          ),
        ],
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var i = 0; i < widget.block.options.length; i++)
              SizedBox(
                width: 88,
                height: 88,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _wrongIndex == i ? WatotoColors.berry : WatotoColors.sky,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => _select(i),
                  child: Text(widget.block.options[i].text),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CelebrationView extends StatelessWidget {
  const _CelebrationView({required this.xp, required this.quizSlug, required this.onDone});

  final int xp;
  final String? quizSlug;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 96)),
          const SizedBox(height: 16),
          Text(
            l10n.greatJob,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.xpEarned(xp),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: WatotoColors.mango,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 16,
            children: [
              if (quizSlug != null)
                FilledButton(
                  onPressed: () => context.go('/quiz/$quizSlug'),
                  child: Text(l10n.quizTime),
                ),
              FilledButton(onPressed: onDone, child: Text(l10n.done)),
            ],
          ),
        ],
      ),
    );
  }
}
