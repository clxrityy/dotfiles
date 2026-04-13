#!/usr/bin/env bash
# scripts/lib/banner.sh
#
# Purpose:
#   Print consistent banners/headers for installers.

# REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
# LIB_DIR="$REPO_DIR/scripts/lib"
# # shellcheck source=/dev/null
# source "$LIB_DIR/colors.sh"
# init_colors
# ------- ^ these should be sourced by the caller script, not the banner library itself, to avoid redundant sourcing and allow the caller to control when colors are initialized.

# Helper function to pad line to box width
pad_line() {
    local box_width=40
    local text="$1"
    local stripped visible_len padding

    # Strip ANSI escape sequences so width math uses only visible characters.
    # - CSI: ESC [ ... command   (colors/styles like setaf, bold, sgr0 tail)
    # - SCS: ESC ( X             (macOS tput sgr0 commonly emits ESC(B)
    stripped="$(printf '%s' "$text" | sed -E $'s/\x1B\\[[0-?]*[ -/]*[@-~]//g; s/\x1B\\([0-9A-Za-z]//g')"

    visible_len=${#stripped}
    padding=$((box_width - visible_len))

    # Prevent negative padding from causing formatting issues.
    (( padding < 0 )) && padding=0

    printf '%s%*s' "$text" "$padding" ""
}

print_box_banner() {
  local title_line_1="$1"
  local title_line_2="$2"
  local extra_lines=("${@:3}") # Optional additional lines to print inside the box

  printf '\n'
  printf '%s╔════════════════════════════════════════╗%s\n' "${BOLD:-}" "${RESET:-}"

  printf '%s║%s║%s\n' "${BOLD:-}" "$(pad_line "$title_line_1")" "${RESET:-}"
  printf '%s║%s║%s\n' "${BOLD:-}" "$(pad_line "$title_line_2")" "${RESET:-}"

  if [ "${#extra_lines[@]}" -gt 0 ]; then
    for line in "${extra_lines[@]}"; do
      printf '%s║%s%s%s║\n' "${BOLD:-}" "$RESET" "$(pad_line "$line")" "${RESET:-}"
    done
  fi

  printf '%s╚════════════════════════════════════════╝%s\n' "${BOLD:-}" "${RESET:-}"
  printf '\n'
}
