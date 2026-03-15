#!/usr/bin/env bash
# tests/phase4.sh — Phase 4 frontend deployment tests
#
# Verifies: S3 bucket has content, CloudFront serves index.html at root (HTTP 200),
#           HTTP redirects to HTTPS, and /login path returns HTTP 200 (SPA routing).
#
# SCOPE LIMITATION: Auth flow testing (sign-in, MFA, create account, etc.) requires
# live user accounts and is intentionally excluded from automated tests. Validate auth
# flows manually against https://dcatch.hilldogs.net after deploy.
#
# Sourced by tests/run-all.sh; can also be run standalone:
#   bash tests/phase4.sh

SCRIPT_DIR_P4="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_P4="$(cd "$SCRIPT_DIR_P4/.." && pwd)"

# Bootstrap when run standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$SCRIPT_DIR_P4/lib.sh"
  echo ""
  echo -e "${BOLD}━━━ Phase 4 Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
fi

source "$REPO_ROOT_P4/infra/outputs.env"
DOMAIN="dcatch.hilldogs.net"

# ═══════════════════════════════════════════════════════════════════════════════
section "S3 — bucket has content"

obj_count=$(aws s3 ls "s3://$S3_BUCKET" --recursive 2>/dev/null | wc -l | tr -d ' ')
if [[ "$obj_count" -gt 0 ]]; then
  pass "S3 bucket $S3_BUCKET has at least one object ($obj_count objects)"
else
  fail "S3 bucket $S3_BUCKET is empty — run deploy.ps1 first"
fi

index_listing=$(aws s3 ls "s3://$S3_BUCKET/index.html" 2>/dev/null)
assert_not_empty "index.html exists in S3 bucket" "$index_listing"

# ═══════════════════════════════════════════════════════════════════════════════
section "CloudFront — HTTPS root returns 200"

http_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/" \
  --max-time 30 --retry 2)
assert_eq "https://$DOMAIN/ returns HTTP 200" "$http_status" "200"

# ═══════════════════════════════════════════════════════════════════════════════
section "CloudFront — HTTP redirects to HTTPS"

redirect_status=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/" \
  --max-time 30 --retry 2 --max-redirs 0)
assert_eq "http://$DOMAIN/ redirects (301 or 302)" "$redirect_status" "301"

redirect_location=$(curl -s -o /dev/null -w "%{redirect_url}" "http://$DOMAIN/" \
  --max-time 30 --retry 2 --max-redirs 0)
assert_contains "HTTP redirect points to HTTPS" "$redirect_location" "https://"

# ═══════════════════════════════════════════════════════════════════════════════
section "CloudFront — SPA routing (/login returns 200)"

login_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/login" \
  --max-time 30 --retry 2)
assert_eq "https://$DOMAIN/login returns HTTP 200 (SPA routing)" "$login_status" "200"

settings_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/settings" \
  --max-time 30 --retry 2)
assert_eq "https://$DOMAIN/settings returns HTTP 200 (SPA routing)" "$settings_status" "200"

# ═══════════════════════════════════════════════════════════════════════════════
section "CloudFront — content-type check"

content_type=$(curl -s -I "https://$DOMAIN/" --max-time 30 | grep -i 'content-type' | head -1)
assert_contains "Root response has text/html content-type" "$content_type" "text/html"

# Standalone summary
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  print_summary "Phase 4"
fi
