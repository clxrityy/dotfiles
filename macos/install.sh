#!/usr/bin/env bash
# macos/install.sh
#
# Purpose:
#   macOS-specific installer invoked by the root ./install.sh orchestrator.
#   This script intentionally only contains macOS-specific tasks.
#
# Responsibilities:
#   - Homebrew install/update + Brewfile bundle
#   - Oh My Zsh + Powerlevel10k setup
#   - Apply macOS defaults from .macos
#
# Not responsible for:
#   - Stow/symlinking dotfiles (handled in root install.sh)
#
# References:
#   - Homebrew: https://brew.sh/
#   - Brewfile / brew bundle: https://github.com/Homebrew/homebrew-bundle
#   - Oh My Zsh: https://ohmyz.sh/
#   - Powerlevel10k: https://github.com/romkatv/powerlevel10k

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
source "$LIB_DIR/fs.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/banner.sh"

init_colors

# OS-specific flag.
SKIP_BREW=false

# Normalized arch key (arm64/x86_64/other) used for Apple Silicon Homebrew path.
ARCH="$(get_arch_key)"

# =====================================================
# Usage/help function
# =====================================================
usage() {
    cat << EOF
${BOLD}Usage:${RESET} 
    ${GREEN}$(basename "$0")${RESET} ${BLUE}[options]${RESET}

${BOLD}Description:${RESET}
    macOS-specific dotfiles installation script.

${BOLD}Options:${RESET}
$(print_common_flags_help)
    ${BLUE}--skip-brew${RESET}     Skip Homebrew installation/updates

${BOLD}Examples:${RESET}
    ${GREEN}./install.sh${RESET}  # Interactive installation
    ${GREEN}./install.sh${RESET} ${BLUE}--force${RESET}  # Force installation
    ${GREEN}./install.sh${RESET} ${BLUE}--dry-run${RESET}  # Simulate installation
EOF
}

# =====================================================
# Argument parsing
# =====================================================
# Parse common flags first, then parse macOS-specific flags from the remainder.
parse_common_flags "$@"
set -- "${REMAINING_ARGS[@]}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-brew)
            SKIP_BREW=true
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
    # Guard against accidentally running on non-macOS.
    require_macos

    # Verify expected files exist.
    if [[ ! -f "$SCRIPT_DIR/.macos" ]]; then
        log_error "Missing expected file: $SCRIPT_DIR/.macos"
        exit 1
    fi

    log_debug "Context validated: script_dir=$SCRIPT_DIR repo_dir=$REPO_DIR"
}

# =====================================================
# Startup banner & confirmation
# =====================================================
print_banner() {
    print_box_banner "    macOS Dotfiles Installation" "         clxrityy/dotfiles"
    printf '  %sArchitecture:%s %s\n' "${BOLD:-}" "${RESET:-}" "$ARCH"
    printf '  %sDotfiles:%s     %s\n' "${BOLD:-}" "${RESET:-}" "$SCRIPT_DIR"
    printf '  %sFlags:%s        force=%s, verbose=%s, dry-run=%s\n\n' "${BOLD:-}" "${RESET:-}" "$FORCE" "$VERBOSE" "$DRY_RUN"
}

# =====================================================
# Homebrew installation/update
# =====================================================
setup_homebrew() {
    if [[ "$SKIP_BREW" == true ]]; then
        log_info "Skipping Homebrew (--skip-brew flag set)"
        return 0
    fi

    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed, updating..."
        run_cmd brew update
        run_cmd brew upgrade
        log_success "Homebrew updated"
    else
        log_info "Installing Homebrew..."
        # Homebrew install script is the official bootstrap.
        # Ref: https://brew.sh/
        run_cmd /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ "$ARCH" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        log_success "Homebrew installed"
    fi
}

# =====================================================
# Oh My Zsh installation
# =====================================================
setup_ohmyzsh() {
    local omz_dir="${HOME}/.oh-my-zsh"

    if [[ -d "$omz_dir" ]]; then
        log_info "Oh My Zsh already installed"
        return 0
    fi

    log_info "Installing Oh My Zsh..."
    run_cmd sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log_success "Oh My Zsh installed"
}

