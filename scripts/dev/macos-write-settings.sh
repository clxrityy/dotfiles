#!/usr/bin/env bash
# scripts/dev/write-settings.sh
#
# Purpose:
#   Read current macOS defaults and system settings, then regenerate
#   the macos/.macos script with the live values from this machine.
#
# Usage:
#   ./scripts/dev/write-settings.sh [--dry-run]
#
# Notes:
#   - Requires sudo for system-level settings (pmset, nvram, etc.)
#   - Only updates values it can read; preserves file structure via template.
#   - Run on the Mac whose settings you want to capture.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MACOS_FILE="$REPO_DIR/macos/.macos"
TEMPLATE_FILE="$MACOS_FILE"  # We read the existing file as template

# shellcheck source=/dev/null
source "$REPO_DIR/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/scripts/lib/log.sh"
init_colors

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# convert_plist_array <defaults_read_output>
# Converts plist array format to defaults write CLI format
#   "(\n    en,\n    nl\n)" -> "\"en\" \"nl\""
convert_plist_array() {
  local result=""
  while IFS= read -r item; do
    # Strip whitespace, commas, parentheses
    item="$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/,$//;s/^[()]$//')"
    [[ -z "$item" ]] && continue
    # Strip any existing quotes, then re-quote
    item="${item#\"}"
    item="${item%\"}"
    result+="\"${item}\" "
  done <<< "$1"
  echo "${result% }"
}

# read_default <domain> <key>
# Reads a single defaults value. Returns empty string on failure.
read_default() {
  local domain="$1" key="$2"
  defaults read "$domain" "$key" 2>/dev/null || echo ""
}

# read_sudo_default <domain_or_path> <key>
read_sudo_default() {
  local domain="$1" key="$2"
  sudo defaults read "$domain" "$key" 2>/dev/null || echo ""
}

# read_plistbuddy <file> <entry_path>
# PlistBuddy uses ':' delimited paths like :DesktopViewSettings:IconViewSettings:iconSize
read_plistbuddy() {
  local file="$1" entry="$2"
  /usr/libexec/PlistBuddy -c "Print $entry" "$file" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# Core: Parse existing .macos and replace values with current state
# ---------------------------------------------------------------------------
#
# Strategy: process the file line-by-line.
#   - Lines matching `defaults write ...` get their value replaced
#     with the live value from `defaults read`.
#   - Lines matching `sudo defaults write ...` use `sudo defaults read`.
#   - PlistBuddy "Set" lines use PlistBuddy "Print".
#   - Everything else (comments, pmset, etc.) passes through unchanged
#     unless explicitly handled.

# Pre-join backslash-continued lines into single logical lines
joined_input=""
buffer=""
while IFS= read -r line; do
  if [[ "$line" == *\\ ]]; then
    # Strip trailing backslash, accumulate
    buffer+="${line%\\} "
  else
    buffer+="${line}"
    joined_input+="${buffer}"$'\n'
    buffer=""
  fi
done < "$TEMPLATE_FILE"

output=""

while IFS= read -r line; do

if [[ "$line" =~ defaults[[:space:]]+write[[:space:]].*-(dict|dict-add) ]]; then
  output+="${line}"$'\n'

  # --- Handle: sudo defaults write <domain> <key> -<type> <value> ---
  elif [[ "$line" =~ ^([[:space:]]*)sudo[[:space:]]+defaults[[:space:]]+write[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+-([a-z]+)[[:space:]]+(.*) ]]; then
    indent="${BASH_REMATCH[1]}"
    domain="${BASH_REMATCH[2]}"
    key="${BASH_REMATCH[3]}"
    type_flag="${BASH_REMATCH[4]}"

    current="$(read_sudo_default "$domain" "$key")"

    if [[ -n "$current" ]]; then
      output+="${indent}sudo defaults write ${domain} ${key} -${type_flag} ${current}"$'\n'
    else
      output+="${line}"$'\n'
      log_warning "Could not read (sudo): ${domain} ${key}"
    fi

    # --- Handle: sudo defaults write <domain> <key> -array <values> ---
  elif [[ "$line" =~ ^([[:space:]]*)sudo[[:space:]]+defaults[[:space:]]+write[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+-array[[:space:]]+(.*) ]]; then
    indent="${BASH_REMATCH[1]}"
    domain="${BASH_REMATCH[2]}"
    key="${BASH_REMATCH[3]}"

    current="$(read_sudo_default "$domain" "$key")"

    if [[ -n "$current" ]]; then
      converted="$(convert_plist_array "$current")"
      output+="${indent}sudo defaults write ${domain} ${key} -array ${converted}"$'\n'
    else
      output+="${line}"$'\n'
    fi

  # --- Handle: defaults write <domain> <key> -array <values> ---
  elif [[ "$line" =~ ^([[:space:]]*)defaults[[:space:]]+write[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+-array[[:space:]]+(.*) ]]; then
    indent="${BASH_REMATCH[1]}"
    domain="${BASH_REMATCH[2]}"
    key="${BASH_REMATCH[3]}"

    current="$(read_default "$domain" "$key")"

    if [[ -n "$current" ]]; then
      converted="$(convert_plist_array "$current")"
      output+="${indent}defaults write ${domain} ${key} -array ${converted}"$'\n'
    else
      output+="${line}"$'\n'
    fi
  # --- Everything else: pass through verbatim ---
  else
    output+="${line}"$'\n'
  fi

done <<< "$joined_input"

# ---------------------------------------------------------------------------
# Write or print
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == true ]]; then
  log_info "Dry run — printing to stdout:"
  printf '%s' "$output"
else
  printf '%s' "$output" > "$MACOS_FILE"
  log_success "Updated ${MACOS_FILE} with current system values"
fi
