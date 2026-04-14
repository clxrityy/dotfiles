#!/usr/bin/env bash
# scripts/dev/migrate-package.sh
#
# Migrate a single package:
#   1) Unstow current package from its current target (if applicable on this OS)
#   2) Rename package directory in repo (if new name differs)
#   3) Stow new package to new target (if applicable on this OS)
#   4) Update packages.conf entry
#
# Usage:
#   ./scripts/dev/migrate-package.sh [--dry-run] <current-package> <scope[:target]> [new-package]
#
# Example:
#   ./scripts/dev/migrate-package.sh prompts macos:~/.copilot copilot

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"
PACKAGES_CONF="$REPO_DIR/packages.conf"

# Shared libs (colors/log/banner/prompt)
# shellcheck source=/dev/null
source "$SCRIPTS_DIR/source.sh"
# Common flags: --help --force --verbose --dry-run
# shellcheck source=/dev/null
source "$LIB_DIR/args.sh"
# run_cmd (dry-run aware)
# shellcheck source=/dev/null
source "$LIB_DIR/run.sh"
# OS detection
# shellcheck source=/dev/null
source "$LIB_DIR/os.sh"
# packages.conf parsing + trim helper
# shellcheck source=/dev/null
source "$LIB_DIR/packages.sh"
# ensure_stow_installed helper
# shellcheck source=/dev/null
source "$LIB_DIR/stow.sh"

CURRENT_PACKAGE=""
TARGET_SPEC=""
NEW_PACKAGE=""

CURRENT_SCOPE=""
CURRENT_TARGET_RESOLVED=""
NEW_SCOPE=""
NEW_TARGET_RAW=""
NEW_TARGET_RESOLVED=""
CURRENT_OS=""

STOW_DIR=""
STOW_PKG_NAME=""

usage() {
  cat << EOF
${BOLD}Usage:${RESET}
  ${GREEN}$(basename "$0")${RESET} ${BLUE}[options] <current-package> <scope[:target]> [new-package]${RESET}

${BOLD}Description:${RESET}
  Migrate a single package in this repo and replace its stow operation.

${BOLD}Options:${RESET}
$(print_common_flags_help)

${BOLD}Arguments:${RESET}
  current-package   Existing package key in packages.conf (e.g. prompts)
  scope[:target]    New value RHS for packages.conf (e.g. macos:~/.copilot)
  new-package       New package directory/key name (defaults to current-package)

${BOLD}Example:${RESET}
  ${GREEN}./scripts/dev/migrate-package.sh prompts macos:~/.copilot copilot${RESET}
EOF
}

