import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../features/auth/auth_service.dart';
import '../../features/auth/parent_gate.dart';
import '../../l10n/gen/app_localizations.dart';
import '../profiles/child_form.dart';
import 'consent.dart';
import 'language_select_screen.dart';
import 'savanna_background.dart';

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

  // grown-up gate (FTC parental gate)
  final _gate = TextEditingController();
  String? _gateError;

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
    _gate.dispose();
    _pin.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step = (_step - 1).clamp(0, 4));

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
    // Step 0 (language) is its own full-bleed playful screen; the grown-up
    // steps share the card-on-savanna template below.
    return switch (_step) {
      0 => LanguageSelectScreen(onStart: _next),
      1 => _GateStep(
          challenge: ref.watch(parentGateChallengeProvider),
          controller: _gate,
          error: _gateError,
          onBack: _back,
          onNext: () {
            if (checkParentGate(
                _gate.text, ref.read(parentGateChallengeProvider))) {
              setState(() => _gateError = null);
              _next();
            } else {
              setState(() => _gateError = l10n.wrongNumbers);
            }
          },
        ),
      2 => _ConsentStep(
          aiFeatures: _aiFeatures,
          voiceRecording: _voiceRecording,
          onAi: (v) => setState(() => _aiFeatures = v),
          onVoice: (v) => setState(() => _voiceRecording = v),
          onBack: _back,
          onNext: _next,
        ),
      3 => _PinStep(
          pin: _pin,
          confirm: _pinConfirm,
          error: _pinError,
          onBack: _back,
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
          onBack: _back,
          onChanged: (v) => setState(() => _child = v),
          canFinish: _child?.isValid ?? false,
          onFinish: _finish,
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card template
// ─────────────────────────────────────────────────────────────────────────────

// Squircle icon accent colours (one per step).
const _gateColor = Color(0xFF4DA6E5);
const _consentColor = Color(0xFF4CB87B);
const _pinColor = Color(0xFFF4A62A);
const _childColor = Color(0xFF9D6FD8);
const _fieldFill = Color(0xFFFBF6EA);
const _fieldBorder = Color(0xFFE7DEC9);
const _disabledFill = Color(0xFFE7DDC9);
const _disabledText = Color(0xFFB3A488);
const _dotInactive = Color(0xFFE3D9C3);

/// A grown-up onboarding step: a white card on the savanna with a back button,
/// progress dots, a coloured squircle icon, title + subtitle, a [body] and a
/// primary [button]. Matches the design (images 2–5).
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepIndex,
    required this.onBack,
    required this.emoji,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.button,
  });

  static const stepCount = 4;

  final int stepIndex;
  final VoidCallback onBack;
  final String emoji;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return SavannaScaffold(
      topRight: const SavannaLockButton(),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: WatotoColors.deep.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _CircleBack(onBack: onBack),
                      Expanded(
                        child: Center(child: _ProgressDots(active: stepIndex)),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(child: _Squircle(emoji: emoji, color: iconColor)),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: WatotoColors.deep.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 22),
                  body,
                  const SizedBox(height: 22),
                  button,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1EAD9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onBack,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back_rounded, size: 20, color: WatotoColors.deep),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.active});
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _StepCard.stepCount; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? WatotoColors.sun : _dotInactive,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _Squircle extends StatelessWidget {
  const _Squircle({required this.emoji, required this.color});
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 34)),
    );
  }
}

