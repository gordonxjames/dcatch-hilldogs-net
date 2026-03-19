#!/usr/bin/env bash
# tests/phase5.sh — Keep-warm EventBridge rule tests
#
# Verifies: dcatch-lambda-keepwarm rule exists, is ENABLED, fires on rate(5 minutes),
#           targets dcatch-lambda, is tagged Project=DCATCH, Lambda resource policy
#           grants EventBridge invoke permission, and Lambda returns { warmed: true }
#           when invoked with a scheduled-event payload.
#
# Sourced by tests/run-all.sh; can also be run standalone:
#   bash tests/phase5.sh

SCRIPT_DIR_P5="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_P5="$(cd "$SCRIPT_DIR_P5/.." && pwd)"

# Bootstrap when run standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$SCRIPT_DIR_P5/lib.sh"
  echo ""
  echo -e "${BOLD}━━━ Phase 5 Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
fi

source "$REPO_ROOT_P5/infra/outputs.env"
REGION="us-east-2"
RULE_NAME="dcatch-lambda-keepwarm"

# ═══════════════════════════════════════════════════════════════════════════════
section "Keep-warm — EventBridge rule exists"

RULE_STATE=$(aws events describe-rule \
  --name "$RULE_NAME" --region "$REGION" \
  --query State --output text 2>/dev/null || echo "")
assert_eq "Rule $RULE_NAME exists and is ENABLED" "ENABLED" "$RULE_STATE"

RULE_SCHEDULE=$(aws events describe-rule \
  --name "$RULE_NAME" --region "$REGION" \
  --query ScheduleExpression --output text 2>/dev/null || echo "")
assert_eq "Rule schedule is rate(5 minutes)" "rate(5 minutes)" "$RULE_SCHEDULE"

RULE_DESC=$(aws events describe-rule \
  --name "$RULE_NAME" --region "$REGION" \
  --query Description --output text 2>/dev/null || echo "")
assert_contains "Rule description references dcatch-lambda" "$RULE_DESC" "dcatch-lambda"

RULE_ARN=$(aws events describe-rule \
  --name "$RULE_NAME" --region "$REGION" \
  --query Arn --output text 2>/dev/null || echo "")
assert_eq "Rule ARN matches outputs.env" "$KEEPWARM_RULE_ARN" "$RULE_ARN"

# ═══════════════════════════════════════════════════════════════════════════════
section "Keep-warm — EventBridge rule target"

TARGET_ARN=$(aws events list-targets-by-rule \
  --rule "$RULE_NAME" --region "$REGION" \
  --query 'Targets[0].Arn' --output text 2>/dev/null || echo "")
assert_eq "Rule targets dcatch-lambda" "$LAMBDA_FUNCTION_ARN" "$TARGET_ARN"

TARGET_ID=$(aws events list-targets-by-rule \
  --rule "$RULE_NAME" --region "$REGION" \
  --query 'Targets[0].Id' --output text 2>/dev/null || echo "")
assert_eq "Rule target ID is dcatch-lambda-keepwarm-target" "dcatch-lambda-keepwarm-target" "$TARGET_ID"

# ═══════════════════════════════════════════════════════════════════════════════
section "Keep-warm — rule tag"

RULE_TAG=$(aws events list-tags-for-resource \
  --resource-arn "$KEEPWARM_RULE_ARN" --region "$REGION" \
  --query 'Tags[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "Rule tagged Project=DCATCH" "DCATCH" "$RULE_TAG"

# ═══════════════════════════════════════════════════════════════════════════════
section "Keep-warm — Lambda resource policy"

POLICY=$(aws lambda get-policy \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query Policy --output text 2>/dev/null || echo "")
assert_contains "Lambda policy has dcatch-lambda-keepwarm statement" \
  "$POLICY" "dcatch-lambda-keepwarm"
assert_contains "Lambda policy grants events.amazonaws.com" \
  "$POLICY" "events.amazonaws.com"

# ═══════════════════════════════════════════════════════════════════════════════
section "Keep-warm — Lambda warm-ping response"

WARM_PAYLOAD='{"source":"aws.events","detail-type":"Scheduled Event","detail":{}}'
WARM_RESPONSE=$(aws lambda invoke \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --region "$REGION" \
  --payload "$WARM_PAYLOAD" \
  --cli-binary-format raw-in-base64-out \
  /tmp/dcatch_warm.json \
  --query StatusCode --output text 2>/dev/null || echo "")
assert_eq "Lambda warm invoke returns status 200" "200" "$WARM_RESPONSE"

if [[ -f /tmp/dcatch_warm.json ]]; then
  WARM_BODY=$(cat /tmp/dcatch_warm.json)
  # Body is JSON-encoded inside the proxy response; check escaped form
  assert_contains "Lambda warm response body contains warmed:true" \
    "$WARM_BODY" 'warmed.*true'
fi

# ── Standalone summary ─────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  print_summary "Phase 5"
fi
