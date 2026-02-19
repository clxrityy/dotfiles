#!/usr/bin/env bash
# fedora/install.sh
#
# Purpose:
#   Fedora-specific installer invoked by the root ./install.sh orchestrator.
#   This script intentionally only contains Fedora-specific tasks.
#
# Responsibilities:
#   - Install packages via dnf (using packages.txt)
#   - Install Starship prompt
#   - Optionally set zsh as default shell
#   - Apply Fedora defaults from .fedora
#
# Not responsible for:
#   - Stow/symlinking dotfiles (handled in root install.sh)
#
# References:
#   - DNF: https://dnf.readthedocs.io/
#   - Starship: https://starship.rs/

set -euo pipefail

# Resolve directories.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Shared libraries (colors/logging/args/run/prompt/etc.).
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
source "$LIB_DIR/prompt.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/os.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/banner.sh"

init_colors

# Fedora-specific flag.
SKIP_PACKAGES=false

# =====================================================
# Usage/help function
# =====================================================
usage() {
    cat << EOF
${BOLD}Usage:${RESET}
    ${GREEN}$(basename "$0")${RESET} ${BLUE}[options]${RESET}

${BOLD}Description:${RESET}
    Fedora-specific dotfiles installation script.

${BOLD}Options:${RESET}
$(print_common_flags_help)
    ${BLUE}--skip-packages${RESET}    Skip package installation

${BOLD}Examples:${RESET}
    ${GREEN}./install.sh${RESET}  # Interactive installation
    ${GREEN}./install.sh${RESET} ${BLUE}--force${RESET}  # Force installation
    ${GREEN}./install.sh${RESET} ${BLUE}--dry-run${RESET}  # Simulate installation
EOF
}

# =====================================================
# Argument parsing
# =====================================================
# Parse common flags first, then parse Fedora-specific flags from the remainder.
parse_common_flags "$@"
set -- "${REMAINING_ARGS[@]}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-packages)
            SKIP_PACKAGES=true
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [[ "$SHOW_HELP" == "true" ]]; then
    usage
    exit 0
fi

# =====================================================
# Execution context validation
# =====================================================
validate_context() {
    require_fedora

    if [[ ! -f "$SCRIPT_DIR/.fedora" ]]; then
        log_error "Missing expected file: $SCRIPT_DIR/.fedora"
        exit 1
    fi

    log_debug "Context validated: script_dir=$SCRIPT_DIR repo_dir=$REPO_DIR"
}

# =====================================================
# Startup banner & confirmation
# =====================================================
print_banner() {
    print_box_banner "   Fedora Dotfiles Installation" "         clxrityy/dotfiles"
    printf '  %sDistribution:%s %s\n' "${BOLD:-}" "${RESET:-}" "$(cat /etc/fedora-release)"
    printf '  %sDotfiles:%s     %s\n' "${BOLD:-}" "${RESET:-}" "$SCRIPT_DIR"
    printf '  %sFlags:%s        force=%s, verbose=%s, dry-run=%s\n\n' "${BOLD:-}" "${RESET:-}" "$FORCE" "$VERBOSE" "$DRY_RUN"
}

# =====================================================
# Install essential tools
# =====================================================
install_essentials() {
    if [[ "$SKIP_PACKAGES" == true ]]; then
        log_info "Skipping essential tools (--skip-packages flag set)"
        return 0
    fi

    log_info "Installing essential tools (git, stow, zsh)..."
    run_cmd sudo dnf install -y git stow zsh util-linux-user
    log_success "Essential tools installed"
}

# =====================================================
# Install packages from packages.txt
# =====================================================
install_packages() {
    if [[ "$SKIP_PACKAGES" == true ]]; then
        log_info "Skipping package installation (--skip-packages flag set)"
        return 0
    fi

    local packages_file="$SCRIPT_DIR/dnf-packages.txt"

    if [[ ! -f "$packages_file" ]]; then
        log_warning "dnf-packages.txt not found: $packages_file"
        return 0
    fi

    log_info "Installing packages from dnf-packages.txt..."

    # Read packages from file, ignoring comments and empty lines
    local packages=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]] && continue
        packages+=("$line")
    done < "$packages_file"

    if [[ ${#packages[@]} -gt 0 ]]; then
        # Pass packages as argv tokens (no eval). This keeps quoting safe.
        run_cmd sudo dnf install -y "${packages[@]}"
        log_success "Packages installed"
    else
        log_warning "No packages found in dnf-packages.txt"
    fi
}

# =====================================================
# Install Starship prompt
# =====================================================
setup_starship() {
    if command -v starship &>/dev/null; then
        log_info "Starship already installed"
        return 0
    fi

    log_info "Installing Starship prompt..."
    # Official Starship installer.
    # Ref: https://starship.rs/
    run_cmd sh -c "curl -sS https://starship.rs/install.sh | sh -s -- -y"
    log_success "Starship installed"
}

# =====================================================
# Set Zsh as default shell
# =====================================================
setup_zsh() {
    local current_shell
    current_shell="$(basename "$SHELL")"

    if [[ "$current_shell" == "zsh" ]]; then
        log_info "Zsh is already the default shell"
        return 0
    fi

    log_info "Setting Zsh as default shell..."

    if [[ "$FORCE" != true ]]; then
        log_warning "This will change your default shell to Zsh."
        if ! confirm_yes_no "Proceed?"; then
            log_info "Skipping Zsh setup"
            return 0
        fi
    fi

    run_cmd chsh -s "$(command -v zsh)"
    log_success "Zsh set as default shell"
    log_warning "Log out and back in for the change to take effect"
}

# =====================================================
# Fedora system configuration
# =====================================================
setup_fedora_defaults() {
    local fedora_script="$SCRIPT_DIR/.fedora"

    if [[ ! -f "$fedora_script" ]]; then
        log_warning "Fedora defaults script not found: $fedora_script"
        return 1
    fi

    if [[ "$FORCE" != true ]]; then
        log_warning "Applying Fedora defaults will change system settings and require sudo."
        read -p "Apply Fedora defaults? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping Fedora defaults"
            return 0
        fi
    fi

    log_info "Applying Fedora system defaults..."
    run_cmd chmod +x "$fedora_script"
    run_cmd bash "$fedora_script"
    log_success "Fedora defaults applied"
}

# =====================================================
# Final setup instructions
# =====================================================
print_post_install() {
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║       Post-Installation Steps          ║${RESET}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${YELLOW}1.${RESET} Restart your terminal or run: ${GREEN}exec zsh${RESET}"
    echo ""
    echo -e "  ${YELLOW}2.${RESET} Configure Starship (optional): ${GREEN}~/.config/starship.toml${RESET}"
    echo ""
    echo -e "  ${BLUE}Tip:${RESET} Install additional fonts for better terminal experience:"
    echo -e "       ${GREEN}sudo dnf install -y jetbrains-mono-fonts-all${RESET}"
    echo ""
}

# =====================================================
# Main script execution
# =====================================================
main() {
    validate_context
    print_banner
    confirm_or_exit "Proceed with installation?"

    log_info "Starting Fedora installation..."

    install_essentials
    install_packages
    setup_starship
    setup_zsh
    setup_fedora_defaults

    log_success "Installation complete!"
    print_post_install
}

# Execute main function
main "$@"
