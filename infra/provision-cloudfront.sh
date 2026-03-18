#!/usr/bin/env bash
# provision-cloudfront.sh — Phase 3 (DCATCH-15, DCATCH-16)
# Creates CloudFront OAC + distribution, updates S3 bucket policy,
# and creates Route 53 A ALIAS record dcatch.hilldogs.net → CloudFront.
# Run from repo root: bash infra/provision-cloudfront.sh
# Writes CF_OAC_ID, CF_DISTRIBUTION_ID, CF_DOMAIN to infra/outputs.env

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
touch "$OUTPUTS"

# ─── Config ──────────────────────────────────────────────────────────────────
ACCOUNT_ID="420030147545"
BUCKET="dcatch-s3-frontend"
DOMAIN="dcatch.hilldogs.net"
CERT_ARN="arn:aws:acm:us-east-1:420030147545:certificate/36daeb2b-20e3-4910-bbe1-acac865f5adb"
HOSTED_ZONE_ID="Z09301025V2NYG3DJ3TL"
# CloudFront's fixed Route 53 hosted zone ID (constant for all distributions)
CF_HOSTED_ZONE="Z2FDTNDATAQYW2"

save() { grep -v "^${1}=" "$OUTPUTS" > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"; echo "${1}=${2}" >> "$OUTPUTS"; }

# ─── 1. Origin Access Control ────────────────────────────────────────────────
echo "1/4  Creating CloudFront OAC..."

OAC_ID=$(aws cloudfront create-origin-access-control \
  --origin-access-control-config \
    "Name=dcatch-s3-oac,Description=DCATCH S3 OAC,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
  --query "OriginAccessControl.Id" --output text)

echo "     OAC: $OAC_ID"
save CF_OAC_ID "$OAC_ID"

# ─── 2. CloudFront Distribution ──────────────────────────────────────────────
echo "2/4  Creating CloudFront distribution (this takes ~15 min)..."

CALLER_REF="dcatch-cf-$(date +%s)"

CF_CONFIG=$(cat <<CFEOF
{
  "CallerReference": "${CALLER_REF}",
  "Comment": "DCATCH Delta Catcher frontend",
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [{
      "Id": "dcatch-s3-origin",
      "DomainName": "${BUCKET}.s3.us-east-2.amazonaws.com",
      "S3OriginConfig": { "OriginAccessIdentity": "" },
      "OriginAccessControlId": "${OAC_ID}"
    }]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "dcatch-s3-origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "AllowedMethods": { "Quantity": 2, "Items": ["GET","HEAD"] },
    "Compress": true
  },
  "CustomErrorResponses": {
    "Quantity": 2,
    "Items": [
      { "ErrorCode": 403, "ResponsePagePath": "/index.html", "ResponseCode": "200", "ErrorCachingMinTTL": 0 },
      { "ErrorCode": 404, "ResponsePagePath": "/index.html", "ResponseCode": "200", "ErrorCachingMinTTL": 0 }
    ]
  },
  "Aliases": { "Quantity": 1, "Items": ["${DOMAIN}"] },
  "ViewerCertificate": {
    "ACMCertificateArn": "${CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http2",
  "Enabled": true
}
CFEOF
)

CF_ID=$(aws cloudfront create-distribution \
  --distribution-config "$CF_CONFIG" \
  --query "Distribution.Id" --output text)

CF_DOMAIN=$(aws cloudfront get-distribution \
  --id "$CF_ID" \
  --query "Distribution.DomainName" --output text)

echo "     Distribution ID: $CF_ID"
echo "     Domain:          $CF_DOMAIN"
save CF_DISTRIBUTION_ID "$CF_ID"
save CF_DOMAIN "$CF_DOMAIN"

# ─── 3. Tag distribution + update S3 bucket policy ───────────────────────────
echo "3/4  Tagging distribution and updating S3 bucket policy..."

CF_ARN="arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${CF_ID}"

aws cloudfront tag-resource \
  --resource "$CF_ARN" \
  --tags "Items=[{Key=Project,Value=DCATCH},{Key=Name,Value=dcatch-cf}]"

aws s3api put-bucket-policy \
  --bucket "$BUCKET" \
  --policy "{
    \"Version\":\"2012-10-17\",
    \"Statement\":[{
      \"Sid\":\"AllowCloudFrontOAC\",
      \"Effect\":\"Allow\",
      \"Principal\":{\"Service\":\"cloudfront.amazonaws.com\"},
      \"Action\":\"s3:GetObject\",
      \"Resource\":\"arn:aws:s3:::${BUCKET}/*\",
      \"Condition\":{\"StringEquals\":{\"AWS:SourceArn\":\"${CF_ARN}\"}}
    }]
  }"

echo "     Waiting for CloudFront to deploy (~15 min)..."
aws cloudfront wait distribution-deployed --id "$CF_ID"
echo "     CloudFront deployed."

# ─── 4. Route 53 — A ALIAS record ────────────────────────────────────────────
echo "4/4  Creating Route 53 A ALIAS record ${DOMAIN} → CloudFront..."

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\":[{
      \"Action\":\"UPSERT\",
      \"ResourceRecordSet\":{
        \"Name\":\"${DOMAIN}\",
        \"Type\":\"A\",
        \"AliasTarget\":{
          \"HostedZoneId\":\"${CF_HOSTED_ZONE}\",
          \"DNSName\":\"${CF_DOMAIN}\",
          \"EvaluateTargetHealth\":false
        }
      }
    }]
  }" > /dev/null

echo "     DNS record created: ${DOMAIN} → ${CF_DOMAIN}"

echo ""
echo "Phase 3 provisioning complete."
echo "  CloudFront: https://${CF_DOMAIN}"
echo "  Custom domain: https://${DOMAIN}  (DNS propagates in < 5 min)"
echo ""
echo "Test with: curl -I https://${DOMAIN}"
