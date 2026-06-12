# 19. CI/CD Pipeline (GitHub Actions)

Trunk-based: short-lived branches → PR → `main`. `main` auto-deploys to **dev**; tag `vX.Y.Z-rc` promotes to **staging**; manual environment-protected approval promotes the *same artifacts* to **production**. AWS access via GitHub OIDC roles (no stored keys). Mobile signing via App Store Connect API key + Play service account in GitHub Encrypted Secrets; Android keystore in Secrets Manager pulled at build time.

## 19.1 Workflows

```
.github/workflows/
├── ci-api.yml          # PR + main: lint, unit, integration (testcontainers), build image
├── ci-mobile.yml       # PR + main: analyze, test, goldens, build debug apk/ipa-sim/web
├── contract.yml        # OpenAPI lint + client-generation drift check
├── ai-evals.yml        # prompt safety evals (on prompts/** change + weekly cron)
├── deploy-api.yml      # build→ECR→ECS rolling deploy + migrations (per env)
├── deploy-web.yml      # flutter build web → S3 → CloudFront invalidate (per env)
├── release-mobile.yml  # tag-triggered: signed builds → TestFlight / Play internal
├── e2e-nightly.yml     # Playwright + Firebase Test Lab + k6 smoke vs dev
└── infra.yml           # terraform plan on PR, apply on env approval
```

## 19.2 `ci-api.yml` (excerpt)

```yaml
name: ci-api
on:
  pull_request: { paths: ['apps/api/**', 'packages/**'] }
  push: { branches: [main], paths: ['apps/api/**', 'packages/**'] }
jobs:
  test:
    runs-on: ubuntu-latest
    services: {}            # testcontainers manages pg/redis
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npm run lint && npm run typecheck
      - run: npm run test:unit -- --coverage
      - run: npm run test:integration
      - uses: actions/upload-artifact@v4
        with: { name: coverage, path: apps/api/coverage }
  build:
    needs: test
    if: github.ref == 'refs/heads/main'
    permissions: { id-token: write, contents: read }
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with: { role-to-assume: ${{ vars.AWS_CI_ROLE }}, aws-region: af-south-1 }
      - uses: docker/build-push-action@v6
        with:
          context: apps/api
          tags: ${{ vars.ECR }}/watoto-api:${{ github.sha }}
          push: true
          provenance: true
      - run: trivy image --severity HIGH,CRITICAL --exit-code 1 ${{ vars.ECR }}/watoto-api:${{ github.sha }}
```

## 19.3 `deploy-api.yml` (promotion model)

```yaml
on:
  workflow_run: { workflows: [ci-api], types: [completed], branches: [main] }   # → dev
  push: { tags: ['v*-rc*'] }                                                    # → staging
  workflow_dispatch: { inputs: { env: { type: choice, options: [production] }}} # → prod (env protection: 2 reviewers)
jobs:
  deploy:
    environment: ${{ ... }}        # dev / staging / production rules
    steps:
      - migrate: run prisma migrate deploy via one-off ECS task (fails → abort)
      - deploy: aws ecs update-service --force-new-deployment (rolling, circuit breaker on)
      - verify: hit /ready + smoke suite (newman) against env
      - notify: Slack #deploys with diff link + Sentry release
```

DB migration policy: **expand → migrate → contract**; migrations must be backward-compatible with the previous app version (rolling deploy overlap); destructive changes ship one release after their code stops using the column.

## 19.4 `release-mobile.yml`

```
tag v1.4.0 →
  ├ android: flutter build appbundle --flavor prod → sign → Play Internal track
  ├ ios: flutter build ipa → App Store Connect API → TestFlight
  └ web: build → staging bucket (prod web promoted with API approval)
Staged rollout: Play 10% → 50% → 100% (halt on crash-rate alarm >0.5%);
TestFlight → phased App Store release 7-day.
Version source: tag drives pubspec version + build number = run number.
```

## 19.5 Quality Gates Summary

| Gate | Blocks |
|---|---|
| Lint/typecheck/tests/coverage ratchet | PR merge |
| OpenAPI contract drift | PR merge |
| Trivy HIGH+ vulns, osv-scanner | image push |
| AI safety evals | prompt changes |
| Terraform plan review | infra apply |
| Smoke suite post-deploy | promotion (auto-rollback on failure via ECS circuit breaker) |
| 2-reviewer environment protection | production |
