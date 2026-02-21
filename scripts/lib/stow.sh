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

stow_packages_for_os() {
  # Arguments:
  #   1: repo_dir (stow -d)
  #   2: os_key (macos|fedora|...)
  local repo_dir="$1"
  local os_key="$2"

  log_info "Stowing common configurations..."
  run_cmd stow -d "$repo_dir" -t "$HOME" common

  log_info "Stowing shell configurations..."
  run_cmd stow -d "$repo_dir" -t "$HOME" shell

  case "$os_key" in
    macos)
      log_info "Stowing macOS configurations..."
      run_cmd stow -d "$repo_dir" -t "$HOME" macos
      ;;
    fedora)
      log_info "Stowing Fedora configurations..."
      run_cmd stow -d "$repo_dir" -t "$HOME" fedora
      ;;
    *)
      log_warning "No OS-specific stow package for: $os_key"
      ;;
  esac

  log_success "Dotfiles symlinked successfully"
}
