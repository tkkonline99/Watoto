# 3. ER Diagrams

Mermaid `erDiagram` views grouped by domain. Cardinality reads left-to-right (e.g. `||--o{` = one-to-many).

## 3.1 Identity & Family

```mermaid
erDiagram
    USERS ||--o| PARENT_PINS : "secures"
    USERS ||--o{ REFRESH_TOKENS : "holds"
    USERS ||--o{ CHILD_PROFILES : "parents"
    USERS ||--o| TEACHER_PROFILES : "extends"
    CHILD_PROFILES |o--o| USERS : "child login identity"
    USERS ||--o{ CONSENTS : "grants"
    CHILD_PROFILES ||--o{ CONSENTS : "subject of"
    CHILD_PROFILES ||--o| SCREEN_TIME_POLICIES : "limited by"

    USERS { uuid id PK; text firebase_uid UK; citext email UK; user_role role; locale_code locale }
    CHILD_PROFILES { uuid id PK; uuid parent_id FK; text nickname; date birth_month; age_band age_band }
    CONSENTS { uuid id PK; consent_kind kind; boolean granted; text method }
```

## 3.2 Curriculum & Content

```mermaid
erDiagram
    SUBJECTS ||--o{ COURSES : "offered as"
    COURSES ||--o{ UNITS : "contains"
    UNITS ||--o{ LESSONS : "contains"
    LESSONS ||--o{ LESSON_VERSIONS : "versioned as"
    LESSONS ||--o{ QUIZZES : "assessed by"
    QUIZZES ||--o{ QUESTIONS : "contains"
    COURSES ||--o{ FLASHCARD_DECKS : "has"
    FLASHCARD_DECKS ||--o{ FLASHCARDS : "contains"
    STORIES ||--o{ STORY_PAGES : "contains"
    SUBJECTS ||--o{ GAMES : "categorizes"
    SUBJECTS ||--o{ ACTIVITIES : "categorizes"
    MEDIA_ASSETS ||--o{ TRANSLATIONS : "narrates"

    COURSES { uuid id PK; uuid subject_id FK; age_band age_band; content_status status }
    LESSONS { uuid id PK; uuid unit_id FK; lesson_type type; smallint difficulty; boolean is_premium; text[] skills }
    LESSON_VERSIONS { uuid id PK; uuid lesson_id FK; int version; jsonb body; text content_hash }
    TRANSLATIONS { uuid id PK; text t_key; locale_code locale; text value; uuid audio_asset_id FK }
```

## 3.3 Learning & Progress

```mermaid
erDiagram
    CHILD_PROFILES ||--o{ LESSON_PROGRESS : "tracks"
    CHILD_PROFILES ||--o{ QUIZ_ATTEMPTS : "makes"
    CHILD_PROFILES ||--o{ SKILL_MASTERY : "accumulates"
    CHILD_PROFILES ||--o| STREAKS : "maintains"
    CHILD_PROFILES ||--o{ DAILY_CHALLENGES : "receives"
    CHILD_PROFILES ||--o{ READING_ATTEMPTS : "records"
    LESSONS ||--o{ LESSON_PROGRESS : "measured by"
    QUIZZES ||--o{ QUIZ_ATTEMPTS : "measured by"
    STORIES ||--o{ READING_ATTEMPTS : "read in"

    LESSON_PROGRESS { uuid child_id FK; uuid lesson_id FK; progress_status status; smallint score_pct; timestamptz client_updated_at }
    QUIZ_ATTEMPTS { uuid id PK; smallint score_pct; boolean passed; jsonb answers; uuid client_op_id UK }
    SKILL_MASTERY { uuid child_id PK; text skill PK; real mastery }
```

## 3.4 Gamification

```mermaid
erDiagram
    CHILD_PROFILES ||--o{ REWARD_LEDGER : "earns/spends"
    CHILD_PROFILES ||--o{ EARNED_BADGES : "earns"
    BADGES ||--o{ EARNED_BADGES : "awarded as"
    CHILD_PROFILES ||--o{ CERTIFICATES : "awarded"
    COURSES ||--o{ CERTIFICATES : "completion of"
    CHILD_PROFILES ||--o| LEADERBOARD_OPTINS : "opted in (parent approved)"

    REWARD_LEDGER { uuid id PK; reward_kind kind; int delta; text reason; uuid client_op_id UK }
    BADGES { uuid id PK; text slug UK; jsonb criteria }
```

## 3.5 Classroom

```mermaid
erDiagram
    USERS ||--o{ GROUPS : "teaches"
    GROUPS ||--o{ GROUP_MEMBERS : "enrolls"
    CHILD_PROFILES ||--o{ GROUP_MEMBERS : "joins (parent approved)"
    GROUPS ||--o{ ASSIGNMENTS : "receives"
    ASSIGNMENTS ||--o{ ASSIGNMENT_SUBMISSIONS : "submitted as"
    CHILD_PROFILES ||--o{ ASSIGNMENT_SUBMISSIONS : "submits"

    GROUPS { uuid id PK; uuid teacher_id FK; text join_code UK }
    GROUP_MEMBERS { uuid group_id PK; uuid child_id PK; uuid approved_by FK }
```

## 3.6 Billing & Entitlements

```mermaid
erDiagram
    PLANS ||--o{ SUBSCRIPTIONS : "purchased as"
    USERS ||--o{ SUBSCRIPTIONS : "owns"
    SUBSCRIPTIONS ||--o{ PAYMENT_EVENTS : "driven by"

    SUBSCRIPTIONS { uuid id PK; plan_code plan; pay_provider provider; text provider_ref; sub_status status; timestamptz current_period_end }
    PLANS { plan_code code PK; jsonb features; int price_usd_cents }
```

## 3.7 Sync, Safety, Admin

```mermaid
erDiagram
    CHILD_PROFILES ||--o{ SYNC_OPS : "uploads"
    USERS ||--o{ AUDIT_LOGS : "acts in"
    USERS ||--o{ MODERATION_ITEMS : "reviews"
    CHILD_PROFILES ||--o{ AI_SESSIONS : "uses"

    SYNC_OPS { uuid client_op_id PK; sync_op_type op_type; jsonb payload; text device_id }
    AUDIT_LOGS { bigserial id PK; uuid actor_id; text action; jsonb before; jsonb after }
    AI_SESSIONS { uuid id PK; text feature; int tokens_in; int tokens_out; boolean flagged }
```
