#!/usr/bin/env bash
# scripts/lib/os.sh
#
# Purpose:
#   OS / distro detection and OS-specific guards.
#
# Notes:
#   - Root installer uses `detect_os_key` for routing.
#   - OS installers use `require_macos` / `require_fedora`.

# Returns one of:
#   macos, fedora, debian, arch, linux, unknown
# This intentionally mirrors common dotfiles patterns.
# Reference:
#   - OSTYPE variable: https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html

detect_os_key() {
  case "${OSTYPE:-}" in
    darwin*)
      printf '%s' "macos"
      ;;
    linux*)
      if [[ -f /etc/fedora-release ]]; then
        printf '%s' "fedora"
      elif [[ -f /etc/debian_version ]]; then
        printf '%s' "debian"
      elif [[ -f /etc/arch-release ]]; then
        printf '%s' "arch"
      else
        printf '%s' "linux"
      fi
      ;;
    *)
      printf '%s' "unknown"
      ;;
  esac
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script is for macOS only. Detected: $(uname -s)"
    exit 1
  fi
}

require_fedora() {
  if [[ ! -f /etc/fedora-release ]]; then
    log_error "This script is for Fedora only."
    exit 1
  fi
}

get_arch_key() {
  # Normalized arch key: arm64 or x86_64 (otherwise raw uname -m)
  local arch
  arch="$(uname -m)"
  case "$arch" in
    arm64|aarch64) printf '%s' "arm64" ;;
    x86_64)        printf '%s' "x86_64" ;;
    *)             printf '%s' "$arch" ;;
  esac
}
