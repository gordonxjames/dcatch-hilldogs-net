# Delta Catcher (DCATCH) — Session Guidance

## Rebuild Requirement

**CRITICAL: Every artifact required to rebuild this application from scratch must exist in this repository.**
If all AWS resources were deleted and only this GitHub repo remained, a developer must be able to
re-provision the complete environment by running the provision scripts in phase order. All resource IDs
are stored in `infra/outputs.env` (gitignored). After cloning, recreate `outputs.env` from
`infra/outputs.env.template` and run the scripts — each script repopulates its section of `outputs.env`.
**This requirement must be restated in every phase update to this file.**

### Pre-existing HDC dependencies (NOT recreated by provision scripts)

These resources are shared across HDC projects and must already exist before rebuilding DCATCH:

| Resource | ID/Value | Notes |
|---|---|---|
| ACM wildcard cert | `arn:aws:acm:us-east-1:420030147545:certificate/36daeb2b-20e3-4910-bbe1-acac865f5adb` | `*.hilldogs.net` — **must be in us-east-1** |
| Route 53 hosted zone | `Z09301025V2NYG3DJ3TL` | `hilldogs.net` zone |

The HDC logo (`frontend/public/hilldogs-logo.png`) is checked into this repo and requires no external copy.

If the ACM cert or Route 53 zone do not exist, contact the HDC AWS account owner before attempting a rebuild.

## Session Setup — Do This First in Every Session

```bash
# 1. Set git author email (required — gjames@hilldogs.com triggers GitHub GH007 push rejection)
git config user.email "gordonxjames@users.noreply.github.com"
git config user.name "Gordon James"

# 2. Verify AWS credentials
aws sts get-caller-identity
```

Jira credentials: `C:/Users/gordon/.claude/jira.env` (not in git)
Jira project key: `DCATCH`, project ID: `10135`

## Project Overview

Delta Catcher is an investment analyst tool for modeling quantitative strategies, hosted at
`dcatch.hilldogs.net` on AWS (us-east-2). It is owned by Hill Dogs Consulting.

- **GitHub**: https://github.com/gordonxjames/DCATCH
- **Jira**: https://hilldogs.atlassian.net/jira/software/projects/DCATCH/boards/136
- **AWS Account**: 420030147545

## Architecture Decisions

| Concern | Decision | Rationale |
|---|---|---|
| Region | us-east-2 (ACM cert in us-east-1 — existing wildcard) | Consistency with other HDC projects |
| VPC CIDR | 10.1.0.0/16 | Avoids conflict with REPL (10.0.0.0/16) |
| Cognito login | Username primary (immutable), email as alias | Users can change email; username stays stable |
| MFA | TOTP optional + SMS optional, enabled per-user via Account Settings | Mandatory MFA caused chicken-and-egg: phone must be verified to sign in with MFA, but sign-in is needed to verify phone. Optional MFA lets users register via email, then enable TOTP (or SMS when unblocked) in Settings. |
| User-facing email | Cognito built-in (no SES) | Free, no infrastructure needed. Cognito uses its own managed SES — not affected by account SES sandbox status. |
| Admin alert email | Dropped — CloudWatch Logs + Cognito console sufficient | Lambda has no internet route (private VPC, no NAT). SES call was removed from PostConfirmation trigger. |
| Lambda VPC | In VPC from day one | Ready for RDS in Phase 2; matches final architecture |
| NAT gateway | None | Lambda only needs intra-VPC access; cost saving |
| Tagging | `Project=DCATCH` on all resources | Consistent with HDC convention |
| Resource prefix | `dcatch-[type]` | Consistent with HDC convention |
| Frontend stack | React 18 + Vite 5, React Router 6, amazon-cognito-identity-js | Mirrors REPL project |
| Styling | Custom CSS variables, no framework | Mirrors REPL project |
| Colors | Amber/gold replacing REPL blues: `--primary-dark:#92400e / --primary:#b45309 / --primary-light:#d97706 / --accent:#059669 (teal)` | DCATCH brand identity |
| Infrastructure tooling | Bash scripts + PowerShell helpers, AWS CLI | Mirrors REPL; human-readable and maintainable |

