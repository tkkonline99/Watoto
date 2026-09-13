/// Domain barrel — pure models, rules, and ports.
library;

export 'models/child_profile.dart';
export 'models/consent.dart';
export 'ports/auth_port.dart';
export 'ports/repositories.dart';
export 'rules/economy.dart';
export 'rules/levels.dart';
export 'rules/stars.dart';
export 'rules/streak.dart'
    show
        nextStreak,
        nextStreakTick,
        StreakTick,
        isoWeekKey,
        liveStreak,
        dayKeyOf,
        dayKeyBefore;
export 'rules/username.dart';
