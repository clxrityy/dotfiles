#!/usr/bin/env bash
# scripts/tests/test_args.sh -- Tests for args.sh flag parsing

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
source "$LIB_DIR/args.sh"

printf 'test_args.sh\n'

# --- parse_common_flags ---

parse_common_flags --help
assert_eq "parse --help sets SHOW_HELP=true" "true" "$SHOW_HELP"

parse_common_flags -f
assert_eq "parse -f sets FORCE=true" "true" "$FORCE"

parse_common_flags --verbose
assert_eq "parse --verbose sets VERBOSE=true" "true" "$VERBOSE"

parse_common_flags --dry-run
assert_eq "parse --dry-run sets DRY_RUN=true" "true" "$DRY_RUN"

# Verify reset between calls -- important because flags are globals
parse_common_flags  # no args
assert_eq "flags reset between calls (FORCE)" "false" "$FORCE"
assert_eq "flags reset between calls (DRY_RUN)" "false" "$DRY_RUN"

# Unknown flags go into REMAINING_ARGS
parse_common_flags -v --skip-brew --extra
assert_eq "VERBOSE parsed before unknown" "true" "$VERBOSE"
assert_eq "unknown flags captured in REMAINING_ARGS" "--skip-brew --extra" "${REMAINING_ARGS[*]}"

# -- separator passes everything after it
parse_common_flags -f -- --help --verbose
assert_eq "FORCE parsed before --" "true" "$FORCE"
assert_eq "args after -- are remaining" "--help --verbose" "${REMAINING_ARGS[*]}"
assert_eq "SHOW_HELP stays false after --" "false" "$SHOW_HELP"

test_summary
