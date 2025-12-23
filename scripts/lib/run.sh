#!/usr/bin/env bash
# scripts/lib/run.sh
#
# Purpose:
#   Helpers for executing commands with dry-run support and dependency checks.
#
# Why not eval:
#   `eval` is error-prone with quoting and increases risk. We execute commands
#   as argv arrays instead.
#
# Reference:
#   - Bash manual: https://www.gnu.org/software/bash/manual/

need_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    log_error "Missing required command: $name"
    return 1
  fi
}

# Print a shell-escaped preview of a command.
_print_cmd_preview() {
  local out=""
  local arg
  for arg in "$@"; do
    # %q prints a reusable shell-escaped token.
    out+="$(printf '%q ' "$arg")"
  done
  printf '%s' "${out% }"
}

run_cmd() {
  # Usage:
  #   run_cmd brew update
  #   run_cmd sudo dnf install -y git
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would execute: $(_print_cmd_preview "$@")"
    return 0
  fi

  log_debug "Executing: $(_print_cmd_preview "$@")"
  "$@"
}
