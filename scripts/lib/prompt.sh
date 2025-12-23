#!/usr/bin/env bash
# scripts/lib/prompt.sh
#
# Purpose:
#   Consistent interactive prompts across installers.

confirm_or_exit() {
  local prompt_text="$1"

  if [[ "${FORCE:-false}" == "true" ]]; then
    log_info "Force flag set; proceeding without confirmation."
    return 0
  fi

  # Read a single character response.
  read -r -p "$prompt_text (y/n): " -n 1
  printf '\n'

  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    log_info "Installation aborted by user."
    exit 0
  fi
}

confirm_yes_no() {
  # Like confirm_or_exit, but returns 0/1 instead of exiting.
  local prompt_text="$1"

  if [[ "${FORCE:-false}" == "true" ]]; then
    return 0
  fi

  read -r -p "$prompt_text (y/n): " -n 1
  printf '\n'
  [[ "$REPLY" =~ ^[Yy]$ ]]
}
