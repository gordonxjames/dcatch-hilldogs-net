#!/usr/bin/env bash
# provision-apigw.sh — Phase 2
# Creates REST API Gateway with Cognito authorizer, /health (no auth) and
# /{proxy+} (Cognito auth) resources, deploys to stage v1.
# Run from repo root: bash infra/provision-apigw.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
source "$OUTPUTS"

REGION="us-east-2"
FUNCTION_NAME="dcatch-api"

echo "=== Phase 2: API Gateway ==="

# ─── 1. Create REST API ───────────────────────────────────────────────────────

echo "Creating REST API dcatch-api-gw..."

API_ID=$(aws apigateway create-rest-api \
  --name dcatch-api-gw \
  --description "DCATCH API Gateway — Phase 2" \
  --endpoint-configuration types=REGIONAL \
  --region "$REGION" \
  --tags Project=DCATCH \
  --query id --output text)

echo "  API ID: $API_ID"

ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --region "$REGION" \
  --query 'items[?path==`/`].id' --output text)

# ─── 2. Cognito authorizer ────────────────────────────────────────────────────

echo "Creating Cognito authorizer..."

AUTHORIZER_ID=$(aws apigateway create-authorizer \
  --rest-api-id "$API_ID" \
  --name dcatch-cognito-auth \
  --type COGNITO_USER_POOLS \
  --provider-arns "arn:aws:cognito-idp:$REGION:$AWS_ACCOUNT_ID:userpool/$COGNITO_USER_POOL_ID" \
  --identity-source "method.request.header.Authorization" \
  --region "$REGION" \
  --query id --output text)

echo "  Authorizer ID: $AUTHORIZER_ID"

LAMBDA_ARN=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --query Configuration.FunctionArn --output text)

INTEGRATION_URI="arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

# ─── 3. /health resource — GET, no auth ──────────────────────────────────────

echo "Creating /health resource (no auth)..."

HEALTH_ID=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_ID" \
  --path-part health \
  --region "$REGION" \
  --query id --output text)

aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$HEALTH_ID" \
  --http-method GET \
  --authorization-type NONE \
  --region "$REGION" > /dev/null

aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$HEALTH_ID" \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "$INTEGRATION_URI" \
  --region "$REGION" > /dev/null

# ─── 4. /{proxy+} resource — ANY, Cognito auth ────────────────────────────────

echo "Creating /{proxy+} resource (Cognito auth)..."

PROXY_ID=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_ID" \
  --path-part "{proxy+}" \
  --region "$REGION" \
  --query id --output text)

aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$PROXY_ID" \
  --http-method ANY \
  --authorization-type COGNITO_USER_POOLS \
  --authorizer-id "$AUTHORIZER_ID" \
  --region "$REGION" > /dev/null

aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$PROXY_ID" \
  --http-method ANY \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "$INTEGRATION_URI" \
  --region "$REGION" > /dev/null

# ─── 5. Lambda invoke permissions ─────────────────────────────────────────────

echo "Granting Lambda invoke permissions to API Gateway..."

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-apigw-health \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$AWS_ACCOUNT_ID:$API_ID/*/GET/health" \
  --region "$REGION" > /dev/null

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-apigw-proxy \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$AWS_ACCOUNT_ID:$API_ID/*/*" \
  --region "$REGION" > /dev/null

# ─── 6. Deploy to stage v1 ───────────────────────────────────────────────────

echo "Deploying to stage v1..."

aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name v1 \
  --description "Phase 2 initial deployment" \
  --region "$REGION" > /dev/null

APIGW_BASE_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/v1"
echo "  Base URL: $APIGW_BASE_URL"

# ─── Write outputs ────────────────────────────────────────────────────────────

grep -v "^APIGW_ID=" "$OUTPUTS" \
  | grep -v "^APIGW_BASE_URL=" \
  | grep -v "^APIGW_AUTHORIZER_ID=" \
  > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"

cat >> "$OUTPUTS" <<EOF
APIGW_ID=$API_ID
APIGW_BASE_URL=$APIGW_BASE_URL
APIGW_AUTHORIZER_ID=$AUTHORIZER_ID
EOF

echo "API Gateway provisioning complete. Values written to outputs.env."
echo ""
echo "Health check: curl $APIGW_BASE_URL/health"
