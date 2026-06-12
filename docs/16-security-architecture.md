# 16. Security Architecture

## 16.1 Authentication

```
Parent/Teacher/Admin: Firebase Auth (Email+verification, Google, Apple)
  → POST /auth/firebase (Firebase ID token, verified via firebase-admin)
  → Watoto JWT access (RS256, 15 min) + refresh (30 d, rotating, device-bound)

Child: never authenticates with credentials.
  Parent session (or PIN-unlocked device) mints scoped child token:
  claims {role:child, childId, familyId, ent} — no email, no PII, 24 h TTL,
  silently re-minted while the device family session is valid.
```

- Refresh rotation with **reuse detection**: a replayed refresh token revokes the whole token family and forces re-auth.
- Parent PIN: argon2id (m=64MB, t=3), 5 failures → 15 min lockout; PIN check issues a `pinAt` claim honored for 10 min for parent-zone mutations.
- Admin/CMS: MFA mandatory (TOTP via Firebase), session 8 h, IP allowlist optional per deployment.

## 16.2 Authorization — RBAC Matrix

| Capability | child | parent | teacher | admin | super |
|---|---|---|---|---|---|
| Consume published content | ✅ (entitlement-checked) | ✅ | ✅ | ✅ | ✅ |
| Write own progress | ✅ | — | — | — | — |
| View child progress | own | own children | linked group children | aggregate only | ✅ |
| Manage child profiles / consents / screen time | — | ✅ (PIN) | — | — | ✅ |
| Manage subscription | — | ✅ (PIN) | — | view | ✅ |
| Groups & assignments | view own | approve join | own groups | ✅ | ✅ |
| Content CRUD / publish | — | — | — | ✅ (four-eyes publish) | ✅ |
| Moderation decisions | — | — | — | ✅ | ✅ |
| User admin / role grants | — | — | — | suspend only | ✅ |
| Platform settings / audit logs | — | — | — | read | ✅ |

Enforced by `RolesGuard` + `ChildAccessGuard` (relationship proof for any `childId` access: parent-of, linked-teacher-of, or self). Deny-by-default; every route declares roles explicitly.

## 16.3 Encryption & Secrets

| Surface | Mechanism |
|---|---|
| In transit | TLS 1.3 (ALB + CloudFront); HSTS preload; cert pinning considered post-launch (rotation risk) |
| At rest — DB/Redis/S3 | KMS CMK AES-256 (RDS, ElastiCache at-rest, S3 SSE-KMS) |
| Voice recordings | separate KMS key + 30-day lifecycle + restricted task-role |
| Device | tokens in flutter_secure_storage (Keychain/Keystore); SQLCipher for drift DB containing child progress |
| Secrets | AWS Secrets Manager; ECS-injected; DB creds auto-rotate 30 d; JWT signing keys rotated quarterly via `kid` header with overlap window |

## 16.4 Application Security Controls

- Input: zod validation on every DTO (OpenAPI-derived), Prisma parameterization (no raw SQL except audited reporting views), upload MIME+magic-byte checks, ClamAV scan, image re-encode (strips payloads/EXIF).
- Headers: helmet — CSP (no inline script on web/CMS), X-Frame-Options DENY, referrer-policy no-referrer.
- CORS: exact origins (`app.watoto.app`, `cms.watoto.app`) only.
- Rate limiting: Redis token buckets per principal + WAF IP rules; login & PIN endpoints stricter (10/min).
- SSRF: no user-supplied URL fetching anywhere; webhook origins signature-verified (Stripe sig, Apple JWS, Google Pub/Sub OIDC).
- Mobile: certificate validation strict, no webviews in child surfaces, Play Integrity / App Attest on auth endpoints (Phase 2).
- Dependency hygiene: Dependabot + `npm audit`/`osv-scanner` in CI fail on high CVEs; container base images rebuilt weekly.

## 16.5 Audit & Detection

- `audit_logs` for all admin mutations + auth events (login, refresh-reuse, PIN lockout, consent changes, deletions) + billing changes.
- CloudTrail (org-wide), GuardDuty, S3 access logs on media buckets.
- Alerts: refresh-reuse spike, failed-login spike, admin action outside business hours, mass data export, WAF block surge → Slack + PagerDuty.
- Quarterly access review for IAM + admin roles; annual external penetration test (pre-launch test is a launch gate).

## 16.6 Child-Specific Hardening

- Child JWTs carry no PII and cannot call: billing, consents, profile mutation, admin, group management, or any endpoint returning other users' data.
- All child-reachable response DTOs pass an allowlist serializer — fields not explicitly whitelisted are stripped (prevents accidental PII leaks via shared models).
- No child-generated free text leaves the device except AI tutor messages (PII-stripped, consent-gated) and creativity artifacts stored privately to the family.
- Media URLs are CDN-signed and scoped; no user-supplied external URLs can ever render in child surfaces (schema forbids `http(s)://` outside `media.watoto.app`).

## 16.7 Threat Model Snapshot (STRIDE highlights)

| Threat | Mitigation |
|---|---|
| Stolen device → child data | secure storage, child tokens scoped & short, PIN for parent zone, remote sign-out (refresh revocation) |
| Token theft via XSS (web) | CSP, httpOnly-equivalent storage strategy (web: tokens in memory + silent refresh), short access TTL |
| Malicious CMS insider | four-eyes publish, moderation gate, audit diffs, least-privilege roles |
| Receipt forgery | server-side verification against Apple/Google/Stripe APIs only; client claims never trusted |
| Sync replay/forgery | ops idempotent by UUID, child-scope guard, server-side grading (answer keys never fully client-trusted online) |
| Scraping content | signed media URLs, rate limits, watermarked premium PDFs |
