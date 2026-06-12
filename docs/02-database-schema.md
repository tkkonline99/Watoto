# 2. Database Schema (PostgreSQL 16)

Conventions: `uuid` PKs (`gen_random_uuid()`), `created_at`/`updated_at timestamptz NOT NULL DEFAULT now()` on every table (omitted below for brevity), soft deletes only where compliance requires (`deleted_at`), all FKs indexed. Enum types are real Postgres enums. Multi-language text lives in `translations`, not in wide columns.

```sql
-- ============ ENUMS ============
CREATE TYPE user_role AS ENUM ('child','parent','teacher','admin','super_admin');
CREATE TYPE age_band AS ENUM ('0_2','3_5','6_8','9_10');
CREATE TYPE locale_code AS ENUM ('en','sw','fr');
CREATE TYPE content_status AS ENUM ('draft','in_review','approved','published','archived');
CREATE TYPE lesson_type AS ENUM ('interactive','video','audio','reading','activity');
CREATE TYPE question_type AS ENUM ('multiple_choice','true_false','match','order','fill_blank','tap_image','audio_choice');
CREATE TYPE media_type AS ENUM ('image','audio','video','rive','lottie','document');
CREATE TYPE plan_code AS ENUM ('free','premium_monthly','premium_annual');
CREATE TYPE sub_status AS ENUM ('active','grace','on_hold','paused','canceled','expired');
CREATE TYPE pay_provider AS ENUM ('apple','google','stripe');
CREATE TYPE reward_kind AS ENUM ('star','coin','xp');
CREATE TYPE progress_status AS ENUM ('not_started','in_progress','completed','mastered');
CREATE TYPE sync_op_type AS ENUM ('lesson_progress','quiz_attempt','reward_event','reading_attempt','streak_tick');
CREATE TYPE consent_kind AS ENUM ('coppa_parental','gdprk_processing','leaderboard','ai_features','voice_recording','marketing_email');
CREATE TYPE moderation_state AS ENUM ('pending','approved','rejected');

-- ============ IDENTITY & ACCOUNTS ============
CREATE TABLE users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid    text UNIQUE NOT NULL,
  email           citext UNIQUE,                 -- null for child accounts
  role            user_role NOT NULL,
  display_name    text NOT NULL,
  locale          locale_code NOT NULL DEFAULT 'en',
  is_active       boolean NOT NULL DEFAULT true,
  deleted_at      timestamptz                    -- compliance soft-delete
);

CREATE TABLE parent_pins (
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  pin_hash    text NOT NULL,                     -- argon2id
  failed_attempts int NOT NULL DEFAULT 0,
  locked_until timestamptz
);

CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  text NOT NULL,
  device_id   text NOT NULL,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz
);
CREATE INDEX ON refresh_tokens (user_id, device_id);

CREATE TABLE child_profiles (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id     uuid NOT NULL REFERENCES users(id),
  user_id       uuid UNIQUE REFERENCES users(id), -- child login identity (optional for 0-2)
  nickname      text NOT NULL,                    -- never legal name (data minimization)
  avatar_key    text NOT NULL DEFAULT 'lion_01',
  birth_month   date NOT NULL,                    -- month precision only
  age_band      age_band NOT NULL,
  learning_locale locale_code NOT NULL DEFAULT 'en',
  settings      jsonb NOT NULL DEFAULT '{}',      -- a11y prefs, audio-first, etc.
  deleted_at    timestamptz
);
CREATE INDEX ON child_profiles (parent_id);

CREATE TABLE teacher_profiles (
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  school_name text,
  verified_at timestamptz
);

-- ============ CURRICULUM ============
CREATE TABLE subjects (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug      text UNIQUE NOT NULL,                 -- 'math', 'phonics', ...
  icon_key  text NOT NULL,
  sort      int NOT NULL DEFAULT 0
);

CREATE TABLE courses (                            -- subject × age_band, e.g. "Math 6-8"
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id uuid NOT NULL REFERENCES subjects(id),
  age_band   age_band NOT NULL,
  slug       text UNIQUE NOT NULL,
  sort       int NOT NULL DEFAULT 0,
  status     content_status NOT NULL DEFAULT 'draft',
  UNIQUE (subject_id, age_band)
);

CREATE TABLE units (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES courses(id),
  slug      text NOT NULL,
  sort      int NOT NULL DEFAULT 0,
  UNIQUE (course_id, slug)
);

CREATE TABLE lessons (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id       uuid NOT NULL REFERENCES units(id),
  slug          text NOT NULL,
  lesson_type   lesson_type NOT NULL,
  difficulty    smallint NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
  est_minutes   smallint NOT NULL DEFAULT 5,
  is_premium    boolean NOT NULL DEFAULT false,
  skills        text[] NOT NULL DEFAULT '{}',     -- skill tags for mastery/adaptive
  status        content_status NOT NULL DEFAULT 'draft',
  current_version_id uuid,                        -- FK added after lesson_versions
  sort          int NOT NULL DEFAULT 0,
  UNIQUE (unit_id, slug)
);

CREATE TABLE lesson_versions (                    -- immutable published payloads
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id   uuid NOT NULL REFERENCES lessons(id),
  version     int NOT NULL,
  body        jsonb NOT NULL,                     -- validated against content_schema JSON Schema
  content_hash text NOT NULL,                     -- sha256 of body+media; CDN cache key
  published_at timestamptz,
  published_by uuid REFERENCES users(id),
  UNIQUE (lesson_id, version)
);
ALTER TABLE lessons ADD FOREIGN KEY (current_version_id) REFERENCES lesson_versions(id);

-- ============ CONTENT: QUIZ / FLASHCARD / STORY / GAME / ACTIVITY ============
CREATE TABLE quizzes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id   uuid REFERENCES lessons(id),        -- nullable: standalone quizzes exist
  unit_id     uuid REFERENCES units(id),
  slug        text UNIQUE NOT NULL,
  pass_pct    smallint NOT NULL DEFAULT 70,
  is_premium  boolean NOT NULL DEFAULT false,
  status      content_status NOT NULL DEFAULT 'draft'
);

CREATE TABLE questions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id      uuid NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  qtype        question_type NOT NULL,
  body         jsonb NOT NULL,        -- prompt, options, correct, media refs, per-option audio
  skills       text[] NOT NULL DEFAULT '{}',
  difficulty   smallint NOT NULL DEFAULT 1,
  sort         int NOT NULL DEFAULT 0
);

CREATE TABLE flashcard_decks (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  uuid NOT NULL REFERENCES courses(id),
  slug       text UNIQUE NOT NULL,
  is_premium boolean NOT NULL DEFAULT false,
  status     content_status NOT NULL DEFAULT 'draft'
);

CREATE TABLE flashcards (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deck_id   uuid NOT NULL REFERENCES flashcard_decks(id) ON DELETE CASCADE,
  front     jsonb NOT NULL,           -- {text_key, image, audio}
  back      jsonb NOT NULL,
  sort      int NOT NULL DEFAULT 0
);

CREATE TABLE stories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text UNIQUE NOT NULL,
  age_band    age_band NOT NULL,
  reading_level smallint NOT NULL DEFAULT 1,
  is_premium  boolean NOT NULL DEFAULT false,
  status      content_status NOT NULL DEFAULT 'draft'
);

CREATE TABLE story_pages (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id  uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  page_no   int NOT NULL,
  body      jsonb NOT NULL,           -- text keys, illustration, narration audio per locale, word-highlight timings
  UNIQUE (story_id, page_no)
);

CREATE TABLE games (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text UNIQUE NOT NULL,
  engine      text NOT NULL,          -- 'builtin:match', 'builtin:trace', 'rive:xyz'
  age_band    age_band NOT NULL,
  subject_id  uuid REFERENCES subjects(id),
  config      jsonb NOT NULL,
  is_premium  boolean NOT NULL DEFAULT false,
  status      content_status NOT NULL DEFAULT 'draft'
);

CREATE TABLE activities (               -- creativity / printable / guided activities
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       text UNIQUE NOT NULL,
  age_band   age_band NOT NULL,
  subject_id uuid REFERENCES subjects(id),
  body       jsonb NOT NULL,
  is_premium boolean NOT NULL DEFAULT false,
  status     content_status NOT NULL DEFAULT 'draft'
);

CREATE TABLE media_assets (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_type   media_type NOT NULL,
  s3_key       text UNIQUE NOT NULL,
  cdn_url      text NOT NULL,
  mime         text NOT NULL,
  bytes        bigint NOT NULL,
  duration_ms  int,
  alt_text_key text,                  -- translation key for a11y
  checksum     text NOT NULL,
  moderation   moderation_state NOT NULL DEFAULT 'pending',
  uploaded_by  uuid NOT NULL REFERENCES users(id)
);

-- ============ I18N ============
CREATE TABLE translations (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  t_key     text NOT NULL,            -- 'lesson.<uuid>.title', 'ui.home.greeting'
  locale    locale_code NOT NULL,
  value     text NOT NULL,
  audio_asset_id uuid REFERENCES media_assets(id),  -- pronunciation/TTS audio
  status    content_status NOT NULL DEFAULT 'draft',
  UNIQUE (t_key, locale)
);
CREATE INDEX translations_fts ON translations USING gin (to_tsvector('simple', value));

-- ============ LEARNING PROGRESS ============
CREATE TABLE lesson_progress (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id    uuid NOT NULL REFERENCES child_profiles(id),
  lesson_id   uuid NOT NULL REFERENCES lessons(id),
  status      progress_status NOT NULL DEFAULT 'not_started',
  score_pct   smallint,
  time_spent_s int NOT NULL DEFAULT 0,
  completed_at timestamptz,
  client_updated_at timestamptz NOT NULL,   -- LWW conflict resolution
  UNIQUE (child_id, lesson_id)
);

CREATE TABLE quiz_attempts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id    uuid NOT NULL REFERENCES child_profiles(id),
  quiz_id     uuid NOT NULL REFERENCES quizzes(id),
  score_pct   smallint NOT NULL,
  passed      boolean NOT NULL,
  answers     jsonb NOT NULL,               -- per-question responses for analytics
  duration_s  int NOT NULL,
  attempted_at timestamptz NOT NULL,
  client_op_id uuid UNIQUE NOT NULL          -- idempotency from offline sync
) PARTITION BY RANGE (attempted_at);

CREATE TABLE skill_mastery (
  child_id   uuid NOT NULL REFERENCES child_profiles(id),
  skill      text NOT NULL,
  mastery    real NOT NULL DEFAULT 0,        -- 0..1 (Bayesian Knowledge Tracing P(known))
  attempts   int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (child_id, skill)
);

CREATE TABLE streaks (
  child_id      uuid PRIMARY KEY REFERENCES child_profiles(id),
  current_days  int NOT NULL DEFAULT 0,
  longest_days  int NOT NULL DEFAULT 0,
  last_active_date date NOT NULL
);

CREATE TABLE daily_challenges (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id  uuid NOT NULL REFERENCES child_profiles(id),
  for_date  date NOT NULL,
  items     jsonb NOT NULL,                  -- generated set of lesson/quiz/game refs
  completed boolean NOT NULL DEFAULT false,
  UNIQUE (child_id, for_date)
);

CREATE TABLE reading_attempts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id   uuid NOT NULL REFERENCES child_profiles(id),
  story_id   uuid REFERENCES stories(id),
  audio_s3_key text,                          -- retained max 30 days (compliance)
  transcript text,
  scores     jsonb,                           -- {accuracy, fluency, per_word:[...]}
  attempted_at timestamptz NOT NULL
);

-- ============ GAMIFICATION ============
CREATE TABLE reward_ledger (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id   uuid NOT NULL REFERENCES child_profiles(id),
  kind       reward_kind NOT NULL,
  delta      int NOT NULL,                    -- +earn / -spend
  reason     text NOT NULL,                   -- 'lesson_completed', 'shop_avatar', ...
  ref_id     uuid,
  client_op_id uuid UNIQUE,
  occurred_at timestamptz NOT NULL DEFAULT now()
) PARTITION BY RANGE (occurred_at);

CREATE TABLE badges (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug      text UNIQUE NOT NULL,
  criteria  jsonb NOT NULL,                   -- rules engine spec
  icon_asset_id uuid REFERENCES media_assets(id)
);

CREATE TABLE earned_badges (
  child_id  uuid NOT NULL REFERENCES child_profiles(id),
  badge_id  uuid NOT NULL REFERENCES badges(id),
  earned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (child_id, badge_id)
);

CREATE TABLE certificates (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id  uuid NOT NULL REFERENCES child_profiles(id),
  course_id uuid NOT NULL REFERENCES courses(id),
  pdf_s3_key text NOT NULL,
  issued_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (child_id, course_id)
);

CREATE TABLE leaderboard_optins (              -- parental approval gate
  child_id    uuid PRIMARY KEY REFERENCES child_profiles(id),
  approved_by uuid NOT NULL REFERENCES users(id),
  approved_at timestamptz NOT NULL DEFAULT now()
);
-- live leaderboards are Redis sorted sets, snapshotted weekly into report_snapshots

-- ============ CLASSROOM ============
CREATE TABLE groups (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id uuid NOT NULL REFERENCES users(id),
  name       text NOT NULL,
  join_code  text UNIQUE NOT NULL               -- parent enters code to link child
);

CREATE TABLE group_members (
  group_id   uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  child_id   uuid NOT NULL REFERENCES child_profiles(id),
  approved_by uuid NOT NULL REFERENCES users(id),  -- parent approval mandatory
  PRIMARY KEY (group_id, child_id)
);

CREATE TABLE assignments (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id  uuid NOT NULL REFERENCES groups(id),
  items     jsonb NOT NULL,                    -- lesson/quiz refs
  due_at    timestamptz,
  created_by uuid NOT NULL REFERENCES users(id)
);

CREATE TABLE assignment_submissions (
  assignment_id uuid NOT NULL REFERENCES assignments(id),
  child_id      uuid NOT NULL REFERENCES child_profiles(id),
  progress      jsonb NOT NULL DEFAULT '{}',
  completed_at  timestamptz,
  PRIMARY KEY (assignment_id, child_id)
);

-- ============ BILLING ============
CREATE TABLE plans (
  code        plan_code PRIMARY KEY,
  features    jsonb NOT NULL,
  price_usd_cents int NOT NULL,
  store_product_ids jsonb NOT NULL              -- {apple, google, stripe_price}
);

CREATE TABLE subscriptions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id    uuid NOT NULL REFERENCES users(id),
  plan         plan_code NOT NULL,
  provider     pay_provider NOT NULL,
  provider_ref text NOT NULL,                   -- originalTransactionId / purchaseToken / stripe sub id
  status       sub_status NOT NULL,
  current_period_end timestamptz NOT NULL,
  canceled_at  timestamptz,
  UNIQUE (provider, provider_ref)
);
CREATE INDEX ON subscriptions (parent_id, status);

CREATE TABLE payment_events (                   -- raw webhook/notification archive
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider    pay_provider NOT NULL,
  event_type  text NOT NULL,
  payload     jsonb NOT NULL,
  processed_at timestamptz
);

-- ============ SYNC / SAFETY / ADMIN ============
CREATE TABLE sync_ops (                         -- server-side archive of applied client ops
  client_op_id uuid PRIMARY KEY,
  child_id     uuid NOT NULL REFERENCES child_profiles(id),
  op_type      sync_op_type NOT NULL,
  payload      jsonb NOT NULL,
  device_id    text NOT NULL,
  applied_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE download_manifests (               -- versioned offline pack descriptors
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope        text NOT NULL,                   -- 'course:<id>', 'story:<id>'
  content_hash text NOT NULL,
  manifest     jsonb NOT NULL,                  -- file list + sizes + hashes
  UNIQUE (scope, content_hash)
);

CREATE TABLE consents (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id   uuid NOT NULL REFERENCES users(id),
  child_id    uuid REFERENCES child_profiles(id),
  kind        consent_kind NOT NULL,
  granted     boolean NOT NULL,
  method      text NOT NULL,                    -- 'verified_card', 'email_plus', ...
  recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON consents (parent_id, child_id, kind, recorded_at DESC);

CREATE TABLE screen_time_policies (
  child_id    uuid PRIMARY KEY REFERENCES child_profiles(id),
  daily_minutes int NOT NULL DEFAULT 60,
  allowed_windows jsonb NOT NULL DEFAULT '[]',  -- [{dow, start, end}]
  set_by      uuid NOT NULL REFERENCES users(id)
);

CREATE TABLE moderation_items (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity     text NOT NULL,                     -- 'lesson:<id>', 'media:<id>'
  state      moderation_state NOT NULL DEFAULT 'pending',
  reviewer_id uuid REFERENCES users(id),
  notes      text,
  reviewed_at timestamptz
);

CREATE TABLE audit_logs (
  id         bigserial,
  actor_id   uuid,
  action     text NOT NULL,                     -- 'lesson.publish', 'user.delete', ...
  entity     text NOT NULL,
  before     jsonb,
  after      jsonb,
  ip         inet,
  at         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, at)
) PARTITION BY RANGE (at);

CREATE TABLE platform_settings (
  key   text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_by uuid REFERENCES users(id)
);

CREATE TABLE ai_sessions (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id  uuid NOT NULL REFERENCES child_profiles(id),
  feature   text NOT NULL,                      -- 'tutor','reading_coach','insights'
  turns     int NOT NULL DEFAULT 0,
  tokens_in int NOT NULL DEFAULT 0,
  tokens_out int NOT NULL DEFAULT 0,
  flagged   boolean NOT NULL DEFAULT false
);
```

