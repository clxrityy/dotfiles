#!/usr/bin/env bash
# shellcheck disable=SC2034  # Color vars consumed by sourcing scripts
# scripts/lib/colors.sh
#
# Purpose:
#   Provide terminal color/style variables in a safe way.
#   Designed to be sourced by other bash scripts.
#
# Why this exists:
#   - Many install scripts duplicate tput/color setup.
#   - Under `set -e`, `tput` can cause unintended exits if TERM
#     is unset/unsupported; we guard it.
#
# Notes:
#   - This library defines functions only. It does NOT set strict mode.
#   - Call `init_colors` once early in your entrypoint.
#
# References:
#   - tput(1): https://man7.org/linux/man-pages/man1/tput.1.html

init_colors() {
  # Default to empty strings (no color).
  RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""

  # Only use colors when stdout is a TTY and tput is available.
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    # tput may fail if TERM is unknown; swallow failures.
    RED="$(tput setaf 1 2>/dev/null || true)"
    GREEN="$(tput setaf 2 2>/dev/null || true)"
    YELLOW="$(tput setaf 3 2>/dev/null || true)"
    BLUE="$(tput setaf 4 2>/dev/null || true)"
    BOLD="$(tput bold 2>/dev/null || true)"
    RESET="$(tput sgr0 2>/dev/null || true)"
  fi
}
