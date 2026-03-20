#!/usr/bin/env bash
# provision-apigw.sh — Phase 2
# Creates HTTP API v2 (API Gateway v2) with JWT authorizer (Cognito), /health (no auth)
# and $default catch-all route (JWT auth), auto-deployed to $default stage.
# Run from repo root: bash infra/provision-apigw.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
source "$OUTPUTS"

REGION="us-east-2"
FUNCTION_NAME="dcatch-lambda"

echo "=== Phase 2: API Gateway (HTTP API v2) ==="

LAMBDA_ARN=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --query Configuration.FunctionArn --output text)

COGNITO_ISSUER="https://cognito-idp.${REGION}.amazonaws.com/${COGNITO_USER_POOL_ID}"
LAMBDA_INVOKE_ARN="arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"

# ─── 1. Create HTTP API ───────────────────────────────────────────────────────

echo "Creating HTTP API dcatch-api..."

API_ID=$(aws apigatewayv2 create-api \
  --name dcatch-api \
  --protocol-type HTTP \
  --cors-configuration \
    AllowOrigins='["https://dcatch.hilldogs.net"]',AllowMethods='["GET","POST","PUT","DELETE","OPTIONS"]',AllowHeaders='["Content-Type","Authorization"]',MaxAge=300 \
  --region "$REGION" \
  --tags Project=DCATCH \
  --query ApiId --output text)

echo "  API ID: $API_ID"

# ─── 2. Lambda integration ────────────────────────────────────────────────────

echo "Creating Lambda integration..."

INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --integration-type AWS_PROXY \
  --integration-method POST \
  --integration-uri "$LAMBDA_INVOKE_ARN" \
  --payload-format-version 2.0 \
  --timeout-in-millis 30000 \
  --region "$REGION" \
  --query IntegrationId --output text)

echo "  Integration ID: $INTEGRATION_ID"

# ─── 3. JWT authorizer ────────────────────────────────────────────────────────

echo "Creating JWT authorizer..."

AUTHORIZER_ID=$(aws apigatewayv2 create-authorizer \
  --api-id "$API_ID" \
  --name dcatch-cognito-jwt \
  --authorizer-type JWT \
  --identity-source '$request.header.Authorization' \
  --jwt-configuration \
    Audience="[\"${COGNITO_CLIENT_ID}\"]",Issuer="${COGNITO_ISSUER}" \
  --region "$REGION" \
  --query AuthorizerId --output text)

echo "  Authorizer ID: $AUTHORIZER_ID"

# ─── 4. Routes ────────────────────────────────────────────────────────────────

echo "Creating GET /health route (no auth)..."

aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "GET /health" \
  --authorization-type NONE \
  --target "integrations/$INTEGRATION_ID" \
  --region "$REGION" > /dev/null

echo "Creating \$default route (JWT auth)..."

aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key '$default' \
  --authorization-type JWT \
  --authorizer-id "$AUTHORIZER_ID" \
  --target "integrations/$INTEGRATION_ID" \
  --region "$REGION" > /dev/null

# ─── 5. Auto-deploy stage ─────────────────────────────────────────────────────

echo "Creating auto-deploy \$default stage..."

aws apigatewayv2 create-stage \
  --api-id "$API_ID" \
  --stage-name '$default' \
  --auto-deploy \
  --region "$REGION" > /dev/null

# ─── 6. Lambda invoke permission ──────────────────────────────────────────────

echo "Granting Lambda invoke permission to API Gateway..."

# Remove first to allow idempotent re-runs
aws lambda remove-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-apigw-httpv2 \
  --region "$REGION" 2>/dev/null || true

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id dcatch-apigw-httpv2 \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$AWS_ACCOUNT_ID:$API_ID/*/*" \
  --region "$REGION" > /dev/null

# ─── Write outputs ────────────────────────────────────────────────────────────

APIGW_BASE_URL="https://$API_ID.execute-api.$REGION.amazonaws.com"
echo "  Base URL: $APIGW_BASE_URL"

grep -v "^APIGW_ID=" "$OUTPUTS" \
  | grep -v "^APIGW_BASE_URL=" \
  | grep -v "^APIGW_AUTHORIZER_ID=" \
  > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"

cat >> "$OUTPUTS" <<ENVEOF
APIGW_ID=$API_ID
APIGW_BASE_URL=$APIGW_BASE_URL
APIGW_AUTHORIZER_ID=$AUTHORIZER_ID
ENVEOF

echo "API Gateway provisioning complete. Values written to outputs.env."
echo ""
echo "Health check: curl $APIGW_BASE_URL/health"
