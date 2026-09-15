#!/usr/bin/env bash
# os/debian/install.sh
#
# Purpose:
#   Debian-specific installer invoked by the root ./install.sh orchestrator.
#   This script intentionally only contains Debian-specific tasks.
#
# Responsibilities:
#   - Install packages via apt (using tracked package lists)
#   - Configure a lean Zsh experience
#   - Install a custom system MOTD
#   - Apply Debian desktop defaults (GNOME + auto-tiling best effort)
#
# Not responsible for:
#   - Stow/symlinking dotfiles (handled in root install.sh)

set -euo pipefail

# Resolve directories.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Shared libraries.
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
SKIP_DESKTOP=false
SKIP_MOTD=false
SKIP_DEFAULTS=false
BOOTSTRAP_PACKAGES_ONLY=false

APT_UPDATED=false
APT_BASE_PACKAGES_FILE="$SCRIPT_DIR/apt-packages.txt"
APT_DESKTOP_PACKAGES_FILE="$SCRIPT_DIR/gnome-packages.txt"
GNOME_DEFAULTS_SCRIPT="$SCRIPT_DIR/.local/share/dotfiles/debian/apply-gnome-defaults.sh"
MOTD_SCRIPT_SOURCE="$SCRIPT_DIR/.local/share/dotfiles/motd/dotfiles-debian-motd"
MOTD_DEFAULTS_EXAMPLE="$SCRIPT_DIR/.local/share/dotfiles/motd/dotfiles-motd.conf.example"

usage() {
	cat << EOF
${BOLD}Usage:${RESET}
	${GREEN}$(basename "$0")${RESET} ${BLUE}[options]${RESET}

${BOLD}Description:${RESET}
	Debian-specific dotfiles installation script.

${BOLD}Options:${RESET}
$(print_common_flags_help)
	${BLUE}--bootstrap-packages${RESET} Install only essential Debian packages needed before stowing dotfiles
	${BLUE}--skip-packages${RESET}   Skip apt package installation
	${BLUE}--skip-desktop${RESET}    Skip GNOME desktop packages and defaults
	${BLUE}--skip-motd${RESET}       Skip custom MOTD installation
	${BLUE}--skip-defaults${RESET}   Skip Debian desktop/system defaults

${BOLD}Examples:${RESET}
	${GREEN}./install.sh${RESET}
	${GREEN}./install.sh${RESET} ${BLUE}--force${RESET}
	${GREEN}./install.sh${RESET} ${BLUE}--dry-run --skip-desktop${RESET}
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
		--skip-desktop)
			SKIP_DESKTOP=true
			shift
			;;
		--skip-motd)
			SKIP_MOTD=true
			shift
			;;
		--skip-defaults)
			SKIP_DEFAULTS=true
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
	if [[ -r /etc/os-release ]]; then
		awk -F= '/^PRETTY_NAME=/{gsub(/"/, "", $2); print $2}' /etc/os-release
	else
		printf '%s' "Debian"
	fi
}

validate_package_context() {
	require_debian

	if [[ ! -f "$APT_BASE_PACKAGES_FILE" ]]; then
		log_error "Missing expected file: $APT_BASE_PACKAGES_FILE"
		exit 1
	fi
}

validate_context() {
	validate_package_context

	if [[ ! -f "$APT_DESKTOP_PACKAGES_FILE" ]]; then
		log_error "Missing expected file: $APT_DESKTOP_PACKAGES_FILE"
		exit 1
	fi

	if [[ ! -f "$GNOME_DEFAULTS_SCRIPT" ]]; then
		log_error "Missing expected file: $GNOME_DEFAULTS_SCRIPT"
		exit 1
	fi

	if [[ ! -f "$MOTD_SCRIPT_SOURCE" ]]; then
		log_error "Missing expected file: $MOTD_SCRIPT_SOURCE"
		exit 1
	fi

	if [[ ! -f "$MOTD_DEFAULTS_EXAMPLE" ]]; then
		log_error "Missing expected file: $MOTD_DEFAULTS_EXAMPLE"
		exit 1
	fi

	log_debug "Context validated: script_dir=$SCRIPT_DIR repo_dir=$REPO_DIR"
}

