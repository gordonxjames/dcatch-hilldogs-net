# Phase 2 Summary — Lambda & API Gateway

## Resources Built

| Resource | Name / ID |
|---|---|
| Lambda Function | dcatch-api (`arn:aws:lambda:us-east-2:420030147545:function:dcatch-api`) |
| EventBridge Rule | dcatch-lambda-keepwarm (rate 5 minutes) |
| REST API | dcatch-api-gw (`0rsdzot34a`) |
| Cognito Authorizer | dcatch-cognito-auth (`0fqrfi`) |
| API Stage | v1 → `https://0rsdzot34a.execute-api.us-east-2.amazonaws.com/v1` |

## Scripts Created

- `infra/provision-lambda.sh` — creates Lambda in VPC, Cognito trigger, keep-warm rule
- `infra/provision-apigw.sh` — creates REST API, authorizer, `/health`, `/{proxy+}`, deploys stage v1
- `infra/configure-lambda.ps1` — sets ALERT_FROM_EMAIL / ALERT_TO_EMAIL env vars on Lambda
- `infra/lambda/make-zip.ps1` — existed from Phase 1; packages lambda.zip

## Decisions Made

- Lambda runtime: `nodejs20.x` (current LTS)
- `/health` resource: no auth (publicly accessible health check)
- `/{proxy+}` resource: `COGNITO_USER_POOLS` auth (all API routes require a valid Cognito JWT)
- Lambda path check uses `/health` (API GW strips stage prefix before forwarding to Lambda)
- ALERT_FROM_EMAIL / ALERT_TO_EMAIL stored in `outputs.env` (not hardcoded in scripts)

## Known Issues Fixed

- `tests/run-all.sh`: for-loop used `$(ls ... | sort -V)` which word-splits on paths with spaces; fixed to use `while read -r -d ''` with `printf '%s\0' | sort -zV`
- `tests/lib.sh`: `((PASS++))` returns exit code 1 when PASS=0, triggering `set -e`; fixed to `PASS=$((PASS + 1))`
- `infra/provision-lambda.sh`: `--tags Key=Project,Value=DCATCH` creates two wrong tags on Lambda; correct syntax is `--tags Project=DCATCH`
- Cognito `update-user-pool` with `--lambda-config` clears other settings if not re-supplied; fixed by always including all required fields together

## Known Gaps

- DCATCH-1: SES admin alert email still deferred (Lambda in private subnet cannot reach SES; IAM policy also missing)
- CloudFront and custom domain (`dcatch.hilldogs.net`) not yet configured — Phase 3
- Frontend not deployed — Phase 4

## Test Results

94 tests, 94 passed (Phase 1 + Phase 2 cumulative).
