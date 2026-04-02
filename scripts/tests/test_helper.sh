#!/usr/bin/env bash
# scripts/tests/test_helper.sh
#
# Shared setup for all test files.
# Sources lib scripts and initializes a non-interactive environment.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TESTS_DIR/../.." && pwd)"
LIB_DIR="$REPO_DIR/scripts/lib"

# Track test results
_TESTS_RUN=0
_TESTS_PASSED=0
_TESTS_FAILED=0

# --- Minimal assertion functions ---

assert_eq() {
  # Usage: assert_eq "description" "expected" "actual"
  local desc="$1" expected="$2" actual="$3"
  _TESTS_RUN=$((_TESTS_RUN + 1))

  if [[ "$expected" == "$actual" ]]; then
    _TESTS_PASSED=$((_TESTS_PASSED + 1))
    printf '  [PASS] %s\n' "$desc"
  else
    _TESTS_FAILED=$((_TESTS_FAILED + 1))
    printf '  [FAIL] %s\n' "$desc"
    printf '         expected: "%s"\n' "$expected"
    printf '         actual:   "%s"\n' "$actual"
  fi
}

assert_ne() {
  # Usage: assert_ne "description" "not_expected" "actual"
  local desc="$1" not_expected="$2" actual="$3"
  _TESTS_RUN=$((_TESTS_RUN + 1))

  if [[ "$not_expected" != "$actual" ]]; then
    _TESTS_PASSED=$((_TESTS_PASSED + 1))
    printf '  [PASS] %s\n' "$desc"
  else
    _TESTS_FAILED=$((_TESTS_FAILED + 1))
    printf '  [FAIL] %s\n' "$desc"
    printf '         should NOT equal: "%s"\n' "$not_expected"
  fi
}

assert_success() {
  # Usage: assert_success "description" <command...>
  # Runs a command and asserts exit code 0
  local desc="$1"; shift
  _TESTS_RUN=$((_TESTS_RUN + 1))

  if "$@" >/dev/null 2>&1; then
    _TESTS_PASSED=$((_TESTS_PASSED + 1))
    printf '  [PASS] %s\n' "$desc"
  else
    _TESTS_FAILED=$((_TESTS_FAILED + 1))
    printf '  [FAIL] %s (exit code: %d)\n' "$desc" "$?"
  fi
}

assert_failure() {
  # Usage: assert_failure "description" <command...>
  # Runs a command and asserts NON-zero exit code
  local desc="$1"; shift
  _TESTS_RUN=$((_TESTS_RUN + 1))

  if "$@" >/dev/null 2>&1; then
    _TESTS_FAILED=$((_TESTS_FAILED + 1))
    printf '  [FAIL] %s (expected failure, got success)\n' "$desc"
  else
    _TESTS_PASSED=$((_TESTS_PASSED + 1))
    printf '  [PASS] %s\n' "$desc"
  fi
}

# Print summary and return appropriate exit code
test_summary() {
  printf '\n--- %d tests: %d passed, %d failed ---\n' \
    "$_TESTS_RUN" "$_TESTS_PASSED" "$_TESTS_FAILED"
  [[ "$_TESTS_FAILED" -eq 0 ]]
}

# --- Load libs in a test-safe way ---
# Source colors first but don't init (no TTY in CI)
# shellcheck disable=SC1091
source "$LIB_DIR/colors.sh"
# Set empty color vars so log.sh works without a TTY
# shellcheck disable=SC2034
RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
# shellcheck disable=SC1091
source "$LIB_DIR/log.sh"
