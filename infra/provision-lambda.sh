#!/usr/bin/env bash
# provision-lambda.sh — Phase 2
# Creates dcatch-api Lambda in VPC, attaches Cognito post-confirmation trigger,
# and creates EventBridge keep-warm rule (every 5 minutes).
# Run from repo root: bash infra/provision-lambda.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
source "$OUTPUTS"

REGION="us-east-2"
FUNCTION_NAME="dcatch-api"
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
  --memory-size 256 \
  --region "$REGION" \
  --tags Project=DCATCH \
  --query FunctionArn --output text)

echo "  Lambda ARN: $LAMBDA_FUNCTION_ARN"

echo "Waiting for Lambda to become Active..."
aws lambda wait function-active \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION"

# ─── 2. Cognito post-confirmation trigger ────────────────────────────────────

echo "Attaching Cognito post-confirmation trigger..."

aws cognito-idp update-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" \
  --lambda-config "PostConfirmation=$LAMBDA_FUNCTION_ARN" \
  --region "$REGION"

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-cognito-postconfirmation \
  --action lambda:InvokeFunction \
  --principal cognito-idp.amazonaws.com \
  --source-arn "arn:aws:cognito-idp:$REGION:$AWS_ACCOUNT_ID:userpool/$COGNITO_USER_POOL_ID" \
  --region "$REGION" > /dev/null

echo "  Cognito trigger attached."

# ─── 3. EventBridge keep-warm rule ───────────────────────────────────────────

echo "Creating EventBridge keep-warm rule (rate 5 minutes)..."

RULE_ARN=$(aws events put-rule \
  --name dcatch-lambda-keepwarm \
  --schedule-expression "rate(5 minutes)" \
  --state ENABLED \
  --tags Key=Project,Value=DCATCH \
  --region "$REGION" \
  --query RuleArn --output text)

aws events put-targets \
  --rule dcatch-lambda-keepwarm \
  --targets "Id=dcatch-api-keepwarm,Arn=$LAMBDA_FUNCTION_ARN" \
  --region "$REGION" > /dev/null

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-eventbridge-keepwarm \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "$RULE_ARN" \
  --region "$REGION" > /dev/null

echo "  Keep-warm rule ARN: $RULE_ARN"

# ─── Write outputs ────────────────────────────────────────────────────────────

grep -v "^LAMBDA_FUNCTION_ARN=" "$OUTPUTS" \
  | grep -v "^LAMBDA_FUNCTION_NAME=" \
  > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"

cat >> "$OUTPUTS" <<EOF
LAMBDA_FUNCTION_ARN=$LAMBDA_FUNCTION_ARN
LAMBDA_FUNCTION_NAME=$FUNCTION_NAME
EOF

echo "Lambda provisioning complete. Values written to outputs.env."