## Frontend Design Decisions

**Login page** — Two-panel layout (mirrors REPL):
- Left panel: amber gradient `linear-gradient(160deg, #92400e 0%, #b45309 60%, #d97706 100%)`, HDC logo (260px), title "Delta Catcher" (28px bold white), tagline "Investment modeling tool for quantitative algorithms." (16px italic white 80% opacity). Hidden on mobile.
- Right panel: light gray bg, white card, tabs: Sign In / Create Account / Verify / Forgot Password / Reset Password
- Create Account collects: username, email, phone number, password, confirm password

**Footer** — Structurally identical to REPL. Background uses `--primary-dark` (#92400e). Same HDC social links (LinkedIn, Facebook, Instagram), same copyright "Hill Dogs Consulting", same privacy policy URL (https://www.hilldogs.net/privacy.html).

**Home page** — Protected route. Welcome message only: "Welcome, [username]." No other content in initial phase.

**Account Settings** (`/settings`) — Protected route, accessible from upper-right nav icon:
- Username: read-only (immutable in Cognito — inform user it cannot be changed)
- Email: editable → `updateUserAttributes` → verification code sent to new address → confirm
- Phone: editable → `updateUserAttributes` → SMS verification code → confirm
- Password: current + new + confirm → `changePassword`

## Reference Project

The `repl.hilldogs.net` project at `gordonxjames/REPL` is the design reference for
naming conventions, code style, and infrastructure patterns. **Do not modify that repository.**
Read from it to understand conventions; implement analogous but independent resources here.

## Completed Phases

- **Phase 1** — VPC, Cognito, IAM, S3. See `PHASE_1_SUMMARY.md`.
- **Phase 2** — Lambda, API Gateway. See `PHASE_2_SUMMARY.md`.
- **Phase 3** — CloudFront OAC + distribution, S3 bucket policy, Route 53 DNS. See `PHASE_3_SUMMARY.md`.
- **Phase 4** — React frontend build & deploy. See `PHASE_4_SUMMARY.md`.

## Current State (release 0.3 — post Phase 4 + v0.3 features)

All infrastructure is provisioned and the React frontend is live. `https://dcatch.hilldogs.net` serves
the Delta Catcher app (amber theme, username-based auth, optional TOTP MFA, account settings, phone
optional). v0.3 adds: QR code TOTP setup, InfoTip component, mobile-responsive login layout, Terms
link in footer, Lambda memory reduced to 128 MB, keep-warm rule removed. 124/124 cumulative tests pass.
End-to-end registration + email verification confirmed working.

| Resource | Name | ID |
|---|---|---|
| VPC | dcatch-vpc | vpc-009adc65bd69501d7 |
| Subnet us-east-2a | dcatch-private-2a | subnet-06e638b34bdd6c924 |
| Subnet us-east-2b | dcatch-private-2b | subnet-08999ff637c2b93cf |
| Security Group | dcatch-sg-lambda | sg-0418a7cce18963011 |
| Security Group | dcatch-sg-db | sg-05970d52df18fde0a |
| Cognito User Pool | dcatch-user-pool | us-east-2_4SqnYbW6y |
| Cognito App Client | dcatch-web-client | akhb5c7esdmiiju1aklovdeb4 |
| IAM Role | dcatch-lambda-role | arn:aws:iam::420030147545:role/dcatch-lambda-role |
| IAM Role | dcatch-cognito-sms-role | arn:aws:iam::420030147545:role/dcatch-cognito-sms-role |
| S3 Bucket | dcatch-s3-frontend | dcatch-s3-frontend |
| ACM Cert (shared) | *.hilldogs.net (us-east-1) | arn:aws:acm:us-east-1:420030147545:certificate/36daeb2b-20e3-4910-bbe1-acac865f5adb |
| Lambda | dcatch-lambda (128MB) | arn:aws:lambda:us-east-2:420030147545:function:dcatch-lambda |
| REST API | dcatch-api | 0rsdzot34a |
| API Stage | v1 | https://0rsdzot34a.execute-api.us-east-2.amazonaws.com/v1 |
| CloudFront OAC | dcatch-s3-oac | E2HC19CJC7ET7N |
| CloudFront Distribution | dcatch.hilldogs.net | E1BFXVAS6JB4C4 |
| CloudFront Domain | — | d166oqa1rcdpok.cloudfront.net |
| Route 53 A ALIAS | dcatch.hilldogs.net | → CloudFront |

Full values in `infra/outputs.env` (gitignored).

## Next Phase — Phase 5: TBD

No next phase defined yet.

## Known Deferred Items

| Ticket | Summary |
|---|---|
| DCATCH-23 | SMS delivery broken — SNS SMS sandbox has no origination entities (no 10DLC/toll-free/short code). Cannot send to any number. Fix: request SNS SMS production access via AWS Service Quotas, or register a toll-free number. Blocks SMS MFA and phone verification. TOTP MFA is available as a workaround. |

## Phase-End Checklist (every phase, in this order)

1. **Create Jira tickets** at the *start* of each phase before writing code
2. Run all cumulative tests: `bash tests/run-all.sh --phase N`
3. All tests must pass before proceeding
4. Add `tests/phaseN.sh` covering everything new this phase
5. Save final test run output: `bash tests/run-all.sh --phase N 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > tests/results/phaseN-final.txt`
6. Update `infra/outputs.env` with all new resource IDs
7. Write `PHASE_N_SUMMARY.md` (resources built, decisions made, known gaps, script fixes)
8. Update this `CLAUDE.md` (completed phases, current state, next phase steps)
9. Commit and push: `git add ... && git commit && git push`

## Jira Issue Types (for creating tickets via API)

Task=10199, Bug=10200, Story=10201, Epic=10202, Subtask=10203

## Rebuild From Scratch Steps

```bash
# 0. Session setup
git config user.email "gordonxjames@users.noreply.github.com"
git config user.name "Gordon James"

# 1. Clone repo
git clone https://github.com/gordonxjames/DCATCH.git
cd DCATCH

# 2. Recreate outputs.env from template
#    Template includes default email values (noreply@hilldogs.net / gjames@hilldogs.com).
#    Edit ALERT_FROM_EMAIL / ALERT_TO_EMAIL before Phase 2 if different values needed.
cp infra/outputs.env.template infra/outputs.env

# 3. Phase 1 — Foundation
bash infra/provision-iam.sh
bash infra/provision-vpc.sh
bash infra/provision-cognito.sh
bash infra/provision-s3.sh
bash tests/run-all.sh --phase 1

# 4. Phase 2 — Lambda & API Gateway
pwsh infra/lambda/make-zip.ps1
bash infra/provision-lambda.sh   # also attaches Cognito trigger + keep-warm rule
bash infra/provision-apigw.sh
bash tests/run-all.sh --phase 2

# 5. Phase 3 — CloudFront & DNS
bash infra/provision-cloudfront.sh   # also creates Route 53 DNS record
bash tests/run-all.sh --phase 3

# 6. Phase 4 — Deploy frontend
#    IMPORTANT: after a rebuild, AWS will assign new resource IDs. Update these
#    hardcoded values in frontend/src/config.js before running deploy.ps1:
#      COGNITO_POOL_ID   → new COGNITO_USER_POOL_ID from outputs.env
#      COGNITO_CLIENT_ID → new COGNITO_CLIENT_ID from outputs.env
#      API_BASE          → new APIGW_BASE_URL from outputs.env
pwsh deploy.ps1   # npm install + build + S3 sync + CF invalidation
bash tests/run-all.sh --phase 4
```