expand_tilde() {
  # Expand only a leading ~ for HOME portability.
  local p="$1"
  if [[ "$p" == "~" ]]; then
    printf '%s' "$HOME"
  elif [[ "$p" == ~/* ]]; then
    printf '%s' "$HOME/${p#~/}"
  else
    printf '%s' "$p"
  fi
}

set_stow_context() {
  # Convert package path to the (-d, package_name) pair expected by stow.
  # Example:
  #   package "prompts"        -> -d "$REPO_DIR",            "prompts"
  #   package "foo/bar/baz"    -> -d "$REPO_DIR/foo/bar",    "baz"
  local package_name="$1"
  local pkg_dir
  pkg_dir="$(dirname "$package_name")"
  STOW_PKG_NAME="$(basename "$package_name")"

  if [[ "$pkg_dir" == "." ]]; then
    STOW_DIR="$REPO_DIR"
  else
    STOW_DIR="$REPO_DIR/$pkg_dir"
  fi
}

validate_package_key() {
  local label="$1"
  local value="$2"

  # Match repo convention used by test_config.sh
  if [[ ! "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid ${label}: '$value'"
    log_error "Package keys must match ^[a-zA-Z0-9_-]+$ (no '/', '~', ':', or path-like values)."
    exit 1
  fi
}

parse_cli() {
  parse_common_flags "$@"

  # Help should work even without positional args.
  if [[ "$SHOW_HELP" == "true" ]]; then
    usage
    exit 0
  fi

  # parse_common_flags stores non-common args here.
  set -- "${REMAINING_ARGS[@]}"

  if [[ $# -lt 2 || $# -gt 3 ]]; then
    log_error "Usage: $0 [--dry-run] <current-package> <scope[:target]> [new-package]"
    exit 1
  fi

  CURRENT_PACKAGE="$1"
  TARGET_SPEC="$2"
  NEW_PACKAGE="${3:-$CURRENT_PACKAGE}"

  # Prevent unknown options being treated as package/scope values.
  if [[ "$CURRENT_PACKAGE" == -* || "$TARGET_SPEC" == -* || "$NEW_PACKAGE" == -* ]]; then
    log_error "Invalid argument. Did you pass an unknown option?"
    usage
    exit 1
  fi

  # Validate package keys only after assigning positional args.
  validate_package_key "current-package" "$CURRENT_PACKAGE"
  validate_package_key "new-package" "$NEW_PACKAGE"
}

parse_target_spec() {
  # TARGET_SPEC format: scope[:target]
  NEW_SCOPE="${TARGET_SPEC%%:*}"
  if [[ ! "$NEW_SCOPE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid scope '$NEW_SCOPE' in target spec '$TARGET_SPEC'."
    exit 1
  fi
  NEW_TARGET_RAW=""

  if [[ "$TARGET_SPEC" == *:* ]]; then
    NEW_TARGET_RAW="${TARGET_SPEC#*:}"
  fi

  if [[ -z "$NEW_SCOPE" ]]; then
    log_error "Invalid target spec '$TARGET_SPEC': scope cannot be empty."
    exit 1
  fi

  if [[ -n "$NEW_TARGET_RAW" ]]; then
    NEW_TARGET_RESOLVED="$(expand_tilde "$NEW_TARGET_RAW")"
  else
    # No explicit target means default stow target ($HOME), same as install flow.
    NEW_TARGET_RESOLVED="$HOME"
  fi
}

resolve_current_entry() {
  # Ensure we read the repo's real packages.conf.
  # shellcheck disable=SC2034
  packages_conf_dir="$PACKAGES_CONF"
  load_packages_conf

  local found=false
  local new_exists=false
  local name scope target

  # shellcheck disable=SC2154
  for ((i=0; i<${#packages_conf[@]}; i+=3)); do
    name="${packages_conf[i]}"
    scope="${packages_conf[i+1]}"
    target="${packages_conf[i+2]}"

    if [[ "$name" == "$CURRENT_PACKAGE" ]]; then
      found=true
      CURRENT_SCOPE="$scope"
      CURRENT_TARGET_RESOLVED="${target:-$HOME}"
    fi

    if [[ "$name" == "$NEW_PACKAGE" && "$name" != "$CURRENT_PACKAGE" ]]; then
      new_exists=true
    fi
  done

  if [[ "$found" != "true" ]]; then
    log_error "Package '$CURRENT_PACKAGE' not found in packages.conf."
    exit 1
  fi

  if [[ "$new_exists" == "true" ]]; then
    log_error "Package '$NEW_PACKAGE' already exists in packages.conf."
    log_error "Choose a different new-package name or remove the existing entry first."
    exit 1
  fi
}

validate_preconditions() {
  if [[ ! -f "$PACKAGES_CONF" ]]; then
    log_error "Missing packages.conf: $PACKAGES_CONF"
    exit 1
  fi

  if [[ ! -d "$REPO_DIR/$CURRENT_PACKAGE" ]]; then
    log_error "Current package directory does not exist: $REPO_DIR/$CURRENT_PACKAGE"
    exit 1
  fi

  if [[ "$NEW_PACKAGE" != "$CURRENT_PACKAGE" && -e "$REPO_DIR/$NEW_PACKAGE" ]]; then
    log_error "Target package directory already exists: $REPO_DIR/$NEW_PACKAGE"
    log_error "Refusing to overwrite existing package directory."
    exit 1
  fi

  CURRENT_OS="$(detect_os_key)"
  ensure_stow_installed "$CURRENT_OS"

  if [[ "$CURRENT_SCOPE" != "all" && "$CURRENT_SCOPE" != "$CURRENT_OS" ]]; then
    log_warning "Current package scope '$CURRENT_SCOPE' does not match current OS '$CURRENT_OS'."
    log_warning "Unstow step will be skipped."
  fi

  if [[ "$NEW_SCOPE" != "all" && "$NEW_SCOPE" != "$CURRENT_OS" ]]; then
    log_warning "New scope '$NEW_SCOPE' does not match current OS '$CURRENT_OS'."
    log_warning "Stow step will be skipped."
  fi
}

print_banner() {
  print_box_banner "       clxrityy/dotfiles" "     Package Migration (single package)" \
    "      ${YELLOW}~/ ${RESET}: ${CURRENT_PACKAGE}${RESET} ${YELLOW}(current package)${RESET}" \
    "      ${CYAN}+/${RESET}: ${UNDERLINE}${TARGET_SPEC}${RESET} ${CYAN}(location)${RESET}" \
    "      ${GREEN}~/${RESET}: ${BOLD}${NEW_PACKAGE}${RESET} ${GREEN}(new package name)${RESET}"
}

unstow_current_package() {
  if [[ "$CURRENT_SCOPE" != "all" && "$CURRENT_SCOPE" != "$CURRENT_OS" ]]; then
    log_info "Skipping unstow for '$CURRENT_PACKAGE' (scope mismatch)."
    return 0
  fi

  if [[ ! -d "$CURRENT_TARGET_RESOLVED" ]]; then
    log_warning "Current target does not exist: $CURRENT_TARGET_RESOLVED"
    log_warning "Skipping unstow."
    return 0
  fi

  set_stow_context "$CURRENT_PACKAGE"
  log_info "Unstowing '$CURRENT_PACKAGE' from '$CURRENT_TARGET_RESOLVED'..."
  run_cmd stow --no-folding -D -d "$STOW_DIR" -t "$CURRENT_TARGET_RESOLVED" "$STOW_PKG_NAME"
}

rename_package_directory() {
  if [[ "$CURRENT_PACKAGE" == "$NEW_PACKAGE" ]]; then
    log_info "Package name unchanged; skipping directory rename."
    return 0
  fi

  local old_path="$REPO_DIR/$CURRENT_PACKAGE"
  local new_path="$REPO_DIR/$NEW_PACKAGE"

  # Ensure parent exists for nested package names.
  run_cmd mkdir -p "$(dirname "$new_path")"

  log_info "Renaming package directory: '$CURRENT_PACKAGE' -> '$NEW_PACKAGE'"
  run_cmd mv "$old_path" "$new_path"
}

stow_new_package() {
  if [[ "$NEW_SCOPE" != "all" && "$NEW_SCOPE" != "$CURRENT_OS" ]]; then
    log_info "Skipping stow for '$NEW_PACKAGE' (scope mismatch)."
    return 0
  fi

  set_stow_context "$NEW_PACKAGE"
  run_cmd mkdir -p "$NEW_TARGET_RESOLVED"

  log_info "Stowing '$NEW_PACKAGE' to '$NEW_TARGET_RESOLVED'..."
  run_cmd stow --no-folding -d "$STOW_DIR" -t "$NEW_TARGET_RESOLVED" "$STOW_PKG_NAME"
}

render_replacement_line() {
  # Build the updated line while preserving inline comments.
  local original_line="$1"
  local comment_part=""

  if [[ "$original_line" == *"#"* ]]; then
    comment_part="${original_line#*#}"
    printf '%s=%s #%s' "$NEW_PACKAGE" "$TARGET_SPEC" "$comment_part"
  else
    printf '%s=%s' "$NEW_PACKAGE" "$TARGET_SPEC"
  fi
}

update_packages_conf() {
  local line stripped key replacement
  local match_count=0

  if [[ "$DRY_RUN" == "true" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      stripped="$(trim "${line%%#*}")"
      [[ -z "$stripped" || "$stripped" != *=* ]] && continue

      key="$(trim "${stripped%%=*}")"
      if [[ "$key" == "$CURRENT_PACKAGE" ]]; then
        replacement="$(render_replacement_line "$line")"
        log_info "[DRY-RUN] packages.conf before: $line"
        log_info "[DRY-RUN] packages.conf after : $replacement"
        match_count=$((match_count + 1))
      fi
    done < "$PACKAGES_CONF"

    if [[ "$match_count" -ne 1 ]]; then
      log_error "Expected exactly 1 '$CURRENT_PACKAGE' entry in packages.conf, found $match_count."
      exit 1
    fi
    return 0
  fi

  local tmp
  tmp="$(mktemp)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    stripped="$(trim "${line%%#*}")"

    if [[ -n "$stripped" && "$stripped" == *=* ]]; then
      key="$(trim "${stripped%%=*}")"
      if [[ "$key" == "$CURRENT_PACKAGE" ]]; then
        replacement="$(render_replacement_line "$line")"
        printf '%s\n' "$replacement" >> "$tmp"
        match_count=$((match_count + 1))
        continue
      fi
    fi

    printf '%s\n' "$line" >> "$tmp"
  done < "$PACKAGES_CONF"

  if [[ "$match_count" -ne 1 ]]; then
    rm -f "$tmp"
    log_error "Expected exactly 1 '$CURRENT_PACKAGE' entry in packages.conf, found $match_count."
    exit 1
  fi

  run_cmd mv "$tmp" "$PACKAGES_CONF"
  log_success "Updated packages.conf: '$CURRENT_PACKAGE' -> '$NEW_PACKAGE=$TARGET_SPEC'"
}

main() {
  parse_cli "$@"
  parse_target_spec
  resolve_current_entry
  validate_preconditions

  print_banner
  log_info "Starting package migration..."

  unstow_current_package
  rename_package_directory
  stow_new_package
  update_packages_conf

  log_success "Migration complete."
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry-run mode: no changes were written."
  fi
}

main "$@"
