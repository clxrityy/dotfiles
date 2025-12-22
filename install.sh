#!/usr/bin/env bash
# 
# install.sh - Dotfiles installation script
# Usage: ./install.sh [options]
# 
# Options:
#   -h, --help      Show this help message
#   -f, --force     Force overwrite existing files
#   -v, --verbose   Enable verbose output
#   --dry-run       Simulate installation without making changes
#   --skip-brew     Skip Homebrew installation/updates
# =====================================================

set -euo pipefail # Enable strict error handling

# =====================================================
# Script directory resolution
# =====================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Get the absolute path of the script directory

# =====================================================
# Color constants (disabled if not a terminal)
# =====================================================
if [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
fi

# =====================================================
# Logging functions
# =====================================================
log_info() { echo -e "${BLUE}[INFO]${RESET} $*"; } # General information
log_success() { echo -e "${GREEN}[✓]${RESET} $*"; } # Success messages
log_warning() { echo -e "${YELLOW}[!]${RESET} $*"; } # Warnings
log_error() { echo -e "${RED}[✗]${RESET} $*"; } # Error messages
log_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BOLD}[DEBUG]${RESET} $*"
    fi
} # Debug messages (verbose only)

# =====================================================
# Default flag values
# =====================================================
FORCE=false
VERBOSE=false
DRY_RUN=false
SKIP_BREW=false

# =====================================================
# Usage/help function
# =====================================================
usage() {
    cat << EOF
${BOLD}Usage:${RESET} 
    ${GREEN}$(basename "$0")${RESET} ${BLUE}[options]${RESET}

${BOLD}Options:${RESET}
    ${BLUE}-h, --help${RESET}      Show this help message
    ${BLUE}-f, --force${RESET}     Force overwrite existing files
    ${BLUE}-v, --verbose${RESET}   Enable verbose output
    ${BLUE}--dry-run${RESET}       Simulate installation without making changes
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
while [[ $# -gt 0 ]]; do
    case $1 in
        # Help option
        -h|--help)
            usage
            exit 0
            ;;
        # Force option
        -f|--force)
            FORCE=true
            shift
            ;;
        # Verbose option
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        # Dry-run option
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        # Skip Homebrew option
        --skip-brew)
            SKIP_BREW=true
            shift
            ;;
        # End of options
        --)
            shift
            break
            ;;
        # Unknown option
        -*)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        # No more options
        *)
            break
            ;;
    esac
done

# =====================================================
# OS detection
# =====================================================
detect_os() {
    case "$OSTYPE" in
        darwin*)  echo "macos" ;;
        linux*)   echo "linux" ;;
        msys*|cygwin*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
} # Detect operating system

detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        arm64|aarch64) echo "arm64" ;;
        x86_64)        echo "x86_64" ;;
        *)             echo "$arch" ;;
    esac
} # Detect system architecture

OS="$(detect_os)"
ARCH="$(detect_arch)"

# =====================================================
# Execution context validation
# =====================================================
validate_context() {
    # Check if in the dotfiles directory
    if [[ ! -f "$SCRIPT_DIR/.zshrc" ]] || [[ ! -f "$SCRIPT_DIR/.macos" ]]; then
        log_error "Missing expected dotfiles. Are you running from the correct directory?"
        log_error "Expected: $SCRIPT_DIR"
        exit 1
    fi

    # Check for unsupported OS
    if [[ "$OS" == "unknown" ]]; then
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi

    log_debug "Context validated: $SCRIPT_DIR"
} # Validate execution context

# =====================================================
# Startup banner & confirmation
# =====================================================
print_banner() {
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║       Dotfiles Installation            ║${RESET}"
    echo -e "${BOLD}║         clxrityy/dotfiles              ║${RESET}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD}OS:${RESET}          $OS ($ARCH)"
    echo -e "  ${BOLD}Dotfiles:${RESET}    $SCRIPT_DIR"
    echo -e "  ${BOLD}Flags:${RESET}       force=$FORCE, verbose=$VERBOSE, dry-run=$DRY_RUN"
    echo ""
} # Print startup banner

confirm_proceed() {
    if [[ "$FORCE" == true ]]; then
        log_info "Force flag set; proceeding without confirmation."
        return 0
    fi

    read -p "Proceed with installation? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation aborted by user."
        exit 0
    fi
} # Confirm to proceed with installation

# =====================================================
# Run command (with dry-run support)
# =====================================================
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would execute: $*"
    else
        log_debug "Executing: $*"
        eval "$@"
    fi
}

