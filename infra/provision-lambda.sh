#!/usr/bin/env bash
# provision-lambda.sh — Phase 2
# Creates dcatch-lambda Lambda in VPC and attaches Cognito post-confirmation trigger.
# Keep-warm EventBridge rule is provisioned separately by infra/provision-keepwarm.sh.
# Run from repo root: bash infra/provision-lambda.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
source "$OUTPUTS"

REGION="us-east-2"
FUNCTION_NAME="dcatch-lambda"
ZIP_PATH="$SCRIPT_DIR/lambda/lambda.zip"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "ERROR: $ZIP_PATH not found. Run first: pwsh infra/lambda/make-zip.ps1"
  exit 1
fi

echo "=== Phase 2: Lambda ==="

# ─── 1. Create Lambda function ───────────────────────────────────────────────

echo "Creating Lambda function $FUNCTION_NAME..."

LAMBDA_FUNCTION_ARN=$(cd "$SCRIPT_DIR/lambda" && aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime nodejs20.x \
  --handler index.handler \
  --role "$LAMBDA_ROLE_ARN" \
  --zip-file "fileb://lambda.zip" \
  --vpc-config "SubnetIds=$SUBNET_2A_ID,$SUBNET_2B_ID,SecurityGroupIds=$SG_LAMBDA_ID" \
  --timeout 30 \
  --memory-size 128 \
  --environment "Variables={ALLOWED_ORIGIN=https://dcatch.hilldogs.net}" \
  --region "$REGION" \
  --tags Project=DCATCH \
  --query FunctionArn --output text)

echo "  Lambda ARN: $LAMBDA_FUNCTION_ARN"

echo "Waiting for Lambda to become Active..."
aws lambda wait function-active \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION"

# ─── 2. Cognito post-confirmation trigger ────────────────────────────────────
# WARNING: aws cognito-idp update-user-pool resets any field not supplied to its
# default value. Always pass MFA, SMS, and auto-verified-attributes together with
# lambda-config to avoid silently wiping pool settings.

echo "Attaching Cognito post-confirmation trigger..."

EXTERNAL_ID="dcatch-cognito-sms"
aws cognito-idp update-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" \
  --region "$REGION" \
  --lambda-config "PostConfirmation=$LAMBDA_FUNCTION_ARN" \
  --mfa-configuration OPTIONAL \
  --sms-configuration "SnsCallerArn=$COGNITO_SMS_ROLE_ARN,ExternalId=$EXTERNAL_ID" \
  --auto-verified-attributes email \
  --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":false,"TemporaryPasswordValidityDays":7}}' \
  --admin-create-user-config '{"AllowAdminCreateUserOnly":false,"UnusedAccountValidityDays":7}' \
  --email-configuration '{"EmailSendingAccount":"COGNITO_DEFAULT"}' \
  --verification-message-template '{"DefaultEmailOption":"CONFIRM_WITH_CODE"}' \
  --user-pool-tags Project=DCATCH

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-cognito-postconfirmation \
  --action lambda:InvokeFunction \
  --principal cognito-idp.amazonaws.com \
  --source-arn "arn:aws:cognito-idp:$REGION:$AWS_ACCOUNT_ID:userpool/$COGNITO_USER_POOL_ID" \
  --region "$REGION" > /dev/null

echo "  Cognito trigger attached."

# ─── 3. CloudWatch log retention ─────────────────────────────────────────────

echo "Setting CloudWatch log retention (7 days)..."

# MSYS_NO_PATHCONV prevents Git Bash on Windows from mangling /aws/lambda/... paths
MSYS_NO_PATHCONV=1 aws logs put-retention-policy \
  --log-group-name "/aws/lambda/$FUNCTION_NAME" \
  --retention-in-days 7 \
  --region "$REGION" 2>/dev/null || true

# ─── Write outputs ────────────────────────────────────────────────────────────

grep -v "^LAMBDA_FUNCTION_ARN=" "$OUTPUTS" \
  | grep -v "^LAMBDA_FUNCTION_NAME=" \
  > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"

cat >> "$OUTPUTS" <<EOF
LAMBDA_FUNCTION_ARN=$LAMBDA_FUNCTION_ARN
LAMBDA_FUNCTION_NAME=$FUNCTION_NAME
EOF

echo "Lambda provisioning complete. Values written to outputs.env."
