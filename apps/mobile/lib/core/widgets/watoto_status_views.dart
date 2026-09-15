import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/watoto_theme.dart';
import 'mascot_widget.dart';
import 'watoto_button.dart';

/// Kid-safe loading shell — spinner + optional message (never a blank screen).
class WatotoLoadingView extends StatelessWidget {
  const WatotoLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  color: WatotoColors.deep,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state with mascot and primary action.
class WatotoEmptyView extends StatelessWidget {
  const WatotoEmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotWidget(size: 96),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: WatotoColors.deep,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  color: WatotoColors.deep,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              WatotoButton(label: actionLabel!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where a link to something that is not there lands — a route that matches
/// nothing, or a lesson or guide id that no longer exists.
///
/// These used to print `Not found: <id>` in English on a blank page (or, for
/// an unknown route, go_router's own English "Page Not Found"), with no way
/// back. A child can reach them from an old deep link, so they speak the
/// family's language and offer the way home.
class WatotoNotFoundScreen extends StatelessWidget {
  const WatotoNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: WatotoErrorView(
          title: l10n.notFoundTitle,
          subtitle: l10n.notFoundBody,
        ),
      ),
    );
  }
}

/// Kid-safe error card — never raw exception dumps on child surfaces.
class WatotoErrorView extends StatelessWidget {
  const WatotoErrorView({
    super.key,
    required this.title,
    this.subtitle,
    this.retryLabel,
    this.onRetry,
    this.homeLabel,
    this.showHome = true,
  });

  final String title;
  final String? subtitle;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? homeLabel;
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotWidget(size: 96, mood: MascotMood.think),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: WatotoColors.deep,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  color: WatotoColors.deep,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (onRetry != null && retryLabel != null)
              WatotoButton(label: retryLabel!, onPressed: onRetry!),
            if (showHome) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(
                  homeLabel ?? AppLocalizations.of(context).goHome,
                  style: const TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: WatotoColors.sky,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
