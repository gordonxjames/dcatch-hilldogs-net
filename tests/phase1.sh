#!/usr/bin/env bash
# tests/phase1.sh — Phase 1 infrastructure tests
# Verifies: IAM roles, VPC, subnets, security groups, Cognito, S3
# No external dependencies — uses AWS CLI --query (JMESPath) only.
#
# Sourced by tests/run-all.sh; can also be run standalone:
#   bash tests/phase1.sh

SCRIPT_DIR_P1="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_P1="$(cd "$SCRIPT_DIR_P1/.." && pwd)"

# Bootstrap when run standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$SCRIPT_DIR_P1/lib.sh"
  echo ""
  echo -e "${BOLD}━━━ Phase 1 Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
fi

source "$REPO_ROOT_P1/infra/outputs.env"
REGION="us-east-2"

# ═══════════════════════════════════════════════════════════════════════════════
section "IAM — Lambda execution role"

ROLE_ARN=$(aws iam get-role --role-name dcatch-lambda-role \
  --query 'Role.Arn' --output text 2>/dev/null || echo "")
assert_not_empty "dcatch-lambda-role exists" "$ROLE_ARN"
assert_eq "Lambda role ARN matches outputs.env" "$LAMBDA_ROLE_ARN" "$ROLE_ARN"

VPC_POLICY=$(aws iam list-attached-role-policies --role-name dcatch-lambda-role \
  --query 'AttachedPolicies[?PolicyName==`AWSLambdaVPCAccessExecutionRole`].PolicyName' \
  --output text 2>/dev/null || echo "")
assert_eq "AWSLambdaVPCAccessExecutionRole attached" "AWSLambdaVPCAccessExecutionRole" "$VPC_POLICY"

