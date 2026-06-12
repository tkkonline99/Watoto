# 20. Deployment Guide

## 20.1 Prerequisites

- AWS Organization with `watoto-dev/staging/prod` accounts; admin SSO configured.
- Domains: `watoto.app` in Route53 (prod account, delegated subzones per env: `dev.watoto.app`, `stg.watoto.app`).
- Firebase projects ×3 (`watoto-dev/stg/prod`) with Auth providers (Email, Google, Apple), Analytics, Crashlytics, FCM enabled; ad personalization disabled.
- Apple Developer + App Store Connect; Google Play Console; Stripe account (test + live).
- GitHub repo with environments `dev/staging/production` and OIDC roles per AWS account.

## 20.2 Infrastructure Bring-Up (per environment)

```bash
cd infra/global && terraform init && terraform apply       # org-level: zones, ECR, OIDC roles (once)
cd ../envs/dev && terraform init
terraform apply -target=module.network                     # 1. VPC, subnets, endpoints
terraform apply                                            # 2. everything: rds, redis, s3/cdn, ecs, waf, secrets, alarms
```

Then populate Secrets Manager (`watoto/<env>/...`): `DATABASE_URL` (from RDS output), `REDIS_URL`, `JWT_PRIVATE_KEY`/`JWT_PUBLIC_KEYS`, `FIREBASE_SA` (service-account JSON), `OPENAI_API_KEY`, `STRIPE_SECRET` + `STRIPE_WEBHOOK_SECRET`, `APPLE_IAP_KEY` (App Store Server API .p8), `GOOGLE_PLAY_SA`.

## 20.3 First Backend Deploy

```bash
# from CI or manually with OIDC role:
docker build -t $ECR/watoto-api:boot apps/api && docker push $ECR/watoto-api:boot
aws ecs run-task ... --overrides '{"command":["npx","prisma","migrate","deploy"]}'   # schema
aws ecs run-task ... --overrides '{"command":["npm","run","seed:baseline"]}'         # plans, subjects, badges, locales, admin user
aws ecs update-service --cluster watoto-dev --service api --force-new-deployment
curl https://api.dev.watoto.app/ready    # expect 200 {db:ok, redis:ok}
```

Wire webhooks after first deploy: Stripe endpoint `/v1/webhooks/stripe` (copy signing secret), Apple App Store Server Notifications v2 URL, Google RTDN Pub/Sub topic → push subscription to `/v1/webhooks/google`.

## 20.4 Web & CMS Deploy

```bash
flutter build web --release --dart-define=ENV=dev          # app
aws s3 sync build/web s3://watoto-web-dev --delete
aws cloudfront create-invalidation --distribution-id $DIST --paths "/index.html" "/flutter_bootstrap.js"
# CMS: same with --dart-define=TARGET=cms → cms bucket/distribution
```

(Automated by `deploy-web.yml`; hashed assets are immutable, only entry files invalidated.)

## 20.5 Mobile Releases

1. Bump tag `vX.Y.Z` → `release-mobile.yml` produces signed builds.
2. **Android**: Play Internal → closed track (team+testers) → production staged rollout 10/50/100% with crash-rate halt rule. First submission: complete Data Safety form, Families Policy declaration, Teacher Approved questionnaire (see [checklist](22-google-play-checklist.md)).
3. **iOS**: TestFlight internal → external beta (review) → App Store phased release. First submission: Kids Category declaration, privacy nutrition labels, IAP products approved alongside binary (see [checklist](21-app-store-checklist.md)).
4. Force-update support: API returns `minSupportedAppVersion`; older clients show an update screen (parent-gated link to store — allowed as parental gate).

## 20.6 Environment Configuration Matrix

| Setting | dev | staging | prod |
|---|---|---|---|
| API URL | api.dev.watoto.app | api.stg.watoto.app | api.watoto.app |
| Firebase | watoto-dev | watoto-stg | watoto-prod |
| Stripe | test keys | test keys | live |
| IAP | sandbox | sandbox/TestFlight | live |
| AI budget/day | $10 | $25 | per finance cap |
| Data | synthetic seed only | synthetic + QA accounts | real (no staging copies — compliance) |

## 20.7 Operations Runbook Pointers

- **Rollback API**: redeploy previous image tag (`aws ecs update-service --task-definition <prev>`); migrations are expand/contract so previous app version is always compatible.
- **Rollback content**: CMS → entity → versions → restore (re-points current_version_id).
- **DB restore**: RDS PITR to new instance → swap endpoint secret → restart tasks (RTO target 1 h, RPO 5 min).
- **Status page**: instatus/status.watoto.app fed by CloudWatch synthetics.
- **Backups verified** monthly by automated restore-and-checksum job into an isolated VPC.
