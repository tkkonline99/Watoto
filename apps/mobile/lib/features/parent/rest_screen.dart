import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/mascot_widget.dart';
import '../../l10n/gen/app_localizations.dart';

/// Soft screen-time lock — kind language, parent can add 10 more minutes.
class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends ConsumerState<RestScreen> {
  @override
  void initState() {
    super.initState();
    // Reaching the soft lock is a product signal (is the default limit too
    // tight?), recorded once per time the screen is shown rather than on
    // every rebuild.
    ref.read(analyticsProvider).log(AnalyticsEvents.screenTimeLimitHit, {
      'limitMinutes': ref.read(offlineStoreProvider).screenTimeLimitMinutes(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotWidget(mood: MascotMood.sleep, size: 96),
              const SizedBox(height: 16),
              Text(
                l10n.restTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.restBody,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.go('/'),
                child: Text(l10n.restGoHome),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/parent'),
                child: Text(l10n.restAskGrownUp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