LAMBDA_ROLE_TAG=$(aws iam list-role-tags --role-name dcatch-lambda-role \
  --query 'Tags[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "Lambda role tagged Project=DCATCH" "DCATCH" "$LAMBDA_ROLE_TAG"

# ═══════════════════════════════════════════════════════════════════════════════
section "IAM — Cognito SMS role"

SMS_ROLE_ARN=$(aws iam get-role --role-name dcatch-cognito-sms-role \
  --query 'Role.Arn' --output text 2>/dev/null || echo "")
assert_not_empty "dcatch-cognito-sms-role exists" "$SMS_ROLE_ARN"
assert_eq "Cognito SMS role ARN matches outputs.env" "$COGNITO_SMS_ROLE_ARN" "$SMS_ROLE_ARN"

TRUST_DOC=$(aws iam get-role --role-name dcatch-cognito-sms-role \
  --query 'Role.AssumeRolePolicyDocument' --output text 2>/dev/null || echo "")
assert_contains "Cognito SMS role trusted by cognito-idp" "$TRUST_DOC" "cognito-idp"

SMS_POLICY_EXISTS=$(aws iam get-role-policy \
  --role-name dcatch-cognito-sms-role \
  --policy-name dcatch-cognito-sms-policy \
  --query 'PolicyName' --output text 2>/dev/null || echo "")
assert_eq "Cognito SMS inline policy exists" "dcatch-cognito-sms-policy" "$SMS_POLICY_EXISTS"

SMS_POLICY_DOC=$(aws iam get-role-policy \
  --role-name dcatch-cognito-sms-role \
  --policy-name dcatch-cognito-sms-policy \
  --query 'PolicyDocument' --output text 2>/dev/null || echo "")
assert_contains "SMS policy grants sns:Publish" "$SMS_POLICY_DOC" "sns:Publish"

COGNITO_ROLE_TAG=$(aws iam list-role-tags --role-name dcatch-cognito-sms-role \
  --query 'Tags[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "Cognito SMS role tagged Project=DCATCH" "DCATCH" "$COGNITO_ROLE_TAG"

# ═══════════════════════════════════════════════════════════════════════════════
section "VPC"

VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" \
  --query 'Vpcs[0].CidrBlock' --output text 2>/dev/null || echo "")
assert_eq "dcatch-vpc CIDR is 10.1.0.0/16" "10.1.0.0/16" "$VPC_CIDR"

VPC_STATE=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" \
  --query 'Vpcs[0].State' --output text 2>/dev/null || echo "")
assert_eq "dcatch-vpc state is available" "available" "$VPC_STATE"

DNS_HOSTNAMES=$(aws ec2 describe-vpc-attribute --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames --region "$REGION" \
  --query 'EnableDnsHostnames.Value' --output text 2>/dev/null || echo "")
assert_eq "VPC DNS hostnames enabled" "True" "$DNS_HOSTNAMES"

DNS_SUPPORT=$(aws ec2 describe-vpc-attribute --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport --region "$REGION" \
  --query 'EnableDnsSupport.Value' --output text 2>/dev/null || echo "")
assert_eq "VPC DNS support enabled" "True" "$DNS_SUPPORT"

VPC_PROJECT_TAG=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" \
  --query 'Vpcs[0].Tags[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "VPC tagged Project=DCATCH" "DCATCH" "$VPC_PROJECT_TAG"

VPC_NAME_TAG=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" \
  --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text 2>/dev/null || echo "")
assert_eq "VPC tagged Name=dcatch-vpc" "dcatch-vpc" "$VPC_NAME_TAG"

# ═══════════════════════════════════════════════════════════════════════════════
section "Subnets"

# Subnet 2a
S2A_CIDR=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2A_ID" --region "$REGION" \
  --query 'Subnets[0].CidrBlock' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2a CIDR is 10.1.1.0/24" "10.1.1.0/24" "$S2A_CIDR"

S2A_AZ=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2A_ID" --region "$REGION" \
  --query 'Subnets[0].AvailabilityZone' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2a is in us-east-2a" "us-east-2a" "$S2A_AZ"

S2A_VPC=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2A_ID" --region "$REGION" \
  --query 'Subnets[0].VpcId' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2a in correct VPC" "$VPC_ID" "$S2A_VPC"

S2A_PUBLIC=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2A_ID" --region "$REGION" \
  --query 'Subnets[0].MapPublicIpOnLaunch' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2a is private (no auto-assign public IP)" "False" "$S2A_PUBLIC"

S2A_TAG=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2A_ID" --region "$REGION" \
  --query 'Subnets[0].Tags[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2a tagged Project=DCATCH" "DCATCH" "$S2A_TAG"

# Subnet 2b
S2B_CIDR=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2B_ID" --region "$REGION" \
  --query 'Subnets[0].CidrBlock' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2b CIDR is 10.1.2.0/24" "10.1.2.0/24" "$S2B_CIDR"

S2B_AZ=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2B_ID" --region "$REGION" \
  --query 'Subnets[0].AvailabilityZone' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2b is in us-east-2b" "us-east-2b" "$S2B_AZ"

S2B_VPC=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2B_ID" --region "$REGION" \
  --query 'Subnets[0].VpcId' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2b in correct VPC" "$VPC_ID" "$S2B_VPC"

S2B_PUBLIC=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2B_ID" --region "$REGION" \
  --query 'Subnets[0].MapPublicIpOnLaunch' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2b is private (no auto-assign public IP)" "False" "$S2B_PUBLIC"

S2B_TAG=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_2B_ID" --region "$REGION" \
  --query 'Subnets[0].Tags[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "Subnet 2b tagged Project=DCATCH" "DCATCH" "$S2B_TAG"

# ═══════════════════════════════════════════════════════════════════════════════
section "Security Groups"

# Lambda SG
SGL_VPC=$(aws ec2 describe-security-groups --group-ids "$SG_LAMBDA_ID" --region "$REGION" \
  --query 'SecurityGroups[0].VpcId' --output text 2>/dev/null || echo "")
assert_eq "sg-lambda in correct VPC" "$VPC_ID" "$SGL_VPC"

SGL_NAME=$(aws ec2 describe-security-groups --group-ids "$SG_LAMBDA_ID" --region "$REGION" \
  --query 'SecurityGroups[0].GroupName' --output text 2>/dev/null || echo "")
assert_eq "sg-lambda name is dcatch-sg-lambda" "dcatch-sg-lambda" "$SGL_NAME"

SGL_INBOUND=$(aws ec2 describe-security-groups --group-ids "$SG_LAMBDA_ID" --region "$REGION" \
  --query 'length(SecurityGroups[0].IpPermissions)' --output text 2>/dev/null || echo "")
assert_eq "sg-lambda has no inbound rules" "0" "$SGL_INBOUND"

SGL_TAG=$(aws ec2 describe-security-groups --group-ids "$SG_LAMBDA_ID" --region "$REGION" \
  --query 'SecurityGroups[0].Tags[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "sg-lambda tagged Project=DCATCH" "DCATCH" "$SGL_TAG"

# DB SG
SDB_VPC=$(aws ec2 describe-security-groups --group-ids "$SG_DB_ID" --region "$REGION" \
  --query 'SecurityGroups[0].VpcId' --output text 2>/dev/null || echo "")
assert_eq "sg-db in correct VPC" "$VPC_ID" "$SDB_VPC"

SDB_NAME=$(aws ec2 describe-security-groups --group-ids "$SG_DB_ID" --region "$REGION" \
  --query 'SecurityGroups[0].GroupName' --output text 2>/dev/null || echo "")
assert_eq "sg-db name is dcatch-sg-db" "dcatch-sg-db" "$SDB_NAME"

SDB_INBOUND=$(aws ec2 describe-security-groups --group-ids "$SG_DB_ID" --region "$REGION" \
  --query 'length(SecurityGroups[0].IpPermissions)' --output text 2>/dev/null || echo "")
assert_eq "sg-db has exactly one inbound rule" "1" "$SDB_INBOUND"

SDB_PROTO=$(aws ec2 describe-security-groups --group-ids "$SG_DB_ID" --region "$REGION" \
  --query 'SecurityGroups[0].IpPermissions[0].IpProtocol' --output text 2>/dev/null || echo "")
assert_eq "sg-db inbound rule is TCP" "tcp" "$SDB_PROTO"

SDB_FROM=$(aws ec2 describe-security-groups --group-ids "$SG_DB_ID" --region "$REGION" \
  --query 'SecurityGroups[0].IpPermissions[0].FromPort' --output text 2>/dev/null || echo "")
assert_eq "sg-db inbound from port 5432" "5432" "$SDB_FROM"

SDB_TO=$(aws ec2 describe-security-groups --group-ids "$SG_DB_ID" --region "$REGION" \
  --query 'SecurityGroups[0].IpPermissions[0].ToPort' --output text 2>/dev/null || echo "")
assert_eq "sg-db inbound to port 5432" "5432" "$SDB_TO"

SDB_SOURCE=$(aws ec2 describe-security-groups --group-ids "$SG_DB_ID" --region "$REGION" \
  --query 'SecurityGroups[0].IpPermissions[0].UserIdGroupPairs[0].GroupId' --output text 2>/dev/null || echo "")
assert_eq "sg-db inbound source is sg-lambda" "$SG_LAMBDA_ID" "$SDB_SOURCE"

SDB_TAG=$(aws ec2 describe-security-groups --group-ids "$SG_DB_ID" --region "$REGION" \
  --query 'SecurityGroups[0].Tags[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "sg-db tagged Project=DCATCH" "DCATCH" "$SDB_TAG"

# ═══════════════════════════════════════════════════════════════════════════════
section "Cognito — User Pool"

POOL_NAME=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.Name' --output text 2>/dev/null || echo "")
assert_eq "User pool name is dcatch-user-pool" "dcatch-user-pool" "$POOL_NAME"

POOL_MFA=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.MfaConfiguration' --output text 2>/dev/null || echo "")
assert_eq "User pool MFA is OPTIONAL" "OPTIONAL" "$POOL_MFA"

POOL_ALIAS=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.AliasAttributes' --output text 2>/dev/null || echo "")
assert_contains "User pool has email alias attribute" "$POOL_ALIAS" "email"

AUTO_VERIFIED=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.AutoVerifiedAttributes' --output text 2>/dev/null || echo "")
assert_contains "Email is auto-verified" "$AUTO_VERIFIED" "email"
# Phone is NOT auto-verified at signup; users verify phone in Account Settings to enable SMS MFA

EMAIL_REQUIRED=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.SchemaAttributes[?Name==`email`].Required' --output text 2>/dev/null || echo "")
assert_eq "Email attribute is required" "True" "$EMAIL_REQUIRED"

EMAIL_MUTABLE=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.SchemaAttributes[?Name==`email`].Mutable' --output text 2>/dev/null || echo "")
assert_eq "Email attribute is mutable" "True" "$EMAIL_MUTABLE"

PHONE_REQUIRED=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.SchemaAttributes[?Name==`phone_number`].Required' --output text 2>/dev/null || echo "")
assert_eq "Phone attribute is not required (optional)" "False" "$PHONE_REQUIRED"

PHONE_MUTABLE=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.SchemaAttributes[?Name==`phone_number`].Mutable' --output text 2>/dev/null || echo "")
assert_eq "Phone attribute is mutable" "True" "$PHONE_MUTABLE"

PW_MIN=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.Policies.PasswordPolicy.MinimumLength' --output text 2>/dev/null || echo "")
assert_eq "Password min length is 8" "8" "$PW_MIN"

PW_UPPER=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.Policies.PasswordPolicy.RequireUppercase' --output text 2>/dev/null || echo "")
assert_eq "Password requires uppercase" "True" "$PW_UPPER"

PW_LOWER=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.Policies.PasswordPolicy.RequireLowercase' --output text 2>/dev/null || echo "")
assert_eq "Password requires lowercase" "True" "$PW_LOWER"

PW_NUM=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.Policies.PasswordPolicy.RequireNumbers' --output text 2>/dev/null || echo "")
assert_eq "Password requires numbers" "True" "$PW_NUM"

PW_SYM=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$COGNITO_USER_POOL_ID" --region "$REGION" \
  --query 'UserPool.Policies.PasswordPolicy.RequireSymbols' --output text 2>/dev/null || echo "")
assert_eq "Password does not require symbols" "False" "$PW_SYM"

# ═══════════════════════════════════════════════════════════════════════════════
section "Cognito — App Client"

CLIENT_NAME=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id "$COGNITO_USER_POOL_ID" --client-id "$COGNITO_CLIENT_ID" --region "$REGION" \
  --query 'UserPoolClient.ClientName' --output text 2>/dev/null || echo "")
assert_eq "Client name is dcatch-web-client" "dcatch-web-client" "$CLIENT_NAME"

CLIENT_SECRET=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id "$COGNITO_USER_POOL_ID" --client-id "$COGNITO_CLIENT_ID" --region "$REGION" \
  --query 'UserPoolClient.ClientSecret' --output text 2>/dev/null || echo "NONE")
assert_eq "Client has no secret" "None" "$CLIENT_SECRET"

CLIENT_FLOWS=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id "$COGNITO_USER_POOL_ID" --client-id "$COGNITO_CLIENT_ID" --region "$REGION" \
  --query 'UserPoolClient.ExplicitAuthFlows' --output text 2>/dev/null || echo "")
assert_contains "Client has ALLOW_USER_SRP_AUTH" "$CLIENT_FLOWS" "ALLOW_USER_SRP_AUTH"
assert_contains "Client has ALLOW_REFRESH_TOKEN_AUTH" "$CLIENT_FLOWS" "ALLOW_REFRESH_TOKEN_AUTH"
assert_contains "Client has ALLOW_USER_PASSWORD_AUTH" "$CLIENT_FLOWS" "ALLOW_USER_PASSWORD_AUTH"

CLIENT_PUSE=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id "$COGNITO_USER_POOL_ID" --client-id "$COGNITO_CLIENT_ID" --region "$REGION" \
  --query 'UserPoolClient.PreventUserExistenceErrors' --output text 2>/dev/null || echo "")
