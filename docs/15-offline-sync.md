# 15. Offline Synchronization Design

Principle: **the local store is the app's database; the server is the sync peer.** Reads never block on network. Writes commit locally first, always.

## 15.1 Client Data Layers

| Layer | Contents | Tech |
|---|---|---|
| Catalog cache | published content metadata + bodies (per locale) | Hive (JSON, hash-keyed) |
| Media packs | images/audio/video/rive for downloaded scopes | filesystem `packs/<scope>/<hash>/` |
| Learning state | progress, attempts, mastery mirror, balances | drift (SQLite) |
| Sync queue | outbound ops | drift table `sync_queue` |

## 15.2 Download Packs

- Unit of download = **scope**: `course:<id>` or `story:<id>` (quizzes/flashcards ride with their course).
- `GET /catalog/manifest?scope=` returns `{contentHash, files:[{url(signed), sha256, bytes}], totalBytes}`.
- DownloadManager: resumable (HTTP range), Wi-Fi-only option (default ON), per-file hash verification, atomic activation (pack visible only when complete), storage meter + LRU eviction suggestions in Settings.
- Premium packs use CloudFront signed URLs (24 h); entitlement checked at manifest time. Already-downloaded packs **keep working offline after expiry** but won't update (license note in ToS); next online entitlement check removes packs only on refund/chargeback.
- Updates: client compares manifest `contentHash` from `/sync/changes`; delta = fetch only changed files (hash-keyed names make this automatic).

## 15.3 Outbound Sync Queue

Every learning write is one transaction: domain row upsert + queue row insert.

```sql
-- drift table
CREATE TABLE sync_queue (
  client_op_id TEXT PRIMARY KEY,         -- uuid v7 (time-ordered)
  op_type TEXT NOT NULL,                 -- lesson_progress | quiz_attempt | reward_event | reading_attempt | streak_tick
  payload TEXT NOT NULL,                 -- JSON
  client_updated_at TEXT NOT NULL,       -- ISO, device clock + recorded server skew offset
  attempts INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' -- pending | inflight | done | rejected
);
```

Trigger points: connectivity regained, app foreground, 15-min background task (WorkManager / BGTaskScheduler), post-write debounce 10 s. Batch ≤200 ops, oldest first, exponential backoff on failure (max 1 h), `rejected` ops surfaced to diagnostics (never silently dropped).

## 15.4 Conflict Resolution

| Op type | Strategy |
|---|---|
| `lesson_progress` | **LWW** on `client_updated_at` per `(child, lesson)` — but status never regresses (`completed` beats later `in_progress`) and `score_pct` keeps max. Effectively LWW + monotonic merge guards |
| `quiz_attempt`, `reward_event`, `reading_attempt` | **Append-only** — no conflicts possible; idempotent by `client_op_id` (server unique index) |
| `streak_tick` | server recomputes from activity dates — client value advisory only |
| balances | derived from ledger, never synced directly |

Clock skew: client records `serverTime - deviceTime` from every API response header (`X-Server-Time`) and adjusts `client_updated_at`; skew >5 min also flagged in op metadata so the server can prefer its own receipt time.

Multi-device same-child: safe by construction — ledgers append, progress merges monotonic, LWW covers the rest. `conflict_server_won` results overwrite local rows from server payload included in the response.

## 15.5 Inbound Changes

`GET /sync/changes?since=<cursor>` (cursor = server sequence) returns ordered events: `entitlement_changed`, `assignment_created`, `content_version_bumped`, `badge_awarded`, `settings_changed` (screen time, consents). Client applies idempotently and persists the cursor. Called on app start, foreground, post-batch, and on FCM data-message nudge (`{type:'sync'}`) so teacher assignments and subscription changes arrive promptly.

## 15.6 Offline UX Rules

- Downloaded content indistinguishable from online (no degraded styling); non-downloaded premium shows download prompt instead of broken tiles.
- Offline banner only in Parent Zone (children just see their world working).
- AI features and leaderboards hidden offline (not erroring) — tutor button becomes Kibo's canned encouragement.
- First-run requires network (auth + consent + initial pack); after that, fully air-gapped learning works for downloaded scopes, including rewards and streaks.

## 15.7 Failure & Integrity

- Pack corruption (hash mismatch on open) → quarantine pack, prompt re-download, log to Crashlytics.
- `sync_queue` >5,000 ops or >30 days old → diagnostics warning surfaced in Parent Zone settings ("connect to internet to save progress").
- App uninstall loses unsynced ops — mitigated by the aggressive sync triggers above; documented as known limitation.
