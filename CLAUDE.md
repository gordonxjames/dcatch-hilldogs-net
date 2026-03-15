# Delta Catcher (DCATCH) — Session Guidance

## Rebuild Requirement

**CRITICAL: Every artifact required to rebuild this application from scratch must exist in this repository.**
If all AWS resources were deleted and only this GitHub repo remained, a developer must be able to
re-provision the complete environment by running the provision scripts in phase order. All resource IDs
are stored in `infra/outputs.env` (gitignored). After cloning, recreate `outputs.env` from
`infra/outputs.env.template` and run the scripts — each script repopulates its section of `outputs.env`.
**This requirement must be restated in every phase update to this file.**

## Project Overview

Delta Catcher is an investment analyst tool for modeling quantitative strategies, hosted at
`dcatch.hilldogs.net` on AWS (us-east-2). It is owned by Hill Dogs Consulting.

- **GitHub**: https://github.com/gordonxjames/dcatch-hilldogs-net
- **Jira**: https://hilldogs.atlassian.net/jira/software/projects/DCATCH/boards/136
- **AWS Account**: 420030147545

## Architecture Decisions

| Concern | Decision | Rationale |
|---|---|---|
| Region | us-east-2 (ACM cert in us-east-1 — existing wildcard) | Consistency with other HDC projects |
| VPC CIDR | 10.1.0.0/16 | Avoids conflict with REPL (10.0.0.0/16) |
| Cognito login | Username primary (immutable), email as alias | Users can change email; username stays stable |
| MFA | SMS mandatory for all users | Security requirement |
| User-facing email | Cognito built-in (no SES) | Free, no infrastructure needed |
| Admin alert email | Lambda + SES — deferred (DCATCH-1) | No VPC route to SES yet; non-critical |
| Lambda VPC | In VPC from day one | Ready for RDS in Phase 2; matches final architecture |
| NAT gateway | None | Lambda only needs intra-VPC access; cost saving |
| Tagging | `Project=DCATCH` on all resources | Consistent with HDC convention |
| Resource prefix | `dcatch-[type]` | Consistent with HDC convention |
| Frontend stack | React 18 + Vite 5, React Router 6, amazon-cognito-identity-js | Mirrors REPL project |
| Colors | Amber/gold replacing REPL blues: `#92400e / #b45309 / #d97706` | DCATCH brand identity |
| Infrastructure tooling | Bash scripts + PowerShell helpers, AWS CLI | Mirrors REPL; human-readable and maintainable |

## Reference Project

The `repl.hilldogs.net` project at `gordonxjames/repl-hilldogs-net` is the design reference for
naming conventions, code style, and infrastructure patterns. **Do not modify that repository.**
Read from it to understand conventions; implement analogous but independent resources here.

## Completed Phases

- **Phase 1** — VPC, Cognito, IAM, S3. See `PHASE_1_SUMMARY.md`.

## Current State (end of Phase 1)

All foundational AWS resources are provisioned. The application is not yet reachable.
Lambda and API Gateway do not yet exist. S3 bucket exists but has no content and no CloudFront in front of it.

| Resource | ID |
|---|---|
| VPC | vpc-009adc65bd69501d7 |
| Subnet 2a | subnet-06e638b34bdd6c924 |
| Subnet 2b | subnet-08999ff637c2b93cf |
| SG Lambda | sg-0418a7cce18963011 |
| SG DB | sg-05970d52df18fde0a |
| Cognito user pool | us-east-2_7fwfzEQZM |
| Cognito client | 38bvf5r3hs4mlfm2d3cu05b011 |
| Lambda role | arn:aws:iam::420030147545:role/dcatch-lambda-role |
| Cognito SMS role | arn:aws:iam::420030147545:role/dcatch-cognito-sms-role |
| S3 bucket | dcatch-hilldogs-frontend |

Full values in `infra/outputs.env` (gitignored).

## Next Phase — Phase 2: Lambda and API Gateway

1. Run `make-zip.ps1` to package `infra/lambda/`
2. Run `infra/provision-lambda.sh` — creates `dcatch-api` Lambda in VPC, attaches post-confirmation trigger to Cognito pool
3. Run `infra/provision-apigw.sh` — creates REST API, Cognito authorizer, `/health` and `/{proxy+}` resources, deploys stage `v1`
4. Run `infra/configure-lambda.ps1` — sets Lambda env vars from `outputs.env`
5. Create CloudWatch keep-warm rule `dcatch-lambda-keepwarm`
6. Update `outputs.env`, write `PHASE_2_SUMMARY.md`, update this file, commit and push

## Known Deferred Items

| Ticket | Summary |
|---|---|
| DCATCH-1 | Admin alert email — Lambda cannot reach SES from private subnet; IAM policy also missing. Deferred to Phase 2. |

## Jira Issue Types (for creating tickets via API)

Task=10199, Bug=10200, Story=10201, Epic=10202, Subtask=10203

## Standard Phase-End Checklist

Every phase must complete these steps before closing, in this order:
1. Run all tests up to current phase: `bash tests/run-all.sh --phase N`
2. All tests must pass before proceeding to documentation or commit
3. Add new phase test file `tests/phaseN.sh` covering everything provisioned this phase
4. Update `infra/outputs.env` with all new resource IDs
5. Write `PHASE_N_SUMMARY.md` (resources, decisions, known gaps)
6. Update `CLAUDE.md` (completed phases, current state, next phase steps)
7. Commit and push to GitHub

## Rebuild From Scratch Steps

```bash
# 1. Clone repo
git clone https://github.com/gordonxjames/dcatch-hilldogs-net.git
cd dcatch-hilldogs-net

# 2. Recreate outputs.env
cp infra/outputs.env.template infra/outputs.env

# 3. Phase 1 — Foundation
bash infra/provision-iam.sh
bash infra/provision-vpc.sh
bash infra/provision-cognito.sh
bash infra/provision-s3.sh

# 4. Phase 2 — Lambda & API Gateway (after Phase 2 scripts exist)
# pwsh infra/lambda/make-zip.ps1
# bash infra/provision-lambda.sh
# bash infra/provision-apigw.sh
# pwsh infra/configure-lambda.ps1

# 5. Phase 3 — CloudFront & DNS (after Phase 3 scripts exist)
# bash infra/provision-cloudfront.sh

# 6. Phase 4 — Deploy frontend (after frontend exists)
# cd frontend && npm install && pwsh deploy.ps1
```
