import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'auth_service.dart';
import 'parent_gate.dart';

/// Shows the FTC-style parent gate. Returns true if the adult passed.
///
/// Draws a new number each time it opens. It used to read one challenge for
/// the whole run, so a child who had watched a grown-up answer it once could
/// type the same three digits to reach PIN or password recovery.
Future<bool> showParentGateDialog(BuildContext context, WidgetRef ref) async {
  ref.invalidate(parentGateChallengeProvider);
  final challenge = ref.read(parentGateChallengeProvider);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ParentGateDialog(challenge: challenge),
  );
  return result == true;
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog({required this.challenge});

  final ParentGateChallenge challenge;

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    if (checkParentGate(_controller.text, widget.challenge)) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = l10n.parentGateWrong);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        l10n.parentGateTitle,
        style: const TextStyle(
          fontFamily: 'Baloo2',
          fontWeight: FontWeight.w800,
          color: WatotoColors.deep,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.parentGateBody(
            widget.challenge.promptIn(l10n.localeName),
          )),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(l10n),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _submit(l10n),
          child: Text(l10n.next),
        ),
      ],
    );
  }
}