# =====================================================
# Powerlevel10k installation
# =====================================================
setup_powerlevel10k() {
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

    # Ensure Oh My Zsh is installed first
    if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        log_warning "Oh My Zsh not found. Install it first."
        return 1
    fi

    # Install Powerlevel10k if not present
    if [[ ! -d "$p10k_dir" ]]; then
        log_info "Installing Powerlevel10k..."
        run_cmd git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        log_success "Powerlevel10k installed"
    else
        log_info "Powerlevel10k already installed"
    fi

    # Determine the actual zshrc file (resolve symlink if needed)
    local zshrc="$HOME/.zshrc"
    local zshrc_target="$zshrc"
    
    # If .zshrc is a symlink, get the actual file path
    if [[ -L "$zshrc" ]]; then
        # macOS' default `readlink` does not support `-f`, so use a portable
        # resolver. This ensures we edit the real file behind a symlink.
        zshrc_target="$(realpath_compat "$zshrc")"
        log_debug "Resolved .zshrc symlink to: $zshrc_target"
    fi

    if [[ -f "$zshrc_target" ]]; then
        # Check if ZSH_THEME is already set to powerlevel10k
        if grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$zshrc_target"; then
            log_debug "Powerlevel10k theme already configured in .zshrc"
        else
            log_info "Configuring Powerlevel10k theme in .zshrc..."
            # Replace existing ZSH_THEME line or add if not present
            if grep -q '^ZSH_THEME=' "$zshrc_target"; then
                if [[ "$DRY_RUN" == true ]]; then
                    log_info "[DRY-RUN] Would update ZSH_THEME in $zshrc_target"
                else
                    # Use a temp file approach instead of sed -i for symlink compatibility
                    local temp_file
                    temp_file=$(mktemp)
                    sed 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc_target" > "$temp_file"
                    run_cmd mv "$temp_file" "$zshrc_target"
                fi
            else
                append_lines "$zshrc_target" 'ZSH_THEME="powerlevel10k/powerlevel10k"'
            fi
            log_success "Powerlevel10k theme configured"
        fi

        # Add p10k sourcing if not present
        if ! grep -q 'source ~/.p10k.zsh' "$zshrc_target" && ! grep -q '\[\[ ! -f ~/.p10k.zsh \]\]' "$zshrc_target"; then
            log_info "Adding Powerlevel10k sourcing to .zshrc..."
            append_lines "$zshrc_target" "" "# To customize prompt, run \`p10k configure\` or edit ~/.p10k.zsh." "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh"
            log_success "Powerlevel10k sourcing added"
        fi

        # Add instant prompt if not present (should be near top of .zshrc)
        if ! grep -q 'p10k-instant-prompt' "$zshrc_target"; then
            log_info "Adding Powerlevel10k instant prompt to .zshrc..."
            local instant_prompt='# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
'
            # Prepend instant prompt to .zshrc
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY-RUN] Would prepend instant prompt to .zshrc"
            else
                local temp_file
                temp_file=$(mktemp)
                echo "$instant_prompt" > "$temp_file"
                cat "$zshrc_target" >> "$temp_file"
                run_cmd mv "$temp_file" "$zshrc_target"
            fi
            log_success "Powerlevel10k instant prompt added"
        fi
    fi

    # Copy default p10k config if dotfiles has one and ~/.p10k.zsh doesn't exist
    local dotfiles_p10k="$SCRIPT_DIR/.p10k.zsh"
    local home_p10k="$HOME/.p10k.zsh"
    
    if [[ -f "$dotfiles_p10k" && ! -f "$home_p10k" ]]; then
        log_info "Copying Powerlevel10k configuration..."
        run_cmd cp "$dotfiles_p10k" "$home_p10k"
        log_success "Powerlevel10k configuration copied"
    elif [[ ! -f "$home_p10k" ]]; then
        log_warning "No p10k configuration found. Run 'p10k configure' after restarting your shell."
    fi
}

# =====================================================
# macOS system defaults
# =====================================================
setup_macos_defaults() {
    local macos_script="$SCRIPT_DIR/.macos"

    if [[ ! -f "$macos_script" ]]; then
        log_warning "macOS defaults script not found: $macos_script"
        return 1
    fi

    if [[ "$FORCE" != true ]]; then
        log_warning "Applying macOS defaults will change system settings and may require sudo."
        read -p "Apply macOS defaults? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping macOS defaults"
            return 0
        fi
    fi

    log_info "Applying macOS system defaults..."
    run_cmd chmod +x "$macos_script"
    run_cmd bash "$macos_script"
    log_success "macOS defaults applied"
    log_warning "Some changes may require a logout/restart to take effect."
}

# =====================================================
# Install packages from Brewfile
# =====================================================
install_packages() {
    if [[ "$SKIP_BREW" == true ]]; then
        log_info "Skipping package installation (--skip-brew flag set)"
        return 0
    fi

    local brewfile="$SCRIPT_DIR/Brewfile"

    if [[ ! -f "$brewfile" ]]; then
        log_warning "Brewfile not found: $brewfile"
        return 0
    fi

    log_info "Installing packages from Brewfile..."
    run_cmd brew bundle --file="$brewfile"
    log_success "Packages installed from Brewfile"
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
    
    if [[ ! -f "$HOME/.p10k.zsh" ]]; then
        echo -e "  ${YELLOW}2.${RESET} Configure Powerlevel10k: ${GREEN}p10k configure${RESET}"
        echo ""
    fi
    
    echo -e "  ${BLUE}Tip:${RESET} If fonts look broken, install a Nerd Font:"
    echo -e "       ${GREEN}brew install --cask font-meslo-lg-nerd-font${RESET}"
    echo ""
}

# =====================================================
# Main script execution
# =====================================================
main() {
    validate_context
    print_banner
    confirm_or_exit "Proceed with installation?"

    log_info "Starting macOS installation..."

    setup_homebrew
    # symlink_dotfiles
    setup_ohmyzsh
    setup_powerlevel10k
    setup_macos_defaults
    install_packages

    log_success "Installation complete!"
    print_post_install
}

# Execute main function
main "$@"