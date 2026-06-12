# 13. AI Architecture

All AI traffic passes through the backend `ai-gateway` module — clients never hold provider keys. Four features share one safety pipeline, one prompt registry (versioned in git, hot-loadable), and one usage meter.

## 13.1 Safety Pipeline (every child-facing request/response)

```
child input → PII strip (names/numbers/addresses regex+NER)
            → input moderation (provider moderation endpoint + denylist)
            → topic gate (allowlist: current lesson skills + general learning topics)
            → LLM call (locked system prompt, child-safe persona, temperature ≤0.7)
            → output moderation (same filters + URL/contact-info strip + reading-level check)
            → if any gate fails: safe fallback line ("Let's ask a grown-up about that!
              Want to get back to counting?") + flag ai_sessions.flagged → safety review queue
```

Hard rules baked into every system prompt: never request personal information; never discuss violence, romance, self-harm, politics, religion; never provide external links; redirect off-topic to learning; language matches child's locale; reading level matched to age band; always encouraging, never sarcastic.

## 13.2 AI Tutor

- **Surface**: chat-style with Kibo; for pre-readers, replies are auto-TTS'd and input is voice or suggestion-chips (no free typing under 6).
- **Context**: system prompt + persona + age band + current lesson body summary + last N turns + child's weak skills (top 3 from mastery) — *no* PII, child referred to by nickname only.
- **Flow**: `POST /ai/tutor/messages` → gateway pipeline → SSE stream → client renders + speaks.
- **Limits**: 30 messages/child/day (parent-adjustable down), 10 rpm rate limit, consent `ai_features` required, parent can review transcripts in Parent Zone (transparency by design).

## 13.3 Reading Coach

```
record page audio (client, 16kHz mono) → signed S3 upload (quarantine bucket)
→ reading queue job:
   1. STT with word-level timestamps (locale model: en/sw/fr)
   2. forced alignment vs expected page text
   3. per-word score: match / partial (phoneme distance) / miss
   4. fluency: WPM vs band norms; accuracy %
→ result JSON → client paints per-word feedback; misses get TTS model pronunciation + retry
→ audio purged ≤30 days (retention job); scores feed skill_mastery (reading.* skills)
```

Pronunciation assessment uses the STT provider's pronunciation API where available for the locale; for Swahili (weaker provider coverage), fall back to phoneme-edit-distance on STT output, flagged as "beta" accuracy internally.

## 13.4 Adaptive Learning Engine

Hybrid, deliberately simple and explainable:

1. **Mastery model — Bayesian Knowledge Tracing** per `(child, skill)`: parameters per skill `p(L0)=0.2, p(T)=0.15, p(S)=0.1, p(G)=0.2` (tunable per skill from data). Updated on every graded interaction; stored in `skill_mastery.mastery`.
2. **Difficulty governor**: rolling success rate last 10 items; >85% → offer +1 difficulty variant; <50% → easier variant + prerequisite skill review. Target zone 60–80% success (productive struggle).
3. **Next-item ranker** (`GET /learning-path/next`): candidate items from current course frontier + spaced-repetition reviews (SM-2-lite on flashcards and weak skills, intervals 1/3/7/16 days) + daily-challenge variety constraint (≥2 content types). Score = `w1·(0.95−mastery) + w2·recency + w3·curriculum_order + w4·variety`.
4. **Cold start**: age-band placement check (5–8 fun items) on first session sets initial mastery priors.

Everything is server-side, deterministic, loggable — no LLM in the learning-path loop (LLM only *explains* recommendations to parents).

## 13.5 Parent Insights AI

Weekly worker job per family: aggregates the week's stats + mastery deltas → LLM generates a 120-word plain-language summary + 2 actionable suggestions in the parent's locale → cached in `report_snapshots`, surfaced in dashboard + optional email. Prompt receives only aggregated numbers and skill names — never raw child utterances or recordings.

## 13.6 Prompt Registry & Versioning

`apps/api/src/modules/ai/prompts/*.prompt.md` — frontmatter: `id`, `version`, `model`, `temperature`, `maxTokens`, eval set reference. Changes require passing the prompt eval suite in CI (golden Q→A safety cases: 50 jailbreak attempts, 30 off-topic probes, 20 PII baits must all produce safe outputs).

## 13.7 Cost & Reliability Controls

| Control | Setting |
|---|---|
| Model tiering | Tutor: mini-tier model; Insights: mini-tier; moderation: dedicated endpoint |
| Token caps | tutor reply ≤300 tokens; insight ≤500 |
| Budget guard | daily $ cap per env → over-budget flips `ai.degraded=true` → canned fallbacks |
| Caching | identical tutor questions per lesson cached 24 h (post-safety) |
| Timeouts | 10 s LLM / 30 s STT; client shows Kibo "thinking" then graceful fallback |
| Metering | `ai_usage` rows per call → CloudWatch EMF → spend alarms |
