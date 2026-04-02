#!/usr/bin/env bash
# scripts/lib/args.sh
# shellcheck disable=SC2034  # Globals consumed by sourcing scripts
#
# Purpose:
#   Parse common installer flags shared across entrypoints.
#
# Common flags supported:
#   -h, --help
#   -f, --force
#   -v, --verbose
#   --dry-run
#
# Design:
#   - This parser is intentionally conservative.
#   - By default, it stops when it sees an unknown flag so the caller can
#     pass remaining args through to an OS-specific installer.
#
# Outputs:
#   - Sets: FORCE, VERBOSE, DRY_RUN, SHOW_HELP
#   - Sets: REMAINING_ARGS (array)

reset_common_flags() {
  FORCE=false
  VERBOSE=false
  DRY_RUN=false
  SHOW_HELP=false
  REMAINING_ARGS=()
}

parse_common_flags() {
  reset_common_flags

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        SHOW_HELP=true
        shift
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --)
        shift
        REMAINING_ARGS+=("$@")
        return 0
        ;;
      -*)
        # Unknown flag: stop parsing so caller can handle/pass through.
        REMAINING_ARGS+=("$@")
        return 0
        ;;
      *)
        REMAINING_ARGS+=("$@")
        return 0
        ;;
    esac
  done
}

print_common_flags_help() {
  # Print the shared flags block (callers embed it in their usage text).
  cat <<'EOF'
  -h, --help      Show this help message
  -f, --force     Proceed without confirmation prompts
  -v, --verbose   Enable debug logs
  --dry-run       Print commands without executing
EOF
}
