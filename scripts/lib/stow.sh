#!/usr/bin/env bash
# scripts/lib/stow.sh
#
# Purpose:
#   Centralize GNU Stow orchestration (backup + stow per package).
#
# Notes:
#   - This is intended for the root installer, but can be reused.
#   - We keep backups conservative: only move regular files (not symlinks).
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
    *)
      log_info "Install GNU Stow via your package manager."
      ;;
  esac
  exit 1
}

backup_conflicting_dotfiles() {
  # Backup a fixed set of common dotfiles if they exist as regular files.
  # This avoids clobbering user-managed configs.
  local backup_dir
  backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
  local files_to_check=(
    ".zshrc"
    ".zprofile"
    ".bashrc"
    ".bash_profile"
    ".editorconfig"
    ".gitconfig"
  )

  local needs_backup=false
  local file
  for file in "${files_to_check[@]}"; do
    if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
      needs_backup=true
      break
    fi
  done

  if [[ "$needs_backup" != "true" ]]; then
    return 0
  fi

  log_info "Backing up existing dotfiles to $backup_dir"
  run_cmd mkdir -p "$backup_dir"

  for file in "${files_to_check[@]}"; do
    if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
      log_debug "Backing up $file"
      run_cmd mv "$HOME/$file" "$backup_dir/"
    fi
  done

  log_success "Existing dotfiles backed up"
}

# -------------------------------------------------------------
# OLD VERSION OF FUNCTION - REPLACED BY PACKAGES.CONF LOGIC (↓)


# stow_packages_for_os() {
#   # Arguments:
#   #   1: repo_dir (stow -d)
#   #   2: os_key (macos|fedora|...)
#   local repo_dir="$1"
#   local os_key="$2"

#   log_info "Stowing common configurations..."
#   run_cmd stow -d "$repo_dir" -t "$HOME" common

#   log_info "Stowing shell configurations..."
#   run_cmd stow -d "$repo_dir" -t "$HOME" shell

#   case "$os_key" in
#     macos)
#       log_info "Stowing macOS configurations..."
#       run_cmd stow -d "$repo_dir" -t "$HOME" macos
#       ;;
#     fedora)
#       log_info "Stowing Fedora configurations..."
#       run_cmd stow -d "$repo_dir" -t "$HOME" fedora
#       ;;
#     *)
#       log_warning "No OS-specific stow package for: $os_key"
#       ;;
#   esac

#   log_success "Dotfiles symlinked successfully"
# }
# -------------------------------------------------------------

stow_packages_for_os() {
  # Arguments:
  #  1: repo_dir (stow -d)
  #  2: os_key (macos|fedora|...)
  local repo_dir="$1"
  local os_key="$2"

  # DEBUG LOGGING
  log_debug "Stow repo directory: $repo_dir"
  log_debug "Operating system key: $os_key"

  # packages_conf is a flat array of triplets (name, scope, target)
  # populated by load_packages_conf from packages.sh.
  # Callers are expected to have sourced packages.sh before calling this.
  # shellcheck disable=SC2154  
  # packages_conf is populated by packages.sh::load_packages_conf()
  if [[ ${#packages_conf[@]} -eq 0 ]]; then
    log_error "packages_conf is empty. Was load_packages_conf called?"
    exit 1
  fi

  local name scope target pkg_dir pkg_name stow_target

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
    # "macos/editors/nvim" becomes: -d "$repo_dir/macos/editors"  nvim
    pkg_dir="$(dirname "$name")"
    pkg_name="$(basename "$name")"

    [[ -n "$target" ]] && log_debug "Package '$name' has custom target: $stow_target"
    log_info "Stowing '$name' -> '$stow_target' (scope: $scope)"

    if [[ "$pkg_dir" == "." ]]; then
      # Top-level package: stow directly from repo root.
      run_cmd stow --no-folding -d "$repo_dir" -t "$stow_target" "$pkg_name"
    else
      # Nested package: shift the stow dir down to the parent folder.
      run_cmd stow --no-folding -d "$repo_dir/$pkg_dir" -t "$stow_target" "$pkg_name"
    fi
  done

  log_debug "Stowed all applicable packages from packages.conf"

  # Stow the private package last if it exists.
  # This directory is gitignored and holds secrets/personal configs.
  if [[ -d "$repo_dir/private" ]]; then
    log_debug "Found 'private' package directory"
    log_info "Stowing 'private' package..."
    run_cmd stow --no-folding -d "$repo_dir" -t "$HOME" private
  else
    log_debug "'private' package directory not found - skipping."
  fi

  log_success "Dotfiles symlinked successfully!"
}
