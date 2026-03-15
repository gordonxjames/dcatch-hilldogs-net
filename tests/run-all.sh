#!/usr/bin/env bash
# tests/run-all.sh — runs all phase test files in order
# Usage: bash tests/run-all.sh [--phase N]
#   --phase N  run only up to and including phase N (default: all)
#
# Each phase test script sources tests/lib.sh and uses shared PASS/FAIL counters.
# This runner accumulates results across all phases.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse optional --phase argument
MAX_PHASE=99
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase) MAX_PHASE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# Verify outputs.env exists
OUTPUTS="$REPO_ROOT/infra/outputs.env"
if [[ ! -f "$OUTPUTS" ]]; then
  echo "ERROR: infra/outputs.env not found. Cannot run tests without provisioned resource IDs."
  exit 1
fi

# Source shared lib (initializes counters)
source "$SCRIPT_DIR/lib.sh"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   DCATCH Infrastructure Test Suite       ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo "  Run at: $(date)"
echo "  Repo:   $REPO_ROOT"

# Find and run phase test files in numeric order
for test_file in $(ls "$SCRIPT_DIR"/phase*.sh 2>/dev/null | sort -V); do
  phase_num=$(basename "$test_file" | grep -oP '\d+')
  if [[ "$phase_num" -le "$MAX_PHASE" ]]; then
    echo ""
    echo -e "${BOLD}━━━ Phase $phase_num Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    # Source the phase test (runs tests, accumulates into shared counters)
    source "$test_file"
  fi
done

# Final summary across all phases
print_summary "All Phases (up to Phase $MAX_PHASE)"