print_banner() {
	print_box_banner "   Debian Dotfiles Installation" "         clxrityy/dotfiles"
	printf '  %sDistribution:%s %s\n' "${BOLD:-}" "${RESET:-}" "$(get_pretty_name)"
	printf '  %sDotfiles:%s     %s\n' "${BOLD:-}" "${RESET:-}" "$SCRIPT_DIR"
	printf '  %sFlags:%s        force=%s, verbose=%s, dry-run=%s\n\n' "${BOLD:-}" "${RESET:-}" "$FORCE" "$VERBOSE" "$DRY_RUN"
}

apt_update_once() {
	if [[ "$APT_UPDATED" == "true" ]]; then
		return 0
	fi

	log_info "Updating apt package index..."
	run_cmd_as_root apt update
	APT_UPDATED=true
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

install_packages_from_file() {
	local packages_file="$1"
	local label="$2"
	local packages=()
	local package_name

	while IFS= read -r package_name; do
		packages+=("$package_name")
	done < <(read_packages_file "$packages_file")

	if [[ ${#packages[@]} -eq 0 ]]; then
		log_warning "No packages found in $packages_file"
		return 0
	fi

	apt_update_once
	log_info "Installing $label..."
	run_cmd_as_root apt install -y "${packages[@]}"
	log_success "$label installed"
}

ensure_github_cli_repository() {
	local keyring_path="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
	local source_list_path="/etc/apt/sources.list.d/github-cli.list"
	local repo_line
	local tmp_file

	repo_line="deb [arch=$(dpkg --print-architecture) signed-by=$keyring_path] https://cli.github.com/packages stable main"

	need_cmd curl
	need_cmd dpkg

	log_info "Configuring the GitHub CLI apt repository..."
	run_cmd_as_root install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d

	tmp_file="$(mktemp)"
	run_cmd curl -fsSL -o "$tmp_file" https://cli.github.com/packages/githubcli-archive-keyring.gpg
	run_cmd_as_root install -m 0644 "$tmp_file" "$keyring_path"
	printf '%s\n' "$repo_line" > "$tmp_file"
	run_cmd_as_root install -m 0644 "$tmp_file" "$source_list_path"
	rm -f "$tmp_file"

	APT_UPDATED=false
	apt_update_once
}

install_github_cli() {
	if [[ "$SKIP_PACKAGES" == true ]]; then
		log_info "Skipping GitHub CLI installation (--skip-packages flag set)"
		return 0
	fi

	if command -v gh >/dev/null 2>&1; then
		log_info "GitHub CLI is already installed"
		return 0
	fi

	apt_update_once

	if apt-cache show gh >/dev/null 2>&1; then
		log_info "Installing GitHub CLI from the configured apt repositories..."
		run_cmd_as_root apt install -y gh
		log_success "GitHub CLI installed"
		return 0
	fi

	log_warning "GitHub CLI is not available in the current apt sources; adding the official GitHub CLI repository"
	ensure_github_cli_repository

	if [[ "$DRY_RUN" == "true" ]]; then
		log_info "Dry-run mode: skipping post-repository GitHub CLI availability check"
		log_info "Dry-run mode: assuming GitHub CLI would be installable after repository configuration"
		run_cmd_as_root apt install -y gh
		log_success "GitHub CLI install simulated"
		return 0
	fi

	if ! apt-cache show gh >/dev/null 2>&1; then
		log_error "GitHub CLI is still unavailable after configuring its apt repository"
		exit 1
	fi

	log_info "Installing GitHub CLI from the official GitHub apt repository..."
	run_cmd_as_root apt install -y gh
	log_success "GitHub CLI installed"
}

install_first_available_package() {
	local label="$1"
	shift

	local package_name
	for package_name in "$@"; do
		if apt-cache show "$package_name" >/dev/null 2>&1; then
			log_info "Installing $label via package: $package_name"
			run_cmd_as_root apt install -y "$package_name"
			log_success "$label installed"
			return 0
		fi
	done

	install_github_cli
	log_warning "Could not find an apt package for $label (${*})"
	return 1
}

install_essentials() {
	if [[ "$SKIP_PACKAGES" == true ]]; then
		log_info "Skipping Debian package installation (--skip-packages flag set)"
		return 0
	fi

	install_packages_from_file "$APT_BASE_PACKAGES_FILE" "Debian base packages"
}

install_desktop_packages() {
	if [[ "$SKIP_PACKAGES" == true || "$SKIP_DESKTOP" == true ]]; then
		log_info "Skipping GNOME desktop package installation"
		return 0
	fi

	install_packages_from_file "$APT_DESKTOP_PACKAGES_FILE" "GNOME desktop packages"

	install_first_available_package \
		"GNOME auto-tiling extension" \
		gnome-shell-extension-tiling-assistant \
		gnome-shell-extension-pop-shell || true
}

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

install_custom_motd() {
	if [[ "$SKIP_MOTD" == true ]]; then
		log_info "Skipping custom MOTD installation (--skip-motd flag set)"
		return 0
	fi

	log_info "Installing custom Debian MOTD..."
	run_cmd_as_root install -d /usr/local/bin /etc/update-motd.d /etc/default
	run_cmd_as_root install -m 0755 "$MOTD_SCRIPT_SOURCE" /usr/local/bin/dotfiles-debian-motd

	if [[ ! -f /etc/default/dotfiles-motd ]]; then
		run_cmd_as_root install -m 0644 "$MOTD_DEFAULTS_EXAMPLE" /etc/default/dotfiles-motd
		log_success "Installed MOTD personalization template at /etc/default/dotfiles-motd"
	else
		log_info "Keeping existing MOTD personalization file: /etc/default/dotfiles-motd"
	fi

	local wrapper_file
	wrapper_file="$(mktemp)"
	cat > "$wrapper_file" <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/dotfiles-debian-motd
EOF
	run_cmd_as_root install -m 0755 "$wrapper_file" /etc/update-motd.d/95-dotfiles-motd
	rm -f "$wrapper_file"

	log_success "Custom Debian MOTD installed"
}

setup_debian_defaults() {
	if [[ "$SKIP_DEFAULTS" == true || "$SKIP_DESKTOP" == true ]]; then
		log_info "Skipping Debian defaults"
		return 0
	fi

	if [[ "$FORCE" != true ]]; then
		log_warning "Applying Debian desktop defaults will change GNOME settings for the current user."
		if ! confirm_yes_no "Apply Debian defaults?"; then
			log_info "Skipping Debian defaults"
			return 0
		fi
	fi

	log_info "Applying Debian GNOME defaults..."
	run_cmd chmod +x "$GNOME_DEFAULTS_SCRIPT"
	run_cmd bash "$GNOME_DEFAULTS_SCRIPT"
	log_success "Debian defaults applied"
}

print_post_install() {
	echo ""
	echo -e "${BOLD}╔════════════════════════════════════════╗${RESET}"
	echo -e "${BOLD}║       Post-Installation Steps          ║${RESET}"
	echo -e "${BOLD}╚════════════════════════════════════════╝${RESET}"
	echo ""
	echo -e "  ${YELLOW}1.${RESET} Restart your terminal or run: ${GREEN}exec zsh${RESET}"
	echo ""
	echo -e "  ${YELLOW}2.${RESET} Customize your prompt in: ${GREEN}~/.zshrc.local${RESET}"
	echo ""
	echo -e "  ${YELLOW}3.${RESET} Personalize the login banner in: ${GREEN}/etc/default/dotfiles-motd${RESET}"
	echo ""
	if [[ "$SKIP_DESKTOP" != true ]]; then
		echo -e "  ${YELLOW}4.${RESET} Log out and pick the ${GREEN}GNOME${RESET} session if needed"
		echo ""
	fi
}

main() {
	if [[ "$BOOTSTRAP_PACKAGES_ONLY" == true ]]; then
		validate_package_context
		log_info "Bootstrapping Debian base packages required before stowing dotfiles..."
		install_essentials
		log_success "Debian package bootstrap complete"
		return 0
	fi

	validate_context
	print_banner
	confirm_or_exit "Proceed with installation?"

	log_info "Starting Debian installation..."

	install_essentials
	install_desktop_packages
	setup_zsh
	install_custom_motd
	setup_debian_defaults

	log_success "Installation complete!"
	print_post_install
}

main "$@"