## Indexing & Performance Notes

```sql
CREATE INDEX ON lesson_progress (child_id, status);
CREATE INDEX ON quiz_attempts (child_id, attempted_at DESC);
CREATE INDEX ON reward_ledger (child_id, kind, occurred_at DESC);
CREATE INDEX ON lessons (unit_id, status, sort);
CREATE INDEX ON stories (age_band, status, reading_level);
CREATE INDEX ON assignments (group_id, due_at);
```

- **Partitioned monthly**: `quiz_attempts`, `reward_ledger`, `audit_logs` (pg_partman). Retention jobs drop expired partitions per the [retention policy](17-compliance.md).
- **Balances** (stars/coins/XP totals) are materialized in Redis (`HINCRBY child:{id} coins delta`) with the ledger as source of truth; a nightly job reconciles.
- **Search**: Postgres FTS over `translations.value` joined to content tables, filtered by locale + age_band + status='published'.
- **Read models**: `reporting` owns materialized views `mv_child_weekly_stats`, `mv_group_progress`, refreshed by worker every 15 min.

## Data Dictionary Highlights (compliance-sensitive fields)

| Field | Why constrained |
|-------|-----------------|
| `child_profiles.nickname` | Data minimization — never collect child legal names |
| `child_profiles.birth_month` | Month precision only; full DOB not collected |
| `reading_attempts.audio_s3_key` | Voice recordings auto-purged ≤30 days; requires `voice_recording` consent |
| `consents.method` | COPPA verifiable parental consent method must be recorded |
| `users.deleted_at` + erasure job | GDPR-K Art. 17 deletion pipeline ([details](17-compliance.md)) |
