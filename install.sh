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
# Main script execution
# =====================================================
main() {
    validate_context
    print_banner
    confirm_proceed

    log_info "Starting installation..."

    # ---- TODOS
    # - User preferences
    # - Homebrew installation/updates (if not skipped)
    # - Symlink dotfiles (stow)
    # - Package installation(s)
    # - Oh My Zsh setup
    # - powkerlevel10k
    # - macOS settings (or system defaults)

    log_success "Installation complete!"
}

# Execute main function
main "$@"