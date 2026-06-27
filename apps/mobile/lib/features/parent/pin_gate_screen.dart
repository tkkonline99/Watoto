import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';

/// PIN gate protecting the parent zone (docs/16 §16.1). Kids can't reach
/// settings, consent, or profile management without the parent PIN.
class PinGateScreen extends ConsumerStatefulWidget {
  const PinGateScreen({super.key});

  @override
  ConsumerState<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends ConsumerState<PinGateScreen> {
  final _pin = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    final store = ref.read(offlineStoreProvider);
    if (store.verifyPin(_pin.text)) {
      ref.read(sessionProvider.notifier).unlockParent();
      context.go('/parent');
    } else {
      setState(() => _error = true);
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: WatotoColors.deep),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔐', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(l10n.enterPinTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(l10n.enterPinSubtitle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                // obscureText + number keyboard drops keystrokes on many
                // Android IMEs unless suggestions/autocorrect are off
                // (flutter#67391).
                enableSuggestions: false,
                autocorrect: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                textAlign: TextAlign.center,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: _error ? l10n.wrongPin : null,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: Text(l10n.unlock)),
            ],
          ),
        ),
      ),
    );
  }
}