# =====================================================
# Homebrew installation/update
# =====================================================
setup_homebrew() {
    if [[ "$SKIP_BREW" == true ]]; then
        log_info "Skipping Homebrew (--skip-brew flag set)"
        return 0
    fi

    if [[ "$OS" != "macos" && "$OS" != "linux" ]]; then
        log_warning "Homebrew is only supported on macOS and Linux"
        return 0
    fi

    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed, updating..."
        run_cmd "brew update"
        run_cmd "brew upgrade"
        log_success "Homebrew updated"
    else
        log_info "Installing Homebrew..."
        run_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ "$OS" == "macos" && "$ARCH" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        log_success "Homebrew installed"
    fi
}

# ==========================================
# Symlink dotfiles using GNU Stow
# ==========================================
symlink_dotfiles() {
    log_info "Symlinking dotfiles using GNU Stow..."
    local dotfiles_dir="$SCRIPT_DIR"
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        log_error "Dotfiles directory not found: $dotfiles_dir"
        exit 1
    fi
    
    # check if stow is installed
    if ! command -v stow &>/dev/null; then
        log_error "GNU Stow is not installed. Please install it and rerun the script."
        exit 1
    fi
    
    log_debug "Stowing from $dotfiles_dir to $HOME"
    
    # Backup conflicting files before stowing
    local backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    local files_to_check=(".zshrc" ".zprofile" ".bash_profile" ".editorconfig" ".gitconfig")
    local needs_backup=false
    
    for file in "${files_to_check[@]}"; do
        # Check if file exists and is NOT a symlink
        if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
            needs_backup=true
            break
        fi
    done
    
    if [[ "$needs_backup" == true ]]; then
        log_info "Backing up existing dotfiles to $backup_dir"
        run_cmd "mkdir -p '$backup_dir'"
        
        for file in "${files_to_check[@]}"; do
            if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
                log_debug "Backing up $file"
                run_cmd "mv '$HOME/$file' '$backup_dir/'"
            fi
        done
        log_success "Existing dotfiles backed up"
    fi
    
    # Run stow from the dotfiles directory, targeting home
    run_cmd "stow -d '$dotfiles_dir' -t '$HOME' ."
    
    log_success "Dotfiles symlinked"
}

# =====================================================
# Oh My Zsh installation
# =====================================================
setup_ohmyzsh() {
    if [[ "$OS" != "macos" ]]; then
        log_info "Skipping Oh My Zsh (macOS only)"
        return 0
    fi

    local omz_dir="${HOME}/.oh-my-zsh"

    if [[ -d "$omz_dir" ]]; then
        log_info "Oh My Zsh already installed"
        return 0
    fi

    log_info "Installing Oh My Zsh..."
    run_cmd 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    log_success "Oh My Zsh installed"
}

# =====================================================
# Powerlevel10k installation
# =====================================================
setup_powerlevel10k() {
    if [[ "$OS" != "macos" ]]; then
        log_info "Skipping Powerlevel10k (macOS only)"
        return 0
    fi

    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

    if [[ -d "$p10k_dir" ]]; then
        log_info "Powerlevel10k already installed"
        return 0
    fi

    # Ensure Oh My Zsh is installed first
    if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        log_warning "Oh My Zsh not found. Install it first."
        return 1
    fi

    log_info "Installing Powerlevel10k..."
    run_cmd "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $p10k_dir"
    log_success "Powerlevel10k installed"
    log_info "Set ZSH_THEME=\"powerlevel10k/powerlevel10k\" in your .zshrc"
}

# =====================================================
# macOS system defaults
# =====================================================
setup_macos_defaults() {
    if [[ "$OS" != "macos" ]]; then
        log_info "Skipping macOS defaults (macOS only)"
        return 0
    fi

    local macos_script="$SCRIPT_DIR/.macos"

    if [[ ! -f "$macos_script" ]]; then
        log_warning "macOS defaults script not found: $macos_script"
        return 1
    fi

    if [[ "$FORCE" != true ]]; then
        log_warning "Applying macOS defaults will change system settings and require sudo."
        read -p "Apply macOS defaults? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping macOS defaults"
            return 0
        fi
    fi

    log_info "Applying macOS system defaults..."
    run_cmd "chmod +x '$macos_script'"
    run_cmd "bash '$macos_script'"
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
    run_cmd "brew bundle --file='$brewfile'"
    log_success "Packages installed from Brewfile"
}

# =====================================================
# Main script execution
# =====================================================
main() {
    validate_context
    print_banner
    confirm_proceed

    log_info "Starting installation..."

    # ---- TODOS
    # - ~~Homebrew installation/updates (if not skipped)~~
    setup_homebrew
    # - ~~Symlink dotfiles (stow)~~
    symlink_dotfiles
    # - Package installation(s)
    # - ~~Oh My Zsh setup~~
    setup_ohmyzsh
    # - ~~Powerlevel10k setup~~
    setup_powerlevel10k
    # - ~~macOS settings (or system defaults)~~
    setup_macos_defaults

    # - ~~Install packages from Brewfile~~
    install_packages

    log_success "Installation complete!"
}

# Execute main function
main "$@"