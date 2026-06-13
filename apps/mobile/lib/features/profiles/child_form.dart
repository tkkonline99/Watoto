import 'package:flutter/material.dart';

import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'child_profile.dart';

/// Reusable nickname + avatar + birth-year picker, used in onboarding and
/// when a parent adds another child. Reports validity and values via [onChanged].
class ChildForm extends StatefulWidget {
  const ChildForm({super.key, required this.onChanged});

  final void Function(ChildFormValue value) onChanged;

  @override
  State<ChildForm> createState() => _ChildFormState();
}

class ChildFormValue {
  const ChildFormValue({
    required this.nickname,
    required this.avatarKey,
    required this.birthYear,
    required this.isValid,
  });

  final String nickname;
  final String avatarKey;
  final int birthYear;
  final bool isValid;
}

class _ChildFormState extends State<ChildForm> {
  final _controller = TextEditingController();
  String _avatar = avatarChoices.keys.first;
  late int _birthYear = DateTime.now().year - 5; // default age 5

  @override
  void initState() {
    super.initState();
    _controller.addListener(_emit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit() {
    final name = _controller.text.trim();
    widget.onChanged(ChildFormValue(
      nickname: name,
      avatarKey: _avatar,
      birthYear: _birthYear,
      isValid: name.isNotEmpty,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final year = DateTime.now().year;
    final age = year - _birthYear;
    final band = ageBandForBirthYear(_birthYear);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.childNickname, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: l10n.childNicknameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.chooseAvatar, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in avatarChoices.entries)
              GestureDetector(
                onTap: () => setState(() {
                  _avatar = entry.key;
                  _emit();
                }),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: _avatar == entry.key
                      ? WatotoColors.sun
                      : Colors.black12,
                  child: Text(entry.value, style: const TextStyle(fontSize: 28)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.childAge(age, band.label),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Slider(
          min: 0,
          max: 10,
          divisions: 10,
          value: age.clamp(0, 10).toDouble(),
          label: '$age',
          onChanged: (v) => setState(() {
            _birthYear = year - v.round();
            _emit();
          }),
        ),
      ],
    );
  }
}
