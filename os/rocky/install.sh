#!/usr/bin/env bash
# os/rocky/install.sh
#
# Purpose:
#   Rocky Linux-specific installer invoked by the root ./install.sh orchestrator.
#   This script intentionally only contains Rocky-specific tasks.
#
# Responsibilities:
#   - Install packages via dnf (using tracked package lists)
#   - Configure shell tooling for a headless VPS workflow
#   - Install Starship prompt
#   - Optionally set zsh as the default shell
#
# Not responsible for:
#   - Stow/symlinking dotfiles (handled in root install.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
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

SKIP_PACKAGES=false
BOOTSTRAP_PACKAGES_ONLY=false
PACKAGES_FILE="$SCRIPT_DIR/dnf-packages.txt"

usage() {
    cat << EOF
${BOLD}Usage:${RESET}
    ${GREEN}$(basename "$0")${RESET} ${BLUE}[options]${RESET}

${BOLD}Description:${RESET}
    Rocky Linux-specific dotfiles installation script for headless/server setups.

${BOLD}Options:${RESET}
$(print_common_flags_help)
    ${BLUE}--bootstrap-packages${RESET} Install only essential Rocky packages needed before stowing dotfiles
    ${BLUE}--skip-packages${RESET}      Skip package installation

${BOLD}Examples:${RESET}
    ${GREEN}./install.sh${RESET}
    ${GREEN}./install.sh${RESET} ${BLUE}--force${RESET}
    ${GREEN}./install.sh${RESET} ${BLUE}--dry-run --skip-packages${RESET}
EOF
}

parse_common_flags "$@"
if [[ "${REMAINING_ARGS+x}" ]]; then
    set -- "${REMAINING_ARGS[@]}"
else
    set --
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bootstrap-packages)
            BOOTSTRAP_PACKAGES_ONLY=true
            shift
            ;;
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

get_pretty_name() {
    local pretty_name
    pretty_name="$(get_os_release_field PRETTY_NAME 2>/dev/null || true)"

    if [[ -n "$pretty_name" ]]; then
        printf '%s' "$pretty_name"
    else
        printf '%s' "Rocky Linux"
    fi
}

validate_package_context() {
    require_rocky

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        log_error "Missing expected file: $PACKAGES_FILE"
        exit 1
    fi
}

validate_context() {
    validate_package_context
    log_debug "Context validated: script_dir=$SCRIPT_DIR repo_dir=$REPO_DIR"
}

print_banner() {
    print_box_banner " Rocky Linux Dotfiles Installation" "         clxrityy/dotfiles"
    printf '  %sDistribution:%s %s\n' "${BOLD:-}" "${RESET:-}" "$(get_pretty_name)"
    printf '  %sDotfiles:%s     %s\n' "${BOLD:-}" "${RESET:-}" "$SCRIPT_DIR"
    printf '  %sFlags:%s        force=%s, verbose=%s, dry-run=%s\n\n' "${BOLD:-}" "${RESET:-}" "$FORCE" "$VERBOSE" "$DRY_RUN"
}

read_packages_file() {
    local packages_file="$1"
    local line

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue
        printf '%s\n' "$line"
    done < "$packages_file"
}

install_essentials() {
    if [[ "$SKIP_PACKAGES" == true ]]; then
        log_info "Skipping essential tools (--skip-packages flag set)"
        return 0
    fi

    log_info "Installing essential tools (git, stow, zsh, curl)..."
    run_cmd_as_root dnf install -y git stow zsh curl
    log_success "Essential tools installed"
}

install_packages() {
    if [[ "$SKIP_PACKAGES" == true ]]; then
        log_info "Skipping package installation (--skip-packages flag set)"
        return 0
    fi

    local packages=()
    local package_name

    while IFS= read -r package_name; do
        packages+=("$package_name")
    done < <(read_packages_file "$PACKAGES_FILE")

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warning "No packages found in $PACKAGES_FILE"
        return 0
    fi

    log_info "Installing packages from dnf-packages.txt..."
    run_cmd_as_root dnf install -y "${packages[@]}"
    log_success "Packages installed"
}

setup_starship() {
    if command -v starship >/dev/null 2>&1; then
        log_info "Starship already installed"
        return 0
    fi

    log_info "Installing Starship prompt..."
    run_cmd sh -c "curl -sS https://starship.rs/install.sh | sh -s -- -y"
    log_success "Starship installed"
}

setup_zsh() {
    local current_shell
    current_shell="$(basename "${SHELL:-bash}")"

    if [[ "$current_shell" == "zsh" ]]; then
        log_info "Zsh is already the default shell"
        return 0
    fi

    if ! command -v chsh >/dev/null 2>&1; then
        log_warning "chsh is not available; skipping default shell change"
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

print_post_install() {
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║       Post-Installation Steps          ║${RESET}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${YELLOW}1.${RESET} Restart your terminal or run: ${GREEN}exec zsh${RESET}"
    echo ""
    echo -e "  ${YELLOW}2.${RESET} Customize Starship locally via: ${GREEN}~/.config/starship.local.toml${RESET}"
    echo ""
    echo -e "  ${YELLOW}3.${RESET} Extend ${GREEN}os/rocky/dnf-packages.txt${RESET} as this VPS gains more responsibilities"
    echo ""
}

main() {
    if [[ "$BOOTSTRAP_PACKAGES_ONLY" == true ]]; then
        validate_package_context
        log_info "Bootstrapping Rocky packages required before stowing dotfiles..."
        install_essentials
        log_success "Rocky package bootstrap complete"
        return 0
    fi

    validate_context
    print_banner
    confirm_or_exit "Proceed with installation?"

    log_info "Starting Rocky Linux installation..."

    install_essentials
    install_packages
    setup_starship
    setup_zsh

    log_success "Installation complete!"
    print_post_install
}

main "$@"
