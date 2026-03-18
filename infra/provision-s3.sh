#!/usr/bin/env bash
# provision-s3.sh — Phase 1
# Creates the S3 bucket for the frontend.
# Run from repo root: bash infra/provision-s3.sh
# Appends resource IDs to infra/outputs.env

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
touch "$OUTPUTS"

REGION="us-east-2"
BUCKET="dcatch-s3-frontend"

# ─── Create bucket ───────────────────────────────────────────────────────────

echo "Creating S3 bucket $BUCKET..."
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-tagging \
  --bucket "$BUCKET" \
  --tagging 'TagSet=[{Key=Project,Value=DCATCH},{Key=Name,Value=dcatch-s3-frontend}]'

echo "  Bucket: $BUCKET"

# Note: bucket policy allowing CloudFront OAC access is added in Phase 3
# when the CloudFront distribution and OAC are created.

# ─── Write outputs ───────────────────────────────────────────────────────────

grep -v "^S3_BUCKET=" "$OUTPUTS" > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"
echo "S3_BUCKET=$BUCKET" >> "$OUTPUTS"

echo "S3 provisioning complete. Values written to outputs.env."
