import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../l10n/gen/app_localizations.dart';
import 'child_form.dart';

/// Add another child profile, reachable from the picker or the parent zone.
class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  ChildFormValue? _value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = _value?.isValid ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addChild)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: ChildForm(onChanged: (v) => setState(() => _value = v)),
                ),
              ),
              FilledButton(
                onPressed: canSave
                    ? () async {
                        final v = _value!;
                        await ref.read(sessionProvider.notifier).addChild(
                              nickname: v.nickname,
                              avatarKey: v.avatarKey,
                              birthYear: v.birthYear,
                            );
                        if (context.mounted) context.go('/profiles');
                      }
                    : null,
                child: Text(l10n.done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
