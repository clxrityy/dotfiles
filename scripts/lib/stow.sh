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
  local packages_conf="$repo_dir/packages.conf"

  # DEBUG LOGGING
  log_debug "Stow repo directory: $repo_dir"
  log_debug "Operating system key: $os_key"
  log_debug "Packages configuration file: $packages_conf"

  # Validate the manifest exists before proceeding.
  if [[ ! -f "$packages_conf" ]]; then
    log_error "packages.conf not found at: $packages_conf"
    exit 1
  fi

  # Read through the packages.conf file line by line.
  local name scope
  while IFS='=' read -r name scope; do
    # Strip inline comments and surrounding whitespace from both fields.
    name="${name%%#*}" # Remove comments
    name="${name// /}" # Trim whitespace
    scope="${scope%%#*}" # Remove comments
    scope="${scope// /}" # Trim whitespace

    # Skip blank lines and pure comment lines.
    [[ -z "$name" || -z "$scope" ]] && continue

    # Stow if the package targets all systems, or matches the current OS.
    if [[ "$scope" == "all" || "$scope" == "$os_key" ]]; then
      log_debug "Scope match for package '$name' with scope '$scope'"
      if [[ -d "$repo_dir/$name" ]]; then
        log_info "Stowing '$name' package... (scope: $scope)"
        run_cmd stow -d "$repo_dir" -t "$HOME" "$name"
      else
        log_debug "Package directory not found for: $name"
        log_warning "Package '$name' listed in packages.conf but directory not found - skipping."
      fi
    fi
  done < "$packages_conf"
  log_debug "Stowed all applicable packages from packages.conf"

  # Stow the private package last if it exists.
  # This directory is gitignored and holds secrets/personal configs.
  if [[ -d "$repo_dir/private" ]]; then
    log_debug "Found 'private' package directory"
    log_info "Stowing 'private' package..."
    run_cmd stow -d "$repo_dir" -t "$HOME" private
  else
    log_debug "'private' package directory not found - skipping."
  fi

  log_success "Dotfiles symlinked successfully!"
}
