#!/usr/bin/env bash
# provision-vpc.sh — Phase 1
# Creates VPC, private subnets, and security groups for dcatch.
# Run from repo root: bash infra/provision-vpc.sh
# Appends resource IDs to infra/outputs.env

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="$SCRIPT_DIR/outputs.env"
touch "$OUTPUTS"
REGION="us-east-2"

# ─── 1. VPC ──────────────────────────────────────────────────────────────────

echo "Creating dcatch-vpc..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.1.0.0/16 \
  --region "$REGION" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=dcatch-vpc},{Key=Project,Value=DCATCH}]' \
  --query Vpc.VpcId --output text)

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
echo "  VPC: $VPC_ID"

# ─── 2. Private subnets ───────────────────────────────────────────────────────
# No public subnets or internet gateway — Lambda and future RDS stay private.
# No NAT gateway — Lambda only needs to reach resources within the VPC.
# When RDS arrives (Phase 2), Lambda talks to it over the private network.
# SES admin alert connectivity deferred to DCATCH-1.

echo "Creating private subnets..."
SUBNET_2A_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.1.1.0/24 \
  --availability-zone "${REGION}a" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dcatch-private-2a},{Key=Project,Value=DCATCH}]' \
  --query Subnet.SubnetId --output text)

SUBNET_2B_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.1.2.0/24 \
  --availability-zone "${REGION}b" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dcatch-private-2b},{Key=Project,Value=DCATCH}]' \
  --query Subnet.SubnetId --output text)

echo "  Subnet 2a: $SUBNET_2A_ID"
echo "  Subnet 2b: $SUBNET_2B_ID"

# ─── 3. Security groups ──────────────────────────────────────────────────────

echo "Creating security groups..."

# Lambda SG — no inbound; outbound open (tightened to RDS port when DB is added)
SG_LAMBDA_ID=$(aws ec2 create-security-group \
  --group-name dcatch-sg-lambda \
  --description "DCATCH Lambda functions" \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=dcatch-sg-lambda},{Key=Project,Value=DCATCH}]' \
  --query GroupId --output text)

# DB SG — inbound TCP 5432 from Lambda SG only (ready for RDS in Phase 2)
SG_DB_ID=$(aws ec2 create-security-group \
  --group-name dcatch-sg-db \
  --description "DCATCH RDS database" \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=dcatch-sg-db},{Key=Project,Value=DCATCH}]' \
  --query GroupId --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_DB_ID" \
  --protocol tcp \
  --port 5432 \
  --source-group "$SG_LAMBDA_ID"

echo "  SG Lambda: $SG_LAMBDA_ID"
echo "  SG DB:     $SG_DB_ID"

# ─── Write outputs ───────────────────────────────────────────────────────────

for key in VPC_ID SUBNET_2A_ID SUBNET_2B_ID SG_LAMBDA_ID SG_DB_ID; do
  grep -v "^${key}=" "$OUTPUTS" > "$OUTPUTS.tmp" && mv "$OUTPUTS.tmp" "$OUTPUTS"
done

cat >> "$OUTPUTS" <<EOF
VPC_ID=$VPC_ID
SUBNET_2A_ID=$SUBNET_2A_ID
SUBNET_2B_ID=$SUBNET_2B_ID
SG_LAMBDA_ID=$SG_LAMBDA_ID
SG_DB_ID=$SG_DB_ID
EOF

echo "VPC provisioning complete. Values written to outputs.env."
