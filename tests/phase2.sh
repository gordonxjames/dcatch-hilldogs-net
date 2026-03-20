#!/usr/bin/env bash
# tests/phase2.sh — Phase 2 infrastructure tests
# Verifies: Lambda function, Cognito trigger,
#           API Gateway HTTP v2 (JWT authorizer, /health, $default), HTTP health check.
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
assert_eq "Lambda memory is 128 MB" "128" "$LAMBDA_MEMORY"

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
section "Lambda — CloudWatch log retention"

# MSYS_NO_PATHCONV prevents Git Bash on Windows from mangling /aws/lambda/... paths
LAMBDA_LOG_RETENTION=$(MSYS_NO_PATHCONV=1 aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/$LAMBDA_FUNCTION_NAME" --region "$REGION" \
  --query 'logGroups[0].retentionInDays' --output text 2>/dev/null || echo "")
assert_eq "Lambda log group retention is 7 days" "7" "$LAMBDA_LOG_RETENTION"

# ═══════════════════════════════════════════════════════════════════════════════
section "Cognito — post-confirmation trigger"

TRIGGER_ARN=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.LambdaConfig.PostConfirmation' --output text 2>/dev/null || echo "")
assert_eq "Cognito post-confirmation trigger set to Lambda" "$LAMBDA_FUNCTION_ARN" "$TRIGGER_ARN"

# ═══════════════════════════════════════════════════════════════════════════════
section "API Gateway — HTTP API v2"

API_NAME=$(aws apigatewayv2 get-api \
  --api-id "$APIGW_ID" --region "$REGION" \
  --query Name --output text 2>/dev/null || echo "")
assert_eq "HTTP API name is dcatch-api" "dcatch-api" "$API_NAME"

API_PROTOCOL=$(aws apigatewayv2 get-api \
  --api-id "$APIGW_ID" --region "$REGION" \
  --query ProtocolType --output text 2>/dev/null || echo "")
assert_eq "HTTP API protocol type is HTTP" "HTTP" "$API_PROTOCOL"

API_TAG=$(aws apigatewayv2 get-api \
  --api-id "$APIGW_ID" --region "$REGION" \
  --query 'Tags.Project' --output text 2>/dev/null || echo "")
assert_eq "HTTP API tagged Project=DCATCH" "DCATCH" "$API_TAG"

CORS_ORIGIN=$(aws apigatewayv2 get-api \
  --api-id "$APIGW_ID" --region "$REGION" \
  --query 'CorsConfiguration.AllowOrigins[0]' --output text 2>/dev/null || echo "")
assert_eq "HTTP API CORS allows dcatch.hilldogs.net" "https://dcatch.hilldogs.net" "$CORS_ORIGIN"

# ═══════════════════════════════════════════════════════════════════════════════
section "API Gateway — JWT authorizer"

AUTH_TYPE=$(aws apigatewayv2 get-authorizer \
  --api-id "$APIGW_ID" --authorizer-id "$APIGW_AUTHORIZER_ID" --region "$REGION" \
  --query AuthorizerType --output text 2>/dev/null || echo "")
assert_eq "Authorizer type is JWT" "JWT" "$AUTH_TYPE"

AUTH_NAME=$(aws apigatewayv2 get-authorizer \
  --api-id "$APIGW_ID" --authorizer-id "$APIGW_AUTHORIZER_ID" --region "$REGION" \
  --query Name --output text 2>/dev/null || echo "")
assert_eq "Authorizer name is dcatch-cognito-jwt" "dcatch-cognito-jwt" "$AUTH_NAME"

AUTH_ISSUER=$(aws apigatewayv2 get-authorizer \
  --api-id "$APIGW_ID" --authorizer-id "$APIGW_AUTHORIZER_ID" --region "$REGION" \
  --query 'JwtConfiguration.Issuer' --output text 2>/dev/null || echo "")
assert_contains "Authorizer JWT issuer references Cognito pool" "$AUTH_ISSUER" "$COGNITO_USER_POOL_ID"

AUTH_AUDIENCE=$(aws apigatewayv2 get-authorizer \
  --api-id "$APIGW_ID" --authorizer-id "$APIGW_AUTHORIZER_ID" --region "$REGION" \
  --query 'JwtConfiguration.Audience[0]' --output text 2>/dev/null || echo "")
assert_eq "Authorizer JWT audience is Cognito client ID" "$COGNITO_CLIENT_ID" "$AUTH_AUDIENCE"

# ═══════════════════════════════════════════════════════════════════════════════
section "API Gateway — routes"

HEALTH_AUTH=$(aws apigatewayv2 get-routes \
  --api-id "$APIGW_ID" --region "$REGION" \
  --query 'Items[?RouteKey==`GET /health`].AuthorizationType' --output text 2>/dev/null || echo "")
assert_eq "GET /health route has no auth (NONE)" "NONE" "$HEALTH_AUTH"

DEFAULT_AUTH=$(aws apigatewayv2 get-routes \
  --api-id "$APIGW_ID" --region "$REGION" \
  --query 'Items[?RouteKey==`$default`].AuthorizationType' --output text 2>/dev/null || echo "")
assert_eq "\$default route uses JWT auth" "JWT" "$DEFAULT_AUTH"

# ═══════════════════════════════════════════════════════════════════════════════
section "API Gateway — stage"

STAGE_AUTODEPLOY=$(aws apigatewayv2 get-stage \
  --api-id "$APIGW_ID" --stage-name '$default' --region "$REGION" \
  --query AutoDeploy --output text 2>/dev/null || echo "")
assert_eq "\$default stage has AutoDeploy enabled" "True" "$STAGE_AUTODEPLOY"

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

# ═══════════════════════════════════════════════════════════════════════════════
section "HTTP — /health CORS headers"

# HTTP API v2 managed CORS only returns Allow-Origin when request has an Origin header.
# Allow-Methods and Allow-Headers are returned on OPTIONS preflight.

GET_CORS=$(curl -si --max-time 15 \
  -H "Origin: https://dcatch.hilldogs.net" \
  "${APIGW_BASE_URL}/health" 2>/dev/null || echo "")
CORS_ORIGIN=$(echo "$GET_CORS" | grep -i 'access-control-allow-origin' | tr -d '\r' | awk '{print $2}')
assert_eq "GET /health has CORS Allow-Origin: https://dcatch.hilldogs.net" \
  "https://dcatch.hilldogs.net" "$CORS_ORIGIN"

OPTIONS_CORS=$(curl -si --max-time 15 -X OPTIONS \
  -H "Origin: https://dcatch.hilldogs.net" \
  -H "Access-Control-Request-Method: GET" \
  "${APIGW_BASE_URL}/health" 2>/dev/null || echo "")
OPTIONS_METHODS=$(echo "$OPTIONS_CORS" | grep -i 'access-control-allow-methods' | tr -d '\r')
assert_contains "OPTIONS preflight has CORS Allow-Methods" "$OPTIONS_METHODS" "GET"

OPTIONS_HEADERS=$(echo "$OPTIONS_CORS" | grep -i 'access-control-allow-headers' | tr -d '\r')
assert_contains "OPTIONS preflight has CORS Allow-Headers with authorization" "$OPTIONS_HEADERS" "authorization"

# ── Standalone summary ─────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  print_summary "Phase 2"
fi
