#!/usr/bin/env bash
# provision-keepwarm.sh — idempotent keep-warm setup for dcatch-lambda
# Creates (or updates) the EventBridge rule that pings Lambda every 5 minutes.
# Safe to re-run after a rebuild — all operations are idempotent.
# Run from repo root: bash infra/provision-keepwarm.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
source "$OUTPUTS"

REGION="us-east-2"
FUNCTION_NAME="dcatch-lambda"

echo "=== Keep-warm: EventBridge rule ==="

KEEPWARM_RULE_ARN=$(aws events put-rule \
  --name dcatch-lambda-keepwarm \
  --schedule-expression "rate(5 minutes)" \
  --state ENABLED \
  --description "Keep dcatch-lambda warm" \
  --tags Key=Project,Value=DCATCH \
  --region "$REGION" \
  --query RuleArn --output text)

# Remove any existing permission before re-adding (idempotent)
aws lambda remove-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-lambda-keepwarm \
  --region "$REGION" > /dev/null 2>&1 || true

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-lambda-keepwarm \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "$KEEPWARM_RULE_ARN" \
  --region "$REGION" > /dev/null

aws events put-targets \
  --rule dcatch-lambda-keepwarm \
  --targets "Id=dcatch-lambda-keepwarm-target,Arn=$LAMBDA_FUNCTION_ARN" \
  --region "$REGION" > /dev/null

echo "  Keep-warm rule ARN: $KEEPWARM_RULE_ARN"

# ─── Write outputs ────────────────────────────────────────────────────────────

grep -v "^KEEPWARM_RULE_ARN=" "$OUTPUTS" \
  > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"

cat >> "$OUTPUTS" <<EOF
KEEPWARM_RULE_ARN=$KEEPWARM_RULE_ARN
EOF

echo "Keep-warm provisioning complete. Value written to outputs.env."
