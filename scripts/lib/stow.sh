#!/usr/bin/env bash
# scripts/lib/stow.sh
#
# Purpose:
#   Centralize GNU Stow orchestration (backup + stow per package).
#
# Notes:
#   - This is intended for the root installer, but can be reused.
#   - We keep backups conservative: only move regular files (not symlinks).
#   - backup_stow_conflicts uses stow's own --simulate mode to detect
#     conflicts, guaranteeing we only touch what stow cares about.
#
# References:
#   - GNU Stow manual: https://www.gnu.org/software/stow/manual/stow.html

ensure_stow_installed() {
  local os_key="$1"

  if command -v stow >/dev/null 2>&1; then
    return 0
  fi

  log_error "GNU Stow is not installed. Please install it first."
  case "$os_key" in
    macos)
      log_info "Install with: brew install stow"
      ;;
    fedora)
      log_info "Install with: sudo dnf install -y stow"
      ;;
    debian)
      log_info "Install with: sudo apt install -y stow"
      ;;
    *)
      log_info "Install GNU Stow via your package manager."
      ;;
  esac
  exit 1
}

cleanup_legacy_root_package() {
  local repo_dir="$1"
  local stow_target="$2"
  local pkg_name="$3"
  local label="$4"

  # When a package moves from "macos" to "os/macos", existing links in the
  # target may still be owned by the old root-level package. Unstow that legacy
  # package first so the nested package can take over cleanly.
  if [[ "$label" != */* ]]; then
    return 0
  fi

  if [[ ! -d "$repo_dir/$pkg_name" ]]; then
    return 0
  fi

  log_info "Cleaning up legacy root package '$pkg_name' before stowing '$label'"
  run_cmd stow -D --no-folding -d "$repo_dir" -t "$stow_target" "$pkg_name" || true
}

parse_stow_conflict_target() {
  local line="$1"

  # Older Stow output style:
  #   * cannot stow ../foo over existing target .bashrc since neither a link nor a directory
  if [[ "$line" =~ existing\ target\ (.+)\ since ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  # Newer Stow output styles:
  #   * existing target is neither a link nor a directory: .bashrc
  #   * existing target is stowed to a different package: .bashrc
  if [[ "$line" =~ existing\ target[^:]*:\ (.+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

# -----------------------------------------------------------------
# backup_stow_conflicts
# -----------------------------------------------------------------
# Ask stow itself (via --simulate / --no) what would conflict, then
# move only those specific files into a timestamped backup directory.
#
# Why let stow detect conflicts instead of `find`-walking ourselves?
#   - Stow honours .stow-local-ignore / .stow-global-ignore rules.
#   - Stow understands its own folding/unfolding semantics.
#   - We never diverge from what stow actually considers a conflict.
#
# Arguments:
#   1: stow_dir    – parent directory for `stow -d`
#   2: pkg_name    – the package folder name (basename only)
#   3: stow_target – destination directory for `stow -t`
#   4: backup_dir  – shared backup root for this installer run
# -----------------------------------------------------------------
backup_stow_conflicts() {
  local stow_dir="$1"
  local pkg_name="$2"
  local stow_target="$3"
  local backup_dir="$4"

  # Run stow in simulate mode — it exits non-zero and prints conflicts
  # to stderr when there are existing files in the way.
  # Example conflict line:
  #   * cannot stow ../foo over existing target .bashrc since neither a link nor a directory ...
  local sim_output
  sim_output="$(stow --no-folding --simulate -d "$stow_dir" -t "$stow_target" "$pkg_name" 2>&1)" || true

  # No output (or no "existing target") ⇒ nothing to back up.
  if [[ -z "$sim_output" ]] || ! echo "$sim_output" | grep -q "existing target"; then
    return 0
  fi

  local pkg_backup_dir="$backup_dir/$pkg_name"
  log_info "Backing up conflicting files for '$pkg_name' -> $pkg_backup_dir"

  # Parse conflict lines to extract the target-relative file paths.
  # Format: "* cannot stow <link> over existing target <rel_path> since ..."
  local rel_path target_file dest moved_any=false dry_run_conflicts=false removed_symlink=false
  while IFS= read -r line; do
    rel_path=""
    if rel_path="$(parse_stow_conflict_target "$line")"; then
      target_file="$stow_target/$rel_path"

      # Safety check: only move regular files (not symlinks or dirs).
      if [[ -f "$target_file" && ! -L "$target_file" ]]; then
        dest="$pkg_backup_dir/$rel_path"
        run_cmd mkdir -p "$(dirname "$dest")"
        log_debug "Backing up: $target_file -> $dest"
        run_cmd mv "$target_file" "$dest"
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
          dry_run_conflicts=true
        else
          moved_any=true
        fi
      elif [[ -L "$target_file" && ! -e "$target_file" ]]; then
        log_debug "Removing dangling symlink: $target_file"
        run_cmd rm "$target_file"
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
          dry_run_conflicts=true
        else
          removed_symlink=true
        fi
      fi
    fi
  done <<< "$sim_output"

  if [[ "$moved_any" == "true" ]]; then
    log_success "Conflicting files for '$pkg_name' backed up"
  elif [[ "$removed_symlink" == "true" ]]; then
    log_success "Dangling symlinks for '$pkg_name' removed"
  elif [[ "$dry_run_conflicts" == "true" ]]; then
    log_info "Dry-run: conflicting files for '$pkg_name' would be backed up"
  else
    log_warning "Stow reported conflicts for '$pkg_name', but no regular files were moved automatically"
  fi
}

# -----------------------------------------------------------------
# stow_package
# -----------------------------------------------------------------
# Stow a single package after backing up any conflicting files.
#
# Factored out of the main loop so both the packages_conf iteration
# and the special-case `private` package use the same code path.
#
# Arguments:
#   1: stow_dir    – parent directory for `stow -d`
#   2: pkg_name    – the package folder name (basename only)
#   3: stow_target – destination directory for `stow -t`
#   4: backup_dir  – shared backup root (timestamped)
#   5: label       – display name for log messages
#   6: scope       – scope tag for log messages
# -----------------------------------------------------------------
stow_package() {
  local stow_dir="$1"
  local pkg_name="$2"
  local stow_target="$3"
  local backup_dir="$4"
  local label="$5"
  local scope="$6"
  local repo_dir="$7"

  cleanup_legacy_root_package "$repo_dir" "$stow_target" "$pkg_name" "$label"

  # Let stow identify its own conflicts, then move only those files.
  backup_stow_conflicts "$stow_dir" "$pkg_name" "$stow_target" "$backup_dir"

  log_info "Stowing '$label' -> '$stow_target' (scope: $scope)"
  run_cmd stow --no-folding -d "$stow_dir" -t "$stow_target" "$pkg_name"
}

stow_packages_for_os() {
  # Arguments:
  #   1: repo_dir  – repository root (stow -d base)
  #   2: os_key    – detected OS identifier (macos|fedora|...)
  local repo_dir="$1"
  local os_key="$2"

  log_debug "Stow repo directory: $repo_dir"
  log_debug "Operating system key: $os_key"

  # packages_conf is a flat array of triplets (name, scope, target)
  # populated by load_packages_conf() from packages.sh.
  # shellcheck disable=SC2154
  if [[ ${#packages_conf[@]} -eq 0 ]]; then
    log_error "packages_conf is empty. Was load_packages_conf called?"
    exit 1
  fi

  # Single timestamp so all backups from this run land in one directory.
  local backup_dir
  backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

  local name scope target pkg_dir pkg_name stow_target stow_dir

  for ((i=0; i<${#packages_conf[@]}; i+=3)); do
    name="${packages_conf[i]}"
    scope="${packages_conf[i+1]}"
    target="${packages_conf[i+2]}"

    # Skip packages that don't apply to the current OS.
    if [[ "$scope" != "all" && "$scope" != "$os_key" ]]; then
      log_debug "Skipping '$name' (scope: $scope, os: $os_key)"
      continue
    fi

    log_debug "Scope match for package '$name' (scope: $scope)"

    if [[ ! -d "$repo_dir/$name" ]]; then
      log_warning "Package '$name' listed in packages.conf but directory not found - skipping."
      continue
    fi

    # Resolve stow target: use custom target if provided, otherwise $HOME.
    stow_target="${target:-$HOME}"

    # Ensure the target directory exists before stowing into it.
    run_cmd mkdir -p "$stow_target"

    # Stow requires a single-level package name — split nested paths so
    # "os/macos/editors/nvim" becomes: -d "$repo_dir/os/macos/editors"  nvim
    pkg_dir="$(dirname "$name")"
    pkg_name="$(basename "$name")"

    [[ -n "$target" ]] && log_debug "Package '$name' has custom target: $stow_target"

    # Determine the effective stow directory.
    if [[ "$pkg_dir" == "." ]]; then
      stow_dir="$repo_dir"
    else
      stow_dir="$repo_dir/$pkg_dir"
    fi

    stow_package "$stow_dir" "$pkg_name" "$stow_target" "$backup_dir" "$name" "$scope" "$repo_dir"
  done

  log_debug "Stowed all applicable packages from packages.conf"

  # Stow the private package last if it exists.
  if [[ -d "$repo_dir/private" ]]; then
    log_debug "Found 'private' package directory"
    stow_package "$repo_dir" "private" "$HOME" "$backup_dir" "private" "all" "$repo_dir"
  else
    log_debug "'private' package directory not found - skipping."
  fi

  log_success "Dotfiles symlinked successfully!"
}
