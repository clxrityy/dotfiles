#!/usr/bin/env bash
# scripts/dev/copy-package.sh
#
# Purpose:
#   Copy a specific package's live target contents back into a destination
#   directory (e.g., the repo package dir) for development/testing.
#
# Usage:
#   ./scripts/dev/copy-package.sh <package_name> <destination>
#
# Example:
#   ./scripts/dev/copy-package.sh prompts ./prompts
#     Copies ~/Library/Application Support/Code/User/prompts -> ~/.dotfiles/prompts
#
# Notes:
#   - Reads packages.conf to resolve the package's configured target path and scope.
#   - Scope is enforced: a macOS-only package will hard-fail on a non-macOS system.
#   - Only packages WITH an explicit target path are supported (e.g. prompts=macos:~/...).
#     Packages without a target path (e.g. common=all) have no single source directory
#     to pull from and are therefore unsupported by this script.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_DIR/scripts/lib/colors.sh"
init_colors

# shellcheck source=/dev/null
source "$REPO_DIR/scripts/lib/log.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/scripts/lib/os.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/scripts/lib/packages.sh"

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [[ $# -ne 2 ]]; then
  log_error "Usage: $0 <package_name> <destination>"
  exit 1
fi

package_name="$1"
raw_destination="$2"

# ---------------------------------------------------------------------------
# Load packages and locate the named entry
# ---------------------------------------------------------------------------
load_packages_conf

current_os="$(detect_os_key)"
log_debug "Detected OS: $current_os"

found=0

# shellcheck disable=SC2154
for ((i = 0; i < ${#packages_conf[@]}; i += 3)); do
  name="${packages_conf[i]}"
  scope="${packages_conf[i+1]}"
  target="${packages_conf[i+2]}"

  # Only process the package we're looking for.
  [[ "$name" != "$package_name" ]] && continue
  found=1

  # Scope enforcement: hard-fail rather than silently skipping.
  # A macos-scoped package must not be copied on a Linux system, etc.
  if [[ "$scope" != "all" && "$scope" != "$current_os" ]]; then
    log_error "Package '$package_name' is scoped to '$scope', but current OS is '$current_os'."
    exit 1
  fi

  # Packages without an explicit target path (e.g. common=all, shell=all) stow
  # straight into $HOME — there's no single subdirectory to pull from.
  if [[ -z "$target" ]]; then
    log_error "Package '$package_name' has no explicit target path in packages.conf."
    log_error "Only packages with a target path (e.g. name=scope:~/some/path) are supported."
    exit 1
  fi

  # 'target' is already tilde-expanded by load_packages_conf.
  source_dir="$target"

  if [[ ! -d "$source_dir" ]]; then
    log_error "Source directory does not exist: $source_dir"
    exit 1
  fi

  # Resolve destination — expand relative paths against $PWD before mkdir.
  # realpath_compat (via Python / GNU readlink) handles non-existent paths too.
  parent="$(realpath_compat "$(dirname "$raw_destination")")"
  dest_dir="$parent/$(basename "$raw_destination")"
  mkdir -p "$dest_dir"

  log_info "Package:     $name"
  log_info "Scope:       $scope"
  log_info "Source:      $source_dir"
  log_info "Destination: $dest_dir"

  # -a preserves permissions, timestamps, and symlinks.
  cp -a "$source_dir/." "$dest_dir/"

  log_success "Copied '$name': '$source_dir' -> '$dest_dir'"
  break
done

if [[ $found -eq 0 ]]; then
  log_error "Package '$package_name' not found in packages.conf"
  exit 1
fi
