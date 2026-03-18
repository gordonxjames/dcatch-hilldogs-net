#!/usr/bin/env bash
# tests/phase3.sh — Phase 3 infrastructure tests
# Verifies: CloudFront OAC, distribution (deployed, aliases, cert, SPA errors),
#           S3 bucket policy (OAC-only), Route 53 DNS record, HTTPS endpoint.
# No external dependencies beyond AWS CLI and curl.
#
# Sourced by tests/run-all.sh; can also be run standalone:
#   bash tests/phase3.sh

SCRIPT_DIR_P3="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_P3="$(cd "$SCRIPT_DIR_P3/.." && pwd)"

# Bootstrap when run standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$SCRIPT_DIR_P3/lib.sh"
  echo ""
  echo -e "${BOLD}━━━ Phase 3 Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
fi

source "$REPO_ROOT_P3/infra/outputs.env"
DOMAIN="dcatch.hilldogs.net"
HOSTED_ZONE_ID="Z09301025V2NYG3DJ3TL"
CERT_ARN="arn:aws:acm:us-east-1:420030147545:certificate/36daeb2b-20e3-4910-bbe1-acac865f5adb"
BUCKET="dcatch-s3-frontend"

# ═══════════════════════════════════════════════════════════════════════════════
section "CloudFront — outputs.env"

assert_not_empty "CF_OAC_ID is set in outputs.env"          "$CF_OAC_ID"
assert_not_empty "CF_DISTRIBUTION_ID is set in outputs.env" "$CF_DISTRIBUTION_ID"
assert_not_empty "CF_DOMAIN is set in outputs.env"          "$CF_DOMAIN"

# ═══════════════════════════════════════════════════════════════════════════════
section "CloudFront — OAC"

OAC_SIGNING_PROTOCOL=$(aws cloudfront get-origin-access-control \
  --id "$CF_OAC_ID" \
  --query "OriginAccessControl.OriginAccessControlConfig.SigningProtocol" \
  --output text 2>/dev/null || echo "")
assert_eq "OAC signing protocol is sigv4" "sigv4" "$OAC_SIGNING_PROTOCOL"

OAC_SIGNING_BEHAVIOR=$(aws cloudfront get-origin-access-control \
  --id "$CF_OAC_ID" \
  --query "OriginAccessControl.OriginAccessControlConfig.SigningBehavior" \
  --output text 2>/dev/null || echo "")
assert_eq "OAC signing behavior is always" "always" "$OAC_SIGNING_BEHAVIOR"

OAC_ORIGIN_TYPE=$(aws cloudfront get-origin-access-control \
  --id "$CF_OAC_ID" \
  --query "OriginAccessControl.OriginAccessControlConfig.OriginAccessControlOriginType" \
  --output text 2>/dev/null || echo "")
assert_eq "OAC origin type is s3" "s3" "$OAC_ORIGIN_TYPE"

# ═══════════════════════════════════════════════════════════════════════════════
section "CloudFront — distribution"

CF_STATUS=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.Status" --output text 2>/dev/null || echo "")
assert_eq "Distribution status is Deployed" "Deployed" "$CF_STATUS"

CF_ENABLED=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.DistributionConfig.Enabled" --output text 2>/dev/null || echo "")
assert_eq "Distribution is enabled" "True" "$CF_ENABLED"

CF_ALIAS=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.DistributionConfig.Aliases.Items[0]" --output text 2>/dev/null || echo "")
assert_eq "Distribution alias is dcatch.hilldogs.net" "$DOMAIN" "$CF_ALIAS"

CF_CERT=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.DistributionConfig.ViewerCertificate.ACMCertificateArn" --output text 2>/dev/null || echo "")
assert_eq "Distribution uses correct ACM cert" "$CERT_ARN" "$CF_CERT"

CF_DEFAULT_ROOT=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.DistributionConfig.DefaultRootObject" --output text 2>/dev/null || echo "")
assert_eq "Default root object is index.html" "index.html" "$CF_DEFAULT_ROOT"

CF_PRICE_CLASS=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.DistributionConfig.PriceClass" --output text 2>/dev/null || echo "")
assert_eq "Price class is PriceClass_100" "PriceClass_100" "$CF_PRICE_CLASS"

CF_ERR_403=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.DistributionConfig.CustomErrorResponses.Items[?ErrorCode==\`403\`].ResponseCode | [0]" \
  --output text 2>/dev/null || echo "")
assert_eq "403 custom error returns 200" "200" "$CF_ERR_403"

CF_ERR_404=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.DistributionConfig.CustomErrorResponses.Items[?ErrorCode==\`404\`].ResponseCode | [0]" \
  --output text 2>/dev/null || echo "")
assert_eq "404 custom error returns 200" "200" "$CF_ERR_404"

CF_OAC_ATTACHED=$(aws cloudfront get-distribution \
  --id "$CF_DISTRIBUTION_ID" \
  --query "Distribution.DistributionConfig.Origins.Items[0].OriginAccessControlId" \
  --output text 2>/dev/null || echo "")
assert_eq "OAC is attached to distribution origin" "$CF_OAC_ID" "$CF_OAC_ATTACHED"

# ═══════════════════════════════════════════════════════════════════════════════
section "S3 — bucket policy (OAC-only)"

CF_ARN="arn:aws:cloudfront::420030147545:distribution/${CF_DISTRIBUTION_ID}"

POLICY_JSON=$(aws s3api get-bucket-policy \
  --bucket "$BUCKET" \
  --query "Policy" --output text 2>/dev/null || echo "")

POLICY_PRINCIPAL=$(echo "$POLICY_JSON" | grep -o '"Service":"[^"]*"' | cut -d'"' -f4)
assert_eq "S3 policy principal is cloudfront.amazonaws.com" "cloudfront.amazonaws.com" "$POLICY_PRINCIPAL"

POLICY_CONDITION=$(echo "$POLICY_JSON" | grep -o '"AWS:SourceArn":"[^"]*"' | cut -d'"' -f4)
assert_eq "S3 policy condition matches CloudFront ARN" "$CF_ARN" "$POLICY_CONDITION"

# ═══════════════════════════════════════════════════════════════════════════════
section "Route 53 — DNS record"

DNS_NAME=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Name=='${DOMAIN}.' && Type=='A'].AliasTarget.DNSName | [0]" \
  --output text 2>/dev/null || echo "")

# Route 53 appends a trailing dot to the CloudFront domain; strip it for comparison
DNS_NAME_CLEAN="${DNS_NAME%.}"

assert_eq "A ALIAS record points to CF domain" "$CF_DOMAIN" "$DNS_NAME_CLEAN"

# ═══════════════════════════════════════════════════════════════════════════════
section "HTTPS endpoint"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${DOMAIN}/" 2>/dev/null || echo "")
# 200 = content served, 403/404 = CF reached but bucket empty (both acceptable before Phase 4)
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "403" || "$HTTP_CODE" == "404" ]]; then
  pass "https://${DOMAIN}/ returns HTTP response (got $HTTP_CODE)"
else
  fail "https://${DOMAIN}/ returned unexpected code '${HTTP_CODE}' (expected 200, 403, or 404)"
fi
