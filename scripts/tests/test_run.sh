#!/usr/bin/env bash
# scripts/tests/test_run.sh -- Tests for run.sh

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
source "$LIB_DIR/run.sh"

printf 'test_run.sh\n'

# --- need_cmd ---

assert_success "need_cmd finds bash" need_cmd bash
assert_success "need_cmd finds printf" need_cmd printf
assert_failure "need_cmd fails for nonexistent" need_cmd __nonexistent_cmd_xyz__

# --- run_cmd with DRY_RUN ---

DRY_RUN=true
# In dry-run mode, even a command that doesn't exist should "succeed"
# because it's never actually executed
output="$(run_cmd __fake_command__ 2>&1)"
assert_eq "run_cmd dry-run doesn't execute" "0" "$?"
# Verify the output mentions DRY-RUN
case "$output" in
  *DRY-RUN*) assert_eq "dry-run output contains marker" "yes" "yes" ;;
  *)         assert_eq "dry-run output contains DRY-RUN marker" "contains DRY-RUN" "$output" ;;
esac

# shellcheck disable=SC2034
DRY_RUN=false
# Real execution -- echo should succeed
assert_success "run_cmd executes real commands" run_cmd echo "hello"

test_summary
