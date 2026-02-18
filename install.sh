#!/usr/bin/env bash
#
# install.sh - Dotfiles Installation Orchestrator
# Detects OS and delegates to environment-specific installers
# =====================================================

set -euo pipefail

# =====================================================
# Script directory resolution
# =====================================================
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =====================================================
# Shared libraries
# =====================================================
# Purpose:
#   Keep install scripts DRY by sourcing shared helpers for:
#   - colors/logging
#   - flag parsing
#   - dry-run command execution
#   - OS detection
#   - stow orchestration

LIB_DIR="$REPO_DIR/scripts/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/colors.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/log.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/args.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/run.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/os.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/stow.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/banner.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/prompt.sh"

init_colors

usage() {
  cat << EOF
${BOLD}Usage:${RESET}
  ${GREEN}./install.sh${RESET} ${BLUE}[options]${RESET}

${BOLD}Description:${RESET}
  Root dotfiles installer. Detects OS, runs GNU Stow, then delegates to the
  OS-specific installer under ${BLUE}./macos${RESET} or ${BLUE}./fedora${RESET}.

${BOLD}Options:${RESET}
$(print_common_flags_help)

${BOLD}Notes:${RESET}
  - OS-specific flags are supported and passed through.
  - For OS-specific help:
      ${GREEN}./macos/install.sh --help${RESET}
      ${GREEN}./fedora/install.sh --help${RESET}
EOF
}

# ...existing code...

# =====================================================
# VS Code settings symlink
# =====================================================
# Stow can't handle "Application Support" (spaces in path),
# so we symlink the settings.json directly.
link_vscode_settings() {
    local src="$REPO_DIR/macos/vscode/settings.json"
    local dest_dir="$HOME/Library/Application Support/Code/User"
    local dest="$dest_dir/settings.json"

    if [[ ! -f "$src" ]]; then
        log_warn "vscode/settings.json not found in repo — skipping"
        return
    fi

    # Ensure target directory exists (VS Code may not have been opened yet)
    run_cmd mkdir -p "$dest_dir"

    if [[ -L "$dest" ]]; then
        log_info "VS Code settings symlink already exists"
        return
    fi

    # Back up existing settings if present
    if [[ -f "$dest" ]]; then
        log_info "Backing up existing VS Code settings.json"
        run_cmd mv "$dest" "$dest.bak.$(date +%s)"
    fi

    run_cmd ln -s "$src" "$dest"
    log_info "Symlinked VS Code settings.json"
}

# =====================================================
# Main execution
# =====================================================
main() {
    parse_common_flags "$@"

    if [[ "$SHOW_HELP" == "true" ]]; then
        usage
        exit 0
    fi

    local os
    os="$(detect_os_key)"

    print_box_banner "       Dotfiles Installation" "         clxrityy/dotfiles"
    log_info "Detected OS: $os"
    log_debug "Repo: $REPO_DIR"
    log_debug "Flags: force=$FORCE, verbose=$VERBOSE, dry-run=$DRY_RUN"

    # Stow dotfiles first (common to all OS).
    log_info "Symlinking dotfiles using GNU Stow..."
    ensure_stow_installed "$os"
    backup_conflicting_dotfiles
    stow_packages_for_os "$REPO_DIR" "$os"

    # Delegate to OS-specific installer (pass through any remaining args).
    # Important:
    #   We pass common flags through explicitly so running `install.sh --dry-run`
    #   also runs OS installers in dry-run mode.
    local -a os_common_args=()
    if [[ "$FORCE" == "true" ]]; then os_common_args+=("--force"); fi
    if [[ "$VERBOSE" == "true" ]]; then os_common_args+=("--verbose"); fi
    if [[ "$DRY_RUN" == "true" ]]; then os_common_args+=("--dry-run"); fi

    case "$os" in
        macos)
            log_info "Running macOS-specific installation..."
            link_vscode_settings
            bash "$REPO_DIR/macos/install.sh" \
              "${os_common_args[@]+"${os_common_args[@]}"}" \
              "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
            ;;
        fedora)
            log_info "Running Fedora-specific installation..."
            bash "$REPO_DIR/fedora/install.sh" \
              "${os_common_args[@]+"${os_common_args[@]}"}" \
              "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
            ;;
        *)
            log_error "Unsupported OS: $os (${OSTYPE:-unknown})"
            log_error "Supported: macOS, Fedora"
            exit 1
            ;;
    esac
}

main "$@"
