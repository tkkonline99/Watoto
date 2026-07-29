/// Friendly loading / empty / error surfaces for kids + grown-ups.
library;

import 'package:flutter/material.dart';

import '../theme/watoto_theme.dart';

/// Full-screen (or expanded) status with emoji, title, body, optional action.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.emoji,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String emoji;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 16.0 : 28.0;
    return Semantics(
      container: true,
      liveRegion: true,
      label: [title, if (body != null) body!].join('. '),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: compact ? 48 : 64),
                  ),
                ),
                SizedBox(height: compact ? 10 : 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.deep,
                  ),
                ),
                if (body != null && body!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 14 : 15,
                      height: 1.4,
                      color: WatotoColors.deep.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Indeterminate loader with optional kid-friendly label.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: CircularProgressIndicator(color: WatotoColors.mango),
            ),
            if (label != null) ...[
              const SizedBox(height: 16),
              Text(
                label!,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: WatotoColors.deep.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
