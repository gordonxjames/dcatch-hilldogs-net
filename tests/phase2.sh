#!/usr/bin/env bash
# tests/phase2.sh — Phase 2 infrastructure tests
# Verifies: Lambda function, Cognito trigger, EventBridge keep-warm rule,
#           API Gateway (REST API, authorizer, /health, /{proxy+}), HTTP health check.
# No external dependencies beyond AWS CLI and curl.
#
# Sourced by tests/run-all.sh; can also be run standalone:
#   bash tests/phase2.sh

SCRIPT_DIR_P2="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_P2="$(cd "$SCRIPT_DIR_P2/.." && pwd)"

# Bootstrap when run standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$SCRIPT_DIR_P2/lib.sh"
  echo ""
  echo -e "${BOLD}━━━ Phase 2 Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
fi

source "$REPO_ROOT_P2/infra/outputs.env"
REGION="us-east-2"

# ═══════════════════════════════════════════════════════════════════════════════
section "Lambda — function"

LAMBDA_RUNTIME=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query Runtime --output text 2>/dev/null || echo "")
assert_eq "Lambda runtime is nodejs20.x" "nodejs20.x" "$LAMBDA_RUNTIME"

LAMBDA_HANDLER=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query Handler --output text 2>/dev/null || echo "")
assert_eq "Lambda handler is index.handler" "index.handler" "$LAMBDA_HANDLER"

LAMBDA_ROLE=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query Role --output text 2>/dev/null || echo "")
assert_eq "Lambda role matches outputs.env" "$LAMBDA_ROLE_ARN" "$LAMBDA_ROLE"

LAMBDA_STATE=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query State --output text 2>/dev/null || echo "")
assert_eq "Lambda state is Active" "Active" "$LAMBDA_STATE"

LAMBDA_TIMEOUT=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query Timeout --output text 2>/dev/null || echo "")
assert_eq "Lambda timeout is 30s" "30" "$LAMBDA_TIMEOUT"

LAMBDA_MEMORY=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query MemorySize --output text 2>/dev/null || echo "")
assert_eq "Lambda memory is 256 MB" "256" "$LAMBDA_MEMORY"

LAMBDA_ARN=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query FunctionArn --output text 2>/dev/null || echo "")
assert_eq "Lambda ARN matches outputs.env" "$LAMBDA_FUNCTION_ARN" "$LAMBDA_ARN"

# ═══════════════════════════════════════════════════════════════════════════════
section "Lambda — VPC config"

LAMBDA_SUBNETS=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query 'VpcConfig.SubnetIds' --output text 2>/dev/null || echo "")
assert_contains "Lambda in subnet 2a" "$LAMBDA_SUBNETS" "$SUBNET_2A_ID"
assert_contains "Lambda in subnet 2b" "$LAMBDA_SUBNETS" "$SUBNET_2B_ID"

LAMBDA_SG=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query 'VpcConfig.SecurityGroupIds[0]' --output text 2>/dev/null || echo "")
assert_eq "Lambda uses sg-lambda" "$SG_LAMBDA_ID" "$LAMBDA_SG"

LAMBDA_VPC=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query 'VpcConfig.VpcId' --output text 2>/dev/null || echo "")
assert_eq "Lambda in correct VPC" "$VPC_ID" "$LAMBDA_VPC"

# ═══════════════════════════════════════════════════════════════════════════════
section "Lambda — tags"

LAMBDA_TAG=$(aws lambda list-tags \
  --resource "$LAMBDA_FUNCTION_ARN" --region "$REGION" \
  --query 'Tags.Project' --output text 2>/dev/null || echo "")
assert_eq "Lambda tagged Project=DCATCH" "DCATCH" "$LAMBDA_TAG"

# ═══════════════════════════════════════════════════════════════════════════════
section "Cognito — post-confirmation trigger"

TRIGGER_ARN=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.LambdaConfig.PostConfirmation' --output text 2>/dev/null || echo "")
assert_eq "Cognito post-confirmation trigger set to Lambda" "$LAMBDA_FUNCTION_ARN" "$TRIGGER_ARN"

# ═══════════════════════════════════════════════════════════════════════════════
section "EventBridge — keep-warm rule"

RULE_STATE=$(aws events describe-rule \
  --name dcatch-lambda-keepwarm --region "$REGION" \
  --query State --output text 2>/dev/null || echo "")
assert_eq "Keep-warm rule is ENABLED" "ENABLED" "$RULE_STATE"

RULE_SCHEDULE=$(aws events describe-rule \
  --name dcatch-lambda-keepwarm --region "$REGION" \
  --query ScheduleExpression --output text 2>/dev/null || echo "")
assert_eq "Keep-warm rule schedule is rate(5 minutes)" "rate(5 minutes)" "$RULE_SCHEDULE"

RULE_TARGET=$(aws events list-targets-by-rule \
  --rule dcatch-lambda-keepwarm --region "$REGION" \
  --query 'Targets[0].Arn' --output text 2>/dev/null || echo "")
