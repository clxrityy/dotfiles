#!/usr/bin/env bash

# scripts/lib/packages.sh
# Purpose:
#   Provide package management utilities for dotfiles installation.
# Notes:
#   - This is intended for the root installer, but can be reused.
# References:
#   - None yet.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
packages_conf_dir="$repo_dir/packages.conf"

# Global flat array of triplets (name, scope, target).
# Populated by load_packages_conf().
packages_conf=()

trim() {
  # Trim leading/trailing whitespace from a string.
  local var="$*"
  # shellcheck disable=SC2001
  var="$(echo -e "$var" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  printf '%s' "$var"
}

load_packages_conf() {
  packages_conf=() # Reset the array

  if [[ ! -f "$packages_conf_dir" ]]; then
    log_error "Packages configuration file not found: $packages_conf_dir"
    exit 1
  fi

  log_debug "Loading packages from: $packages_conf_dir"

  local name scope target

  while IFS='=' read -r name scope; do
    name="$(trim "${name%%#*}")"
    scope="$(trim "${scope%%#*}")"

    [[ -z "$name" || -z "$scope" ]] && continue

    # Split scope:target
    target="${scope#*:}"
    scope="${scope%%:*}"
    [[ "$target" == "$scope" ]] && target=""
    [[ -n "$target" ]] && target="${target/\~/$HOME}"

    # Append as a flat triplet: name, scope, target
    packages_conf+=( "$name" "$scope" "$target" )

    log_debug "Package: $name, Scope: $scope, Target: $target"
  done < "$packages_conf_dir"
}


resolve_path() {
  # Resolve an absolute path, similar to `readlink -f`.
  local input="$1"

  # macOS `realpath` (commonly via coreutils).
  if command -v realpath >/dev/null 2>&1; then
    realpath "$input"
    return 0
  fi
  # Python tends to exist on both macOS and Linux; prefer it when available.
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$input"
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
    return 0
  fi
  # GNU coreutils `readlink -f` (commonly on Linux).
  if readlink -f / >/dev/null 2>&1; then
    readlink -f "$input"
    return 0
  fi
  # Best-effort: absolute path without resolving symlinks.
  local dir
  dir="$(cd "$(dirname "$input")" >/dev/null 2>&1 && pwd)"
  printf '%s/%s\n' "$dir" "$(basename "$input")"
}

realpath_compat() {
  # Wrapper for resolve_path to mimic realpath behavior.
  resolve_path "$1"
}
