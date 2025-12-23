#!/usr/bin/env bash
# scripts/lib/banner.sh
#
# Purpose:
#   Print consistent banners/headers for installers.

print_box_banner() {
  local title_line_1="$1"
  local title_line_2="$2"

  printf '\n'
  printf '%s╔════════════════════════════════════════╗%s\n' "${BOLD:-}" "${RESET:-}"
  printf '%s║%-40s║%s\n' "${BOLD:-}" "$title_line_1" "${RESET:-}"
  printf '%s║%-40s║%s\n' "${BOLD:-}" "$title_line_2" "${RESET:-}"
  printf '%s╚════════════════════════════════════════╝%s\n' "${BOLD:-}" "${RESET:-}"
  printf '\n'
}
