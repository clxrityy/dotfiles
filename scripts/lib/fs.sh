#!/usr/bin/env bash
# scripts/lib/fs.sh
#
# Purpose:
#   Small filesystem helpers (portable path resolution, file existence checks).
#
# Why:
#   macOS' default `readlink` lacks `-f`, while Linux often has it.
#   We provide a portable `realpath_compat` for installers.

realpath_compat() {
  # Print an absolute, symlink-resolved path when possible.
  # Falls back to a best-effort absolute path.
  local input="$1"

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

append_lines() {
  # Append one or more lines to a file.
  # Usage: append_lines /path/to/file "line1" "line2" ...
  #
  # This is preferred over `run_cmd echo ... >> file` because redirection is
  # handled by the current shell, not by the executed command.
  local file="$1"
  shift

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would append to $file:"
    local line
    for line in "$@"; do
      log_info "[DRY-RUN]   $line"
    done
    return 0
  fi

  local line
  for line in "$@"; do
    printf '%s\n' "$line" >> "$file"
  done
}

prepend_text() {
  # Prepend a block of text to a file.
  # Usage: prepend_text /path/to/file "$block"
  local file="$1"
  local block="$2"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would prepend text to $file"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  printf '%s' "$block" > "$tmp"
  cat "$file" >> "$tmp"
  mv "$tmp" "$file"
}
