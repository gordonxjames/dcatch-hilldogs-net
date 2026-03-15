#!/usr/bin/env bash
# provision-iam.sh — Phase 1
# Creates IAM roles needed by Lambda and Cognito SMS MFA.
# Run from repo root: bash infra/provision-iam.sh
# Appends resource IDs to infra/outputs.env

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
touch "$OUTPUTS"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account: $AWS_ACCOUNT_ID"

# ─── 1. Lambda execution role ───────────────────────────────────────────────

echo "Creating dcatch-lambda-role..."

LAMBDA_TRUST='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}'

LAMBDA_ROLE_ARN=$(aws iam create-role \
  --role-name dcatch-lambda-role \
  --assume-role-policy-document "$LAMBDA_TRUST" \
  --tags Key=Project,Value=DCATCH \
  --query Role.Arn --output text)

aws iam attach-role-policy \
  --role-name dcatch-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole

# NOTE: sesv2:SendEmail permission intentionally omitted until DCATCH-1 is resolved.
# When that ticket is worked, add an inline policy here granting sesv2:SendEmail.

echo "  Lambda role ARN: $LAMBDA_ROLE_ARN"

# ─── 2. Cognito SMS role (required for SMS MFA) ──────────────────────────────

echo "Creating dcatch-cognito-sms-role..."

# ExternalId ties the role to this specific user pool (populated after Cognito is created).
# For initial creation we use a placeholder; configure-cognito.ps1 will update if needed.
EXTERNAL_ID="dcatch-cognito-sms"

COGNITO_TRUST=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "cognito-idp.amazonaws.com" },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": { "sts:ExternalId": "$EXTERNAL_ID" }
    }
  }]
}
EOF
)

COGNITO_SMS_ROLE_ARN=$(aws iam create-role \
  --role-name dcatch-cognito-sms-role \
  --assume-role-policy-document "$COGNITO_TRUST" \
  --tags Key=Project,Value=DCATCH \
  --query Role.Arn --output text)

aws iam put-role-policy \
  --role-name dcatch-cognito-sms-role \
  --policy-name dcatch-cognito-sms-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "*"
    }]
  }'

echo "  Cognito SMS role ARN: $COGNITO_SMS_ROLE_ARN"

# ─── Write outputs ───────────────────────────────────────────────────────────

grep -v "^LAMBDA_ROLE_ARN=" "$OUTPUTS" | grep -v "^COGNITO_SMS_ROLE_ARN=" | grep -v "^AWS_ACCOUNT_ID=" > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"
cat >> "$OUTPUTS" <<EOF
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
LAMBDA_ROLE_ARN=$LAMBDA_ROLE_ARN
COGNITO_SMS_ROLE_ARN=$COGNITO_SMS_ROLE_ARN
EOF

echo "IAM provisioning complete. Values written to outputs.env."
