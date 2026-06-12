# 9. User Flows

## 9.1 First-Run Onboarding (Parent + Child Setup)

```mermaid
flowchart TD
    A[Launch] --> B[Language pick EN/SW/FR\nspoken + flags]
    B --> C{Has account?}
    C -- No --> D[Parent sign-up\nEmail / Google / Apple via Firebase]
    C -- Yes --> E[Sign in]
    D --> F[Age gate: confirm adult\nneutral DOB entry]
    F --> G[COPPA/GDPR-K consent screen\nplain-language, per-feature toggles:\ncore · AI features · voice recording]
    G --> H[Verifiable consent method\ncard micro-auth or email-plus]
    H --> I[Set parent PIN]
    I --> J[Create child profile\nnickname · avatar · birth month]
    J --> K[Age band auto-selected\nparent can override]
    K --> L{Add another child?}
    L -- Yes --> J
    L -- No --> M[Plan screen: continue Free / try Premium]
    M --> N[Child home]
```

Key rules: child never enters personal data; consent is granular and revocable in Parent Zone; declining AI/voice consent simply hides those features.

## 9.2 Child Daily Learning Loop

```mermaid
flowchart TD
    A[Profile picker\n'Who is learning?'] --> B[Child home: subject islands\n+ daily challenge + streak]
    B --> C{Pick}
    C --> D[Lesson player\nblock by block]
    C --> E[Game]
    C --> F[Story reader]
    D --> G[Inline checks\ninstant audio feedback]
    G --> H[Completion celebration\nXP + stars + Kibo cheer]
    H --> I{Quiz unlocked?}
    I -- Yes --> J[Quiz runner] --> K{Pass >=70%?}
    K -- Yes --> L[Rewards + mastery update\nnext lesson unlocked]
    K -- No --> M[Encourage + targeted retry\nadaptive: easier variant offered]
    B --> N{Screen-time limit hit?}
    N -- Yes --> O[Kibo 'time to rest' screen\nsoft lock, parent PIN overrides]
```

## 9.3 Subscription Purchase

```mermaid
flowchart TD
    A[Premium-locked content tapped] --> B[Parent gate: PIN]
    B --> C[Paywall: plan compare\nmonthly / annual]
    C --> D{Platform}
    D -- iOS --> E[StoreKit purchase] --> H[POST /billing/apple/verify]
    D -- Android --> F[Play Billing purchase] --> I[POST /billing/google/verify]
    D -- Web --> G[Stripe Checkout redirect] --> J[Stripe webhook]
    H & I & J --> K[Subscription row upserted\nentitlements cache busted]
    K --> L[JWT refreshed with new ent claim\ncontent unlocks immediately]
```

Restore purchases: Settings → "Restore" re-runs store verification. Cancellation/expiry arrives via ASSN v2 / RTDN / Stripe webhooks → grace period honored → entitlement downgrade.

## 9.4 Offline Download & Sync

```mermaid
flowchart TD
    A[Parent or child taps download\non course/story] --> B[GET /catalog/manifest?scope=...]
    B --> C[DownloadManager: fetch files\nresumable, hash-verified, Wi-Fi-only option]
    C --> D[Pack registered in drift\ncontent fully usable offline]
    E[Child learns offline] --> F[Progress + attempts + rewards\nwritten locally, ops appended to sync queue]
    G[Connectivity restored] --> H[POST /sync/batch ≤200 ops]
    H --> I{Per-op result}
    I -- applied/duplicate --> J[Dequeue]
    I -- conflict_server_won --> K[Local row overwritten with server state]
    H --> L[GET /sync/changes\nassignments, entitlements, content updates]
```

## 9.5 Parent Dashboard Review

Parent → PIN → dashboard: per-child cards (streak, minutes, mastery deltas) → drill into subject report → weekly AI insight summary → actions: set goal, adjust screen time, approve leaderboard, manage subscription, export/delete data (compliance self-service).

## 9.6 Teacher Assignment Flow

Teacher (web/tablet) → create group → share join code → parent enters code in Parent Zone and approves linkage → teacher assigns lessons/quizzes with due date → children see "From your teacher" rail on home → teacher dashboard tracks per-child completion and class skill heatmap.

## 9.7 Reading Coach Session

Child opens story page → taps "Read it myself" → mic permission (parent pre-consented) → records page → upload via signed URL → async scoring (STT + alignment) → per-word feedback: green = good, amber = listen-and-retry with TTS model pronunciation → fluency stars awarded → recording auto-deleted ≤30 days, score retained.

## 9.8 Consent Revocation / Data Deletion

Parent Zone → Privacy → toggle consent off (AI/voice features hide immediately, server flag flips) or "Delete child profile" → confirm with PIN → soft-delete + 30-day grace (recoverable) → erasure job purges PII, recordings, and de-identifies analytics → email confirmation to parent.