assert_eq "Client prevent-user-existence-errors is ENABLED" "ENABLED" "$CLIENT_PUSE"

# ═══════════════════════════════════════════════════════════════════════════════
section "S3 Bucket"

S3_NAME=$(aws s3api list-buckets \
  --query "Buckets[?Name=='${S3_BUCKET}'].Name" --output text 2>/dev/null || echo "")
assert_eq "dcatch-hilldogs-frontend bucket exists" "$S3_BUCKET" "$S3_NAME"

BLK_ACLS=$(aws s3api get-public-access-block --bucket "$S3_BUCKET" \
  --query 'PublicAccessBlockConfiguration.BlockPublicAcls' --output text 2>/dev/null || echo "")
assert_eq "BlockPublicAcls is true" "True" "$BLK_ACLS"

IGN_ACLS=$(aws s3api get-public-access-block --bucket "$S3_BUCKET" \
  --query 'PublicAccessBlockConfiguration.IgnorePublicAcls' --output text 2>/dev/null || echo "")
assert_eq "IgnorePublicAcls is true" "True" "$IGN_ACLS"

BLK_POL=$(aws s3api get-public-access-block --bucket "$S3_BUCKET" \
  --query 'PublicAccessBlockConfiguration.BlockPublicPolicy' --output text 2>/dev/null || echo "")
assert_eq "BlockPublicPolicy is true" "True" "$BLK_POL"

RST_PUB=$(aws s3api get-public-access-block --bucket "$S3_BUCKET" \
  --query 'PublicAccessBlockConfiguration.RestrictPublicBuckets' --output text 2>/dev/null || echo "")
assert_eq "RestrictPublicBuckets is true" "True" "$RST_PUB"

S3_TAG=$(aws s3api get-bucket-tagging --bucket "$S3_BUCKET" \
  --query 'TagSet[?Key==`Project`].Value' --output text 2>/dev/null || echo "")
assert_eq "S3 bucket tagged Project=DCATCH" "DCATCH" "$S3_TAG"

S3_NAME_TAG=$(aws s3api get-bucket-tagging --bucket "$S3_BUCKET" \
  --query 'TagSet[?Key==`Name`].Value' --output text 2>/dev/null || echo "")
assert_eq "S3 bucket tagged Name=dcatch-hilldogs-frontend" "dcatch-hilldogs-frontend" "$S3_NAME_TAG"

# ── Standalone summary ────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  print_summary "Phase 1"
fi