/// Full-width pill button. A null [onPressed] renders the beige disabled state.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.trailing, this.onPressed});
  final String label;
  final Widget? trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [WatotoColors.sun, WatotoColors.mango],
                  )
                : null,
            color: enabled ? null : _disabledFill,
            borderRadius: BorderRadius.circular(30),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: WatotoColors.mango.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: enabled ? WatotoColors.deep : _disabledText,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String? hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _fieldFill,
      hintStyle: TextStyle(color: WatotoColors.deep.withValues(alpha: 0.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _fieldBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: WatotoColors.sun, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: WatotoColors.berry, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: WatotoColors.berry, width: 2),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Steps
// ─────────────────────────────────────────────────────────────────────────────

class _GateStep extends StatelessWidget {
  const _GateStep({
    required this.challenge,
    required this.controller,
    required this.error,
    required this.onBack,
    required this.onNext,
  });

  final ParentGateChallenge challenge;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The challenge is spelled-out words joined by " — "; show each as a chip.
    final words =
        challenge.prompt.split('—').map((w) => w.trim()).where((w) => w.isNotEmpty);
    return _StepCard(
      stepIndex: 0,
      onBack: onBack,
      emoji: '🔢',
      iconColor: _gateColor,
      title: l10n.grownupCheck,
      subtitle: l10n.grownupCheckBody,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [for (final w in words) _WordChip(w)],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: _fieldDecoration(l10n.gateAnswerHint).copyWith(
              errorText: error,
            ),
          ),
        ],
      ),
      button: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => _PrimaryButton(
          label: l10n.next,
          trailing: const Icon(Icons.arrow_forward_rounded,
              size: 20, color: WatotoColors.deep),
          onPressed: value.text.trim().isEmpty ? null : onNext,
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip(this.word);
  final String word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCEBF8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        word,
        style: const TextStyle(
          fontFamily: 'Baloo2',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF2F86D6),
        ),
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
    required this.onBack,
    required this.onNext,
  });

  final bool aiFeatures;
  final bool voiceRecording;
  final ValueChanged<bool> onAi;
  final ValueChanged<bool> onVoice;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepCard(
      stepIndex: 1,
      onBack: onBack,
      emoji: '🛡️',
      iconColor: _consentColor,
      title: l10n.consentTitle,
      subtitle: l10n.consentBody,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _consentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _consentColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _consentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.consentCoreData,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: WatotoColors.deep)),
                      Text(l10n.consentRequired,
                          style: TextStyle(
                              fontSize: 13,
                              color: WatotoColors.deep.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _ConsentToggle(
            title: l10n.consentAi,
            subtitle: l10n.consentAiBody,
            value: aiFeatures,
            onChanged: onAi,
          ),
          _ConsentToggle(
            title: l10n.consentVoice,
            subtitle: l10n.consentVoiceBody,
            value: voiceRecording,
            onChanged: onVoice,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.consentChangeLater,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: WatotoColors.deep.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      button: _PrimaryButton(label: l10n.agreeContinue, onPressed: onNext),
    );
  }
}

class _ConsentToggle extends StatelessWidget {
  const _ConsentToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: WatotoColors.deep)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 13,
                        color: WatotoColors.deep.withValues(alpha: 0.6))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: _consentColor,
          ),
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
    required this.onBack,
    required this.onNext,
  });

  final TextEditingController pin;
  final TextEditingController confirm;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepCard(
      stepIndex: 2,
      onBack: onBack,
      emoji: '🔐',
      iconColor: _pinColor,
      title: l10n.setPinTitle,
      subtitle: l10n.setPinSubtitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(l10n.parentPin),
          _PinField(controller: pin),
          const SizedBox(height: 16),
          _FieldLabel(l10n.confirmPin),
          _PinField(controller: confirm, errorText: error),
        ],
      ),
      button: AnimatedBuilder(
        animation: Listenable.merge([pin, confirm]),
        builder: (context, _) => _PrimaryButton(
          label: l10n.next,
          trailing: const Icon(Icons.arrow_forward_rounded,
              size: 20, color: WatotoColors.deep),
          onPressed: (pin.text.isEmpty || confirm.text.isEmpty) ? null : onNext,
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({required this.controller, this.errorText});
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      // obscureText + number keyboard drops keystrokes on many Android IMEs
      // unless suggestions/autocorrect are off (flutter#67391).
      enableSuggestions: false,
      autocorrect: false,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      style: const TextStyle(fontSize: 18, letterSpacing: 4),
      decoration: _fieldDecoration(null).copyWith(errorText: errorText),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, color: WatotoColors.deep),
      ),
    );
  }
}

class _ChildStep extends StatelessWidget {
  const _ChildStep({
    required this.onBack,
    required this.onChanged,
    required this.canFinish,
    required this.onFinish,
  });

  final VoidCallback onBack;
  final ValueChanged<ChildFormValue> onChanged;
  final bool canFinish;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepCard(
      stepIndex: 3,
      onBack: onBack,
      emoji: '🧒',
      iconColor: _childColor,
      title: l10n.createChildTitle,
      subtitle: l10n.createChildSubtitle,
      body: ChildForm(onChanged: onChanged),
      button: _PrimaryButton(
        label: l10n.done,
        trailing: const Text('🎉', style: TextStyle(fontSize: 18)),
        onPressed: canFinish ? onFinish : null,
      ),
    );
  }
}
