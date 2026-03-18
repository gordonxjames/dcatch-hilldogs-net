# Phase 1 Summary — Foundation & Infrastructure

## What was built

| Resource | Name / ID | Notes |
|---|---|---|
| IAM role (Lambda) | dcatch-lambda-role | AWSLambdaVPCAccessExecutionRole attached |
| IAM role (Cognito SMS) | dcatch-cognito-sms-role | sns:Publish; ExternalId=dcatch-cognito-sms |
| VPC | dcatch-vpc / vpc-009adc65bd69501d7 | 10.1.0.0/16, DNS hostnames enabled |
| Subnet us-east-2a | dcatch-private-2a / subnet-06e638b34bdd6c924 | 10.1.1.0/24, private only |
| Subnet us-east-2b | dcatch-private-2b / subnet-08999ff637c2b93cf | 10.1.2.0/24, private only |
| Security group (Lambda) | dcatch-sg-lambda / sg-0418a7cce18963011 | No inbound; outbound open |
| Security group (DB) | dcatch-sg-db / sg-05970d52df18fde0a | Inbound TCP 5432 from sg-lambda only |
| Cognito user pool | dcatch-user-pool / us-east-2_7fwfzEQZM | See decisions below |
| Cognito app client | dcatch-web-client / 38bvf5r3hs4mlfm2d3cu05b011 | No secret; SRP + refresh + password flows |
| S3 bucket | dcatch-s3-frontend | All public access blocked; CloudFront OAC policy added in Phase 3 |

All resources tagged `Project=DCATCH`.

## Key decisions

**Username as primary Cognito identifier**
Username is immutable after creation. Users log in with their username or email (email is an alias). Email and phone are required attributes and are auto-verified. This allows users to change their email address over time while retaining a stable login handle.

**SMS MFA mandatory**
`--mfa-configuration ON` — all users must use SMS MFA. Phone number is a required, verified attribute. Cognito calls SNS via `dcatch-cognito-sms-role` with ExternalId `dcatch-cognito-sms`.

**Cognito built-in email for user-facing messages**
Verification codes, confirmation codes, and password reset codes are sent by Cognito's managed email service. No SES or custom email configuration required. This is separate from the admin alert email (see DCATCH-1).

**Lambda in VPC from day one**
Lambda will be placed in the VPC in Phase 2 even though RDS does not yet exist. This matches the final target architecture and avoids having to move Lambda into the VPC later. Security groups are already in place.

**No NAT gateway**
Lambda only needs to reach resources inside the VPC (RDS, coming in Phase 2). Admin alert email via SES is deferred — see DCATCH-1.

**Admin alert email deferred**
The Lambda post-confirmation trigger includes SES code that will fail silently until DCATCH-1 is resolved (VPC endpoint for SES + IAM policy). This does not affect end users.

**VPC CIDR 10.1.0.0/16**
Chosen to avoid conflict with the REPL project's VPC (10.0.0.0/16).

## Known gaps / deferred items

- **DCATCH-1**: Admin alert email (SES) — Lambda cannot reach SES from private subnet; IAM policy missing. Deferred to Phase 2 when RDS VPC endpoint economics justify adding SES endpoint.

## Scripts that provisioned this phase (run in order)

```bash
bash infra/provision-iam.sh
bash infra/provision-vpc.sh
bash infra/provision-cognito.sh   # also creates app client
bash infra/provision-s3.sh
```

## Script fixes applied during Phase 1 execution

- `provision-cognito.sh`: Removed `--prevent-user-existence-errors` from `create-user-pool` (not a valid flag there; it belongs on `create-user-pool-client`).
- `provision-cognito.sh`: Updated auth flow names to ALLOW_ prefix format (`ALLOW_USER_SRP_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`, `ALLOW_USER_PASSWORD_AUTH`).
