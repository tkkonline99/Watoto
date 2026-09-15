import 'package:flutter/material.dart';

import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'curriculum_i18n.dart';
import 'curriculum_models.dart';

/// Asks the child to pick an age, then returns the matching curriculum stage.
/// Only [stages] are offered, so a subject never lands on an age that has no
/// content for it. Returns null if dismissed.
Future<CurriculumStage?> showAgePicker(
  BuildContext context, {
  required List<CurriculumStage> stages,
  String? heading,
}) {
  return showModalBottomSheet<CurriculumStage>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heading != null) ...[
                Text(heading,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: WatotoColors.sky)),
                const SizedBox(height: 4),
              ],
              Text(l10n.selectAgeTitle,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(l10n.selectAgeSubtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: stages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final stage = stages[i];
                    return _AgeTile(
                      stage: stage,
                      label: l10n.ageBandLabel(stage.ageRange),
                      onTap: () => Navigator.of(context).pop(stage),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AgeTile extends StatelessWidget {
  const _AgeTile({required this.stage, required this.label, required this.onTap});

  final CurriculumStage stage;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Band and grade names are curriculum data, English at the source.
    final subtitle = localizedCurriculum(
      stage.grade ?? stage.band,
      AppLocalizations.of(context).localeName,
    );
    return Semantics(
      button: true,
      label: '$label. $subtitle',
      child: ExcludeSemantics(child: _tile(subtitle)),
    );
  }

  Widget _tile(String subtitle) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WatotoColors.sky.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: WatotoColors.sun,
              foregroundColor: WatotoColors.deep,
              child: Text('${stage.minAge}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: WatotoColors.deep)),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: WatotoColors.deep),
          ],
        ),
      ),
    );
  }
}
