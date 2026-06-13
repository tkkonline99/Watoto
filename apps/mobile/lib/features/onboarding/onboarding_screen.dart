import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../profiles/child_form.dart';
import 'consent.dart';

/// First-run flow: language → consent → parent PIN → first child.
/// Everything is captured locally and persisted in one step at the end
/// (docs/09 §9.1). Required for any deployment — no child data is collected
/// before parental consent is recorded.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  // consent
  bool _aiFeatures = false;
  bool _voiceRecording = false;

  // pin
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();
  String? _pinError;

  // child
  ChildFormValue? _child;

  @override
  void dispose() {
    _pin.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);

  Future<void> _finish() async {
    final consent = ConsentRecord(
      coreData: true,
      aiFeatures: _aiFeatures,
      voiceRecording: _voiceRecording,
      recordedAt: DateTime.now().toUtc(),
    );
    final child = _child!;
    await ref.read(sessionProvider.notifier).completeOnboarding(
          consent: consent,
          pin: _pin.text,
          nickname: child.nickname,
          avatarKey: child.avatarKey,
          birthYear: child.birthYear,
        );
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            0 => _LanguageStep(onNext: _next),
            1 => _ConsentStep(
                aiFeatures: _aiFeatures,
                voiceRecording: _voiceRecording,
                onAi: (v) => setState(() => _aiFeatures = v),
                onVoice: (v) => setState(() => _voiceRecording = v),
                onNext: _next,
              ),
            2 => _PinStep(
                pin: _pin,
                confirm: _pinConfirm,
                error: _pinError,
                onNext: () {
                  if (_pin.text.length < 4) {
                    setState(() => _pinError = l10n.pinTooShort);
                  } else if (_pin.text != _pinConfirm.text) {
                    setState(() => _pinError = l10n.pinMismatch);
                  } else {
                    setState(() => _pinError = null);
                    _next();
                  }
                },
              ),
            _ => _ChildStep(
                onChanged: (v) => setState(() => _child = v),
                canFinish: _child?.isValid ?? false,
                onFinish: _finish,
              ),
          },
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.emoji,
    required this.title,
    required this.child,
    required this.actionLabel,
    required this.onAction,
  });

  final String emoji;
  final String title;
  final Widget child;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(emoji, style: const TextStyle(fontSize: 56), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Expanded(child: SingleChildScrollView(child: child)),
        const SizedBox(height: 12),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _LanguageStep extends ConsumerWidget {
  const _LanguageStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _StepScaffold(
      emoji: '🦁',
      title: l10n.chooseLanguage,
      actionLabel: l10n.startLearning,
      onAction: onNext,
      child: Column(
        children: [
          for (final entry in const {
            'en': 'English',
            'sw': 'Kiswahili',
            'fr': 'Français',
          }.entries)
            ListTile(
              title: Text(entry.value, style: const TextStyle(fontSize: 18)),
              trailing: ref.watch(localeProvider).languageCode == entry.key
                  ? const Icon(Icons.check_circle, color: WatotoColors.leaf)
                  : const Icon(Icons.circle_outlined),
              onTap: () =>
                  ref.read(localeProvider.notifier).state = Locale(entry.key),
            ),
        ],
      ),
    );
  }
}

class _ConsentStep extends StatelessWidget {
  const _ConsentStep({
    required this.aiFeatures,
    required this.voiceRecording,
    required this.onAi,
    required this.onVoice,
    required this.onNext,
  });

  final bool aiFeatures;
  final bool voiceRecording;
  final ValueChanged<bool> onAi;
  final ValueChanged<bool> onVoice;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepScaffold(
      emoji: '🛡️',
      title: l10n.consentTitle,
      actionLabel: l10n.agreeContinue,
      onAction: onNext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.consentBody, style: const TextStyle(fontSize: 16, height: 1.4)),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: WatotoColors.leaf),
              title: Text(l10n.consentCoreData),
              subtitle: Text(l10n.consentRequired),
            ),
          ),
          SwitchListTile(
            value: aiFeatures,
            onChanged: onAi,
            title: Text(l10n.consentAi),
            subtitle: Text(l10n.consentAiBody),
          ),
          SwitchListTile(
            value: voiceRecording,
            onChanged: onVoice,
            title: Text(l10n.consentVoice),
            subtitle: Text(l10n.consentVoiceBody),
          ),
          const SizedBox(height: 8),
          Text(l10n.consentChangeLater,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PinStep extends StatelessWidget {
  const _PinStep({
    required this.pin,
    required this.confirm,
    required this.error,
    required this.onNext,
  });

  final TextEditingController pin;
  final TextEditingController confirm;
  final String? error;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepScaffold(
      emoji: '🔐',
      title: l10n.setPinTitle,
      actionLabel: l10n.next,
      onAction: onNext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.setPinSubtitle, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: l10n.parentPin,
              border: const OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: confirm,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: l10n.confirmPin,
              border: const OutlineInputBorder(),
              errorText: error,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildStep extends StatelessWidget {
  const _ChildStep({
    required this.onChanged,
    required this.canFinish,
    required this.onFinish,
  });

  final ValueChanged<ChildFormValue> onChanged;
  final bool canFinish;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepScaffold(
      emoji: '🧒',
      title: l10n.createChildTitle,
      actionLabel: l10n.done,
      onAction: canFinish ? onFinish : null,
      child: ChildForm(onChanged: onChanged),
    );
  }
}
