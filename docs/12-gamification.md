# 12. Gamification Architecture

Design stance: gamification reinforces *learning behaviors* (effort, consistency, mastery), never raw screen time. No loot boxes, no real-money currency purchase, no pressure mechanics (countdown scarcity, FOMO). Variable rewards are mild and capped.

## 12.1 Currencies

| Currency | Earned by | Spent on | Notes |
|---|---|---|---|
| **XP** | Any completed learning item (lesson 10, quiz 5–20 by score, story read 8, challenge 15) | Never spent — drives Level | Mastery bonus ×1.5 when a skill crosses 0.95 |
| **Stars** | Quality: quiz ≥70% = 1★, ≥90% = 2★, 100% = 3★ per item | Never spent — fill course constellations → certificates | Visible quality signal for parents |
| **Coins** | Daily challenge (5), streak milestones, badge unlocks | Avatar shop: outfits, mascot accessories, home themes | Cosmetic only; earn rate capped 30/day |

All grants flow through `reward_ledger` (append-only, idempotent by `client_op_id`); balances cached in Redis, reconciled nightly.

## 12.2 Levels & Streaks

- Level n requires `100 × n^1.4` cumulative XP (L2=264, L5=950, L10=2512…) — fast early wins, steady later.
- Levels unlock cosmetics + new Kibo animations, never learning content (content gating is curriculum/premium only).
- Streak = a day with ≥1 completed learning item. Milestones 3/7/14/30/60/100 days → coins + badges. **One free "streak shield" per week** auto-applied (miss a day without losing streak) — kindness over compulsion. Streak prompts never use guilt language.

## 12.3 Badges (rules-engine driven)

`badges.criteria` JSONB evaluated by the gamification worker on domain events:

```json
{ "event": "QuizGraded", "all": [
    {"fact": "scorePct", "op": ">=", "value": 100},
    {"fact": "subjectSlug", "op": "==", "value": "math"},
    {"fact": "countInWindow", "window": "all_time", "op": ">=", "value": 10}
] }
```

Launch catalog (~40): First Steps, Bookworm (10/50/100 stories), Math Whiz tiers, Phonics Hero, Streak tiers, Polyglot (lesson in 2nd language), Scientist, Helper (social-skills unit), Explorer (every subject sampled), Champion (course certificate).

## 12.4 Certificates

Course completion (all units ≥70% + course quiz) → `certificate-pdf` job renders localized PDF (child nickname, course, date, signature art) → stored in S3 → parent notified, shareable/printable from Parent Zone.

## 12.5 Social Layer (parent-gated)

- **Leaderboards**: weekly XP, opt-in via parent approval (`leaderboard_optins`). Scopes: family (default), class group, country cohort (random 30-child shards so no one is rank 4,000). Nickname + avatar only. Redis sorted sets: `ZINCRBY lb:{scope}:{isoweek} xp child:{id}`; reset weekly with top-3 celebration.
- **Challenges**: parent or teacher initiates "read 5 stories this week" between siblings/classmates.
- **Learning clubs** (Phase 2): teacher-moderated, content-reaction only — no free text between children, ever.

## 12.6 Healthy-Use Safeguards

| Mechanism | Behavior |
|---|---|
| Screen-time policy | soft-lock with Kibo "rest" screen at parent-set daily limit |
| Reward cool-down | celebration animations shorten after 5th in a session |
| No push to children | streak/challenge reminders go to *parents* only, off by default |
| Daily coin cap | prevents grind loops |
| Session nudge | after 25 min continuous, Kibo suggests a stretch break (band <6: 15 min) |

## 12.7 Event Wiring

```
LessonCompleted ─┬→ XP/star grant → ledger → balance cache
                 ├→ badge rules eval
                 ├→ streak tick (idempotent per day)
                 ├→ leaderboard ZINCRBY (if opted in)
                 └→ adaptive engine signal
QuizGraded, StoryFinished, ChallengeCompleted → same pipeline
CourseCompleted → certificate job + Champion badge + parent notification
```
