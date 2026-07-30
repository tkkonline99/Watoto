/// Parental consent captured at onboarding (docs/17-compliance.md).
/// Pure domain model — no Flutter imports.
library;

/// `coreData` is required to use the app; `aiFeatures` and `voiceRecording`
/// are optional and default OFF (privacy by default).
class ConsentRecord {
  const ConsentRecord({
    required this.coreData,
    required this.aiFeatures,
    required this.voiceRecording,
    required this.recordedAt,
    this.policyVersion = 1,
  });

  final bool coreData;
  final bool aiFeatures;
  final bool voiceRecording;
  final DateTime? recordedAt;
  final int policyVersion;

  static const empty = ConsentRecord(
    coreData: false,
    aiFeatures: false,
    voiceRecording: false,
    recordedAt: null,
  );

  ConsentRecord copyWith({
    bool? coreData,
    bool? aiFeatures,
    bool? voiceRecording,
  }) =>
      ConsentRecord(
        coreData: coreData ?? this.coreData,
        aiFeatures: aiFeatures ?? this.aiFeatures,
        voiceRecording: voiceRecording ?? this.voiceRecording,
        recordedAt: DateTime.now().toUtc(),
        policyVersion: policyVersion,
      );

  Map<String, dynamic> toJson() => {
        'coreData': coreData,
        'aiFeatures': aiFeatures,
        'voiceRecording': voiceRecording,
        'recordedAt': recordedAt?.toIso8601String(),
        'policyVersion': policyVersion,
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
        coreData: json['coreData'] as bool? ?? false,
        aiFeatures: json['aiFeatures'] as bool? ?? false,
        voiceRecording: json['voiceRecording'] as bool? ?? false,
        recordedAt: json['recordedAt'] == null
            ? null
            : DateTime.parse(json['recordedAt'] as String),
        policyVersion: json['policyVersion'] as int? ?? 1,
      );
}

/// Consent policy version string shared with backend Cloud Functions.
const consentPolicyVersion = '2026-06-01';
