#!/usr/bin/env bash
# tests/lib.sh — shared test helpers
# Source this file from phase test scripts; do not run directly.

PASS=0
FAIL=0
SKIP=0
FAILURES=""
CURRENT_SECTION=""

# ── Formatting ────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

section() {
  CURRENT_SECTION="$1"
  echo ""
  echo -e "${CYAN}${BOLD}── $1 ──${RESET}"
}

pass() {
  echo -e "  ${GREEN}[PASS]${RESET} $1"
  ((PASS++))
}

fail() {
  local msg="$1"
  echo -e "  ${RED}[FAIL]${RESET} $msg"
  ((FAIL++))
  FAILURES="${FAILURES}\n  [FAIL] ${CURRENT_SECTION}: ${msg}"
}

skip() {
  echo -e "  ${YELLOW}[SKIP]${RESET} $1"
  ((SKIP++))
}

# ── Assertions ────────────────────────────────────────────────────────────────

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label — expected '${expected}', got '${actual}'"
  fi
}

assert_not_empty() {
  local label="$1" value="$2"
  if [[ -n "$value" && "$value" != "None" && "$value" != "null" ]]; then
    pass "$label"
  else
    fail "$label — value was empty or null"
  fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -q "$needle"; then
    pass "$label"
  else
    fail "$label — expected to contain '${needle}'"
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if ! echo "$haystack" | grep -q "$needle"; then
    pass "$label"
  else
    fail "$label — expected NOT to contain '${needle}'"
  fi
}

# ── Summary ───────────────────────────────────────────────────────────────────

print_summary() {
  local phase_label="${1:-}"
  local total=$((PASS + FAIL + SKIP))
  echo ""
  echo -e "${BOLD}════════════════════════════════════════${RESET}"
  if [[ -n "$phase_label" ]]; then
    echo -e "${BOLD} Results: $phase_label${RESET}"
  else
    echo -e "${BOLD} Test Results${RESET}"
  fi
  echo -e "${BOLD}════════════════════════════════════════${RESET}"
  echo -e "  Total:  $total"
  echo -e "  ${GREEN}Passed: $PASS${RESET}"
  if [[ $FAIL -gt 0 ]]; then
    echo -e "  ${RED}Failed: $FAIL${RESET}"
  else
    echo -e "  Failed: $FAIL"
  fi
  if [[ $SKIP -gt 0 ]]; then
    echo -e "  ${YELLOW}Skipped: $SKIP${RESET}"
  fi
  if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}Failures:${RESET}"
    echo -e "$FAILURES"
    echo ""
    return 1
  fi
  echo ""
  echo -e "${GREEN}${BOLD}All tests passed.${RESET}"
  echo ""
  return 0
}
