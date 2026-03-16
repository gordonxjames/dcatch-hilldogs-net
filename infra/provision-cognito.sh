#!/usr/bin/env bash
# provision-cognito.sh — Phase 1
# Creates Cognito user pool and app client for dcatch.
# Requires provision-iam.sh to have run first (needs COGNITO_SMS_ROLE_ARN).
# Run from repo root: bash infra/provision-cognito.sh
# Appends resource IDs to infra/outputs.env

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"

if [[ ! -f "$OUTPUTS" ]]; then
  echo "ERROR: outputs.env not found. Run provision-iam.sh first."
  exit 1
fi

source "$OUTPUTS"

if [[ -z "${COGNITO_SMS_ROLE_ARN:-}" ]]; then
  echo "ERROR: COGNITO_SMS_ROLE_ARN not set. Run provision-iam.sh first."
  exit 1
fi

REGION="us-east-2"
EXTERNAL_ID="dcatch-cognito-sms"

# ─── 1. User pool ────────────────────────────────────────────────────────────
# Design decisions:
#   - Username is the primary immutable identifier (no --username-attributes flag)
#   - Email is an alias: users can sign in with either username or email
#   - Email is the auto-verified attribute (account confirmation code sent to email)
#   - Phone is optional at signup; can be added/verified in Account Settings for future SMS MFA
#   - MFA: OPTIONAL — TOTP (authenticator app) supported; SMS MFA deferred (DCATCH-23)
#   - TOTP MFA enabled via set-user-pool-mfa-config after pool creation (see step 3 below)
#   - Cognito built-in email for verification codes (no SES needed)
#   - Password: 8 chars min, upper + lower + numbers required

echo "Creating dcatch-user-pool..."
COGNITO_USER_POOL_ID=$(aws cognito-idp create-user-pool \
  --pool-name dcatch-user-pool \
  --region "$REGION" \
  --alias-attributes email \
  --auto-verified-attributes email \
  --mfa-configuration OPTIONAL \
  --sms-configuration "SnsCallerArn=$COGNITO_SMS_ROLE_ARN,ExternalId=$EXTERNAL_ID" \
  --sms-authentication-message "Your Delta Catcher verification code is {####}" \
  --sms-verification-message "Your Delta Catcher verification code is {####}" \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": false,
      "TemporaryPasswordValidityDays": 7
    }
  }' \
  --schema '[
    {
      "Name": "email",
      "AttributeDataType": "String",
      "Required": true,
      "Mutable": true
    },
    {
      "Name": "phone_number",
      "AttributeDataType": "String",
      "Required": false,
      "Mutable": true
    }
  ]' \
  --account-recovery-setting '{
    "RecoveryMechanisms": [
      {"Priority": 1, "Name": "verified_email"},
      {"Priority": 2, "Name": "verified_phone_number"}
    ]
  }' \
  --user-pool-tags Project=DCATCH \
  --query UserPool.Id --output text)

echo "  User pool: $COGNITO_USER_POOL_ID"

# Note: post-confirmation Lambda trigger attached in Phase 2 after Lambda is created.

# ─── 2. App client ───────────────────────────────────────────────────────────

echo "Creating dcatch-web-client..."
COGNITO_CLIENT_ID=$(aws cognito-idp create-user-pool-client \
  --user-pool-id "$COGNITO_USER_POOL_ID" \
  --client-name dcatch-web-client \
  --no-generate-secret \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH ALLOW_REFRESH_TOKEN_AUTH ALLOW_USER_PASSWORD_AUTH \
  --prevent-user-existence-errors ENABLED \
  --region "$REGION" \
  --query UserPoolClient.ClientId --output text)

echo "  Client ID: $COGNITO_CLIENT_ID"

# ─── 3. Enable TOTP MFA ──────────────────────────────────────────────────────
# SMS MFA remains configured (DCATCH-23 blocks delivery); TOTP is the active MFA method.

echo "Enabling TOTP MFA on user pool..."
aws cognito-idp set-user-pool-mfa-config \
  --user-pool-id "$COGNITO_USER_POOL_ID" \
  --mfa-configuration OPTIONAL \
  --software-token-mfa-configuration Enabled=true \
  --sms-mfa-configuration "SmsAuthenticationMessage='Your Delta Catcher verification code is {####}',SmsConfiguration={SnsCallerArn=$COGNITO_SMS_ROLE_ARN,ExternalId=$EXTERNAL_ID,SnsRegion=$REGION}" \
  --region "$REGION" > /dev/null

echo "  TOTP MFA enabled."

# ─── Write outputs ───────────────────────────────────────────────────────────

for key in COGNITO_USER_POOL_ID COGNITO_CLIENT_ID; do
  grep -v "^${key}=" "$OUTPUTS" > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"
done

cat >> "$OUTPUTS" <<EOF
COGNITO_USER_POOL_ID=$COGNITO_USER_POOL_ID
COGNITO_CLIENT_ID=$COGNITO_CLIENT_ID
EOF

echo "Cognito provisioning complete. Values written to outputs.env."
