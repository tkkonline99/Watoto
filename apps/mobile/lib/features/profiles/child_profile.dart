/// Age bands mirror the curriculum design (docs/06 / docs/11): 0-2, 3-5,
/// 6-8, 9-10. Stored per child and used to scope content.
enum AgeBand {
  b0_2('0-2'),
  b3_5('3-5'),
  b6_8('6-8'),
  b9_10('9-10');

  const AgeBand(this.label);
  final String label;
}

/// Derives the age band from a birth year. We collect year only (data
/// minimization — never a full DOB for a child). Ages above 10 clamp to the
/// top band so older siblings can still use the app.
AgeBand ageBandForBirthYear(int birthYear, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  final age = (year - birthYear).clamp(0, 99);
  if (age <= 2) return AgeBand.b0_2;
  if (age <= 5) return AgeBand.b3_5;
  if (age <= 8) return AgeBand.b6_8;
  return AgeBand.b9_10;
}

/// Avatar choices are emoji keys (no image assets needed yet); the CMS will
/// later supply illustrated avatars behind the same `avatarKey`.
const avatarChoices = <String, String>{
  'lion': '🦁',
  'elephant': '🐘',
  'giraffe': '🦒',
  'zebra': '🦓',
  'hippo': '🦛',
  'monkey': '🐵',
};

String avatarEmoji(String key) => avatarChoices[key] ?? '🦁';

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.nickname,
    required this.avatarKey,
    required this.birthYear,
    required this.ageBand,
  });

  final String id;
  final String nickname;
  final String avatarKey;
  final int birthYear;
  final AgeBand ageBand;

  String get emoji => avatarEmoji(avatarKey);

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'avatarKey': avatarKey,
        'birthYear': birthYear,
        'ageBand': ageBand.name,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        avatarKey: json['avatarKey'] as String,
        birthYear: json['birthYear'] as int,
        ageBand: AgeBand.values.byName(json['ageBand'] as String),
      );
}
