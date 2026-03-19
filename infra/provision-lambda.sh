#!/usr/bin/env bash
# provision-lambda.sh — Phase 2
# Creates dcatch-lambda Lambda in VPC and attaches Cognito post-confirmation trigger.
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

# ─── 3. Keep-warm EventBridge rule ───────────────────────────────────────────

echo "Creating keep-warm EventBridge rule dcatch-lambda-keepwarm..."

KEEPWARM_RULE_ARN=$(aws events put-rule \
  --name dcatch-lambda-keepwarm \
  --schedule-expression "rate(5 minutes)" \
  --state ENABLED \
  --description "Keep dcatch-lambda warm" \
  --region "$REGION" \
  --query RuleArn --output text)

aws events tag-resource \
  --resource-arn "$KEEPWARM_RULE_ARN" \
  --tags Key=Project,Value=DCATCH \
  --region "$REGION"

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-lambda-keepwarm \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "$KEEPWARM_RULE_ARN" \
  --region "$REGION" > /dev/null 2>&1 || echo "  (permission already exists — skipping)"

aws events put-targets \
  --rule dcatch-lambda-keepwarm \
  --targets "Id=1,Arn=$LAMBDA_FUNCTION_ARN" \
  --region "$REGION" > /dev/null

echo "  Keep-warm rule ARN: $KEEPWARM_RULE_ARN"

# ─── Write outputs ────────────────────────────────────────────────────────────

grep -v "^LAMBDA_FUNCTION_ARN=" "$OUTPUTS" \
  | grep -v "^LAMBDA_FUNCTION_NAME=" \
  | grep -v "^KEEPWARM_RULE_ARN=" \
  > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"

cat >> "$OUTPUTS" <<EOF
LAMBDA_FUNCTION_ARN=$LAMBDA_FUNCTION_ARN
LAMBDA_FUNCTION_NAME=$FUNCTION_NAME
KEEPWARM_RULE_ARN=$KEEPWARM_RULE_ARN
EOF

echo "Lambda provisioning complete. Values written to outputs.env."
