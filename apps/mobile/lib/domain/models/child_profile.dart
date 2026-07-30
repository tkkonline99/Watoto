/// Age bands mirror the curriculum design (docs/06 / docs/11): 0-2, 3-5,
/// 6-8, 9-10. Stored per child and used to scope content.
///
/// Pure domain model — no Flutter or feature imports.
library;

/// Free avatar choices (emoji keys). Shop unlocks live in economy rules.
const avatarChoices = <String, String>{
  'lion': '🦁',
  'elephant': '🐘',
  'giraffe': '🦒',
  'zebra': '🦓',
  'hippo': '🦛',
  'monkey': '🐵',
};

enum AgeBand {
  b0_2('0-2'),
  b3_5('3-5'),
  b6_8('6-8'),
  b9_10('9-10');

  const AgeBand(this.label);
  final String label;
}

/// Derives the age band from a birth year. Year only (data minimization —
/// never a full DOB for a child). Ages above 10 clamp to the top band.
AgeBand ageBandForBirthYear(int birthYear, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  final age = (year - birthYear).clamp(0, 99);
  if (age <= 2) return AgeBand.b0_2;
  if (age <= 5) return AgeBand.b3_5;
  if (age <= 8) return AgeBand.b6_8;
  return AgeBand.b9_10;
}

String avatarEmoji(String key) {
  const shop = <String, String>{
    'parrot': '🦜',
    'turtle': '🐢',
    'fox': '🦊',
    'panda': '🐼',
    'tiger': '🐯',
    'owl': '🦉',
  };
  return avatarChoices[key] ?? shop[key] ?? '🦁';
}

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.nickname,
    required this.avatarKey,
    required this.birthYear,
    required this.ageBand,
    this.nicknameChangedAt,
  });

  final String id;
  final String nickname;
  final String avatarKey;
  final int birthYear;
  final AgeBand ageBand;

  /// Last time the parent changed [nickname] (UTC). Null = never changed after
  /// creation timestamp semantics — treated as changeable until first rename
  /// policy clocks start on first edit, or set at creation.
  final DateTime? nicknameChangedAt;

  String get emoji => avatarEmoji(avatarKey);

  ChildProfile copyWith({
    String? nickname,
    String? avatarKey,
    int? birthYear,
    AgeBand? ageBand,
    DateTime? nicknameChangedAt,
  }) =>
      ChildProfile(
        id: id,
        nickname: nickname ?? this.nickname,
        avatarKey: avatarKey ?? this.avatarKey,
        birthYear: birthYear ?? this.birthYear,
        ageBand: ageBand ?? this.ageBand,
        nicknameChangedAt: nicknameChangedAt ?? this.nicknameChangedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'avatarKey': avatarKey,
        'birthYear': birthYear,
        'ageBand': ageBand.name,
        if (nicknameChangedAt != null)
          'nicknameChangedAt': nicknameChangedAt!.toUtc().toIso8601String(),
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        avatarKey: json['avatarKey'] as String,
        birthYear: json['birthYear'] as int,
        ageBand: AgeBand.values.byName(json['ageBand'] as String),
        nicknameChangedAt: json['nicknameChangedAt'] == null
            ? null
            : DateTime.tryParse(json['nicknameChangedAt'] as String),
      );
}
