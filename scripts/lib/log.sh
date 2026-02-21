#!/usr/bin/env bash
# scripts/lib/log.sh
#
# Purpose:
#   Provide consistent log functions for installers.
#
# Usage:
#   source ".../colors.sh"; init_colors
#   source ".../log.sh"
#   VERBOSE=true
#   log_info "message"
#
# Notes:
#   - Uses printf rather than echo -e for portability.
#   - `log_debug` prints only when VERBOSE=true.

log_info() {
  printf '%s[INFO]%s %s\n' "${BLUE:-}" "${RESET:-}" "$*"
}

log_success() {
  printf '%s[✓]%s %s\n' "${GREEN:-}" "${RESET:-}" "$*"
}

log_warning() {
  printf '%s[!]%s %s\n' "${YELLOW:-}" "${RESET:-}" "$*"
}

log_error() {
  printf '%s[✗]%s %s\n' "${RED:-}" "${RESET:-}" "$*" 1>&2
}

log_debug() {
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    printf '%s[DEBUG]%s %s\n' "${BOLD:-}" "${RESET:-}" "$*"
  fi
}