assert_eq "Keep-warm rule targets Lambda" "$LAMBDA_FUNCTION_ARN" "$RULE_TARGET"

# ═══════════════════════════════════════════════════════════════════════════════
section "API Gateway — REST API"

API_NAME=$(aws apigateway get-rest-api \
  --rest-api-id "$APIGW_ID" --region "$REGION" \
  --query name --output text 2>/dev/null || echo "")
assert_eq "REST API name is dcatch-api-gw" "dcatch-api-gw" "$API_NAME"

API_ENDPOINT=$(aws apigateway get-rest-api \
  --rest-api-id "$APIGW_ID" --region "$REGION" \
  --query 'endpointConfiguration.types[0]' --output text 2>/dev/null || echo "")
assert_eq "REST API endpoint type is REGIONAL" "REGIONAL" "$API_ENDPOINT"

API_TAG=$(aws apigateway get-tags \
  --resource-arn "arn:aws:apigateway:$REGION::/restapis/$APIGW_ID" --region "$REGION" \
  --query 'tags.Project' --output text 2>/dev/null || echo "")
assert_eq "REST API tagged Project=DCATCH" "DCATCH" "$API_TAG"

# ═══════════════════════════════════════════════════════════════════════════════
section "API Gateway — Cognito authorizer"

AUTH_TYPE=$(aws apigateway get-authorizer \
  --rest-api-id "$APIGW_ID" --authorizer-id "$APIGW_AUTHORIZER_ID" --region "$REGION" \
  --query type --output text 2>/dev/null || echo "")
assert_eq "Authorizer type is COGNITO_USER_POOLS" "COGNITO_USER_POOLS" "$AUTH_TYPE"

AUTH_NAME=$(aws apigateway get-authorizer \
  --rest-api-id "$APIGW_ID" --authorizer-id "$APIGW_AUTHORIZER_ID" --region "$REGION" \
  --query name --output text 2>/dev/null || echo "")
assert_eq "Authorizer name is dcatch-cognito-auth" "dcatch-cognito-auth" "$AUTH_NAME"

AUTH_IDENTITY=$(aws apigateway get-authorizer \
  --rest-api-id "$APIGW_ID" --authorizer-id "$APIGW_AUTHORIZER_ID" --region "$REGION" \
  --query identitySource --output text 2>/dev/null || echo "")
assert_eq "Authorizer identity source is Authorization header" \
  "method.request.header.Authorization" "$AUTH_IDENTITY"

AUTH_POOL=$(aws apigateway get-authorizer \
  --rest-api-id "$APIGW_ID" --authorizer-id "$APIGW_AUTHORIZER_ID" --region "$REGION" \
  --query 'providerARNs[0]' --output text 2>/dev/null || echo "")
assert_contains "Authorizer points to correct Cognito pool" "$AUTH_POOL" "$COGNITO_USER_POOL_ID"

# ═══════════════════════════════════════════════════════════════════════════════
section "API Gateway — resources"

HEALTH_METHOD=$(aws apigateway get-resources \
  --rest-api-id "$APIGW_ID" --region "$REGION" \
  --embed methods \
  --query 'items[?path==`/health`].resourceMethods.GET.authorizationType' \
  --output text 2>/dev/null || echo "")
assert_eq "/health GET has no auth" "NONE" "$HEALTH_METHOD"

PROXY_METHOD=$(aws apigateway get-resources \
  --rest-api-id "$APIGW_ID" --region "$REGION" \
  --embed methods \
  --query 'items[?path==`/{proxy+}`].resourceMethods.ANY.authorizationType' \
  --output text 2>/dev/null || echo "")
assert_eq "/{proxy+} ANY uses Cognito auth" "COGNITO_USER_POOLS" "$PROXY_METHOD"

# ═══════════════════════════════════════════════════════════════════════════════
section "API Gateway — stage"

STAGE_STATE=$(aws apigateway get-stage \
  --rest-api-id "$APIGW_ID" --stage-name v1 --region "$REGION" \
  --query stageName --output text 2>/dev/null || echo "")
assert_eq "Stage v1 exists" "v1" "$STAGE_STATE"

# ═══════════════════════════════════════════════════════════════════════════════
section "HTTP — /health endpoint"

HEALTH_RESPONSE=$(curl -s -o /tmp/dcatch_health.json -w "%{http_code}" \
  --max-time 15 "${APIGW_BASE_URL}/health" 2>/dev/null || echo "000")
assert_eq "GET /health returns 200" "200" "$HEALTH_RESPONSE"

if [[ -f /tmp/dcatch_health.json ]]; then
  HEALTH_STATUS=$(cat /tmp/dcatch_health.json | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")
  assert_eq "GET /health body has status ok" "ok" "$HEALTH_STATUS"

  HEALTH_SERVICE=$(cat /tmp/dcatch_health.json | grep -o '"service":"[^"]*"' | cut -d'"' -f4 || echo "")
  assert_eq "GET /health body has service dcatch-api" "dcatch-api" "$HEALTH_SERVICE"
fi

# ── Standalone summary ─────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  print_summary "Phase 2"
fi
