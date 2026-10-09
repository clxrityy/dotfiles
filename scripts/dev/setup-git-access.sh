#!/usr/bin/env bash
# scripts/dev/setup-git-access.sh
#
# Purpose:
#   Bootstrap local Git identity and GitHub authentication using the tracked
#   example.gitconfig template.
#
# Notes:
#   - The live ~/.gitconfig is intentionally not tracked in git.
#   - This script is safe to rerun; it updates identity/auth settings in place.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"
TEMPLATE_GITCONFIG="$REPO_DIR/git/example.gitconfig"
TARGET_GITCONFIG="$HOME/.gitconfig"

# shellcheck source=/dev/null
source "$SCRIPTS_DIR/source.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/args.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/run.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/os.sh"

GIT_USERNAME=""
GIT_EMAIL=""
AUTH_MODE="https"
AUTH_FLOW="auto"
SKIP_GH_AUTH="false"

usage() {
  cat << EOF
${BOLD}Usage:${RESET}
  ${GREEN}$(basename "$0")${RESET} ${BLUE}[options]${RESET}

${BOLD}Description:${RESET}
  Create or update your local ${BLUE}~/.gitconfig${RESET} from the tracked template,
  then configure GitHub authentication using ${BLUE}gh${RESET}.

${BOLD}Options:${RESET}
$(print_common_flags_help)
  ${BLUE}--username <name>${RESET}   Set Git user.name
  ${BLUE}--email <email>${RESET}     Set Git user.email
  ${BLUE}--ssh${RESET}               Prefer SSH auth instead of HTTPS
  ${BLUE}--https${RESET}             Use HTTPS auth via GitHub CLI (default)
  ${BLUE}--web${RESET}               Force browser-based GitHub login
  ${BLUE}--device${RESET}            Avoid launching a local browser; use terminal/device flow
  ${BLUE}--no-gh-auth${RESET}        Configure Git for SSH access without logging into GitHub CLI

${BOLD}Examples:${RESET}
  ${GREEN}make setup-git-access${RESET}
  ${GREEN}make setup-git-access ARGS="--username clxrityy --email 123+clxrityy@users.noreply.github.com"${RESET}
  ${GREEN}make setup-git-access ARGS="--ssh"${RESET}
  ${GREEN}make setup-git-access ARGS="--device"${RESET}
  ${GREEN}make setup-git-access ARGS="--ssh --no-gh-auth"${RESET}
EOF
}

parse_cli() {
  parse_common_flags "$@"

  if [[ "$SHOW_HELP" == "true" ]]; then
    usage
    exit 0
  fi

  if [[ "${REMAINING_ARGS+x}" ]]; then
    set -- "${REMAINING_ARGS[@]}"
  else
    set --
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username)
        [[ $# -lt 2 ]] && { log_error "--username requires a value"; exit 1; }
        GIT_USERNAME="$2"
        shift 2
        ;;
      --email)
        [[ $# -lt 2 ]] && { log_error "--email requires a value"; exit 1; }
        GIT_EMAIL="$2"
        shift 2
        ;;
      --ssh)
        AUTH_MODE="ssh"
        shift
        ;;
      --https)
        AUTH_MODE="https"
        shift
        ;;
      --web)
        AUTH_FLOW="web"
        shift
        ;;
      --device)
        AUTH_FLOW="device"
        shift
        ;;
      --no-gh-auth)
        SKIP_GH_AUTH="true"
        shift
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        log_error "Unexpected positional argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ "$SKIP_GH_AUTH" == "true" && "$AUTH_MODE" != "ssh" ]]; then
    log_error "--no-gh-auth is only supported together with --ssh"
    exit 1
  fi
}

need_local_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    log_error "Missing required command: $name"
    return 1
  fi
}

is_template_identity_value() {
  local key="$1"
  local value="$2"

  case "$key:$value" in
    name:"Your Name")
      return 0
      ;;
    email:"12345678+github-username@users.noreply.github.com")
      return 0
      ;;
  esac

  return 1
}

prompt_if_empty() {
  local var_name="$1"
  local prompt_text="$2"
  local current_value="${!var_name}"

  if [[ -n "$current_value" ]]; then
    return 0
  fi

  read -r -p "$prompt_text: " current_value
  printf -v "$var_name" '%s' "$current_value"
}

has_local_browser() {
  local browser_cmd="${BROWSER:-}"

  if [[ -n "$browser_cmd" ]]; then
    browser_cmd="${browser_cmd%% *}"
    if command -v "$browser_cmd" >/dev/null 2>&1; then
      return 0
    fi
  fi

  case "$(uname -s)" in
    Darwin)
      command -v open >/dev/null 2>&1
      return
      ;;
  esac

  local candidate
  for candidate in \
    firefox \
    firefox-esr \
    chromium \
    chromium-browser \
    google-chrome \
    google-chrome-stable \
    brave-browser \
    microsoft-edge \
    vivaldi \
    qutebrowser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}

login_with_gh() {
  local protocol="$1"
  local login_args=(gh auth login --git-protocol "$protocol")

  case "$AUTH_FLOW" in
    web)
      log_info "Using browser-based GitHub authentication..."
      run_cmd "${login_args[@]}" --web
      ;;
    device)
      log_info "Using terminal-based GitHub authentication (no local browser required)..."
      log_info "Follow the one-time code prompt from gh to finish sign-in."
      run_cmd "${login_args[@]}"
      ;;
    auto)
      if has_local_browser; then
        log_info "Using browser-based GitHub authentication..."
        run_cmd "${login_args[@]}" --web
      else
        log_warning "No suitable local browser detected; falling back to terminal-based GitHub authentication"
        log_info "Follow the one-time code prompt from gh to finish sign-in on this or another device."
        run_cmd "${login_args[@]}"
      fi
      ;;
    *)
      log_error "Unsupported auth flow: $AUTH_FLOW"
      exit 1
      ;;
  esac
}

print_manual_ssh_steps() {
  local pub_key_path="$1"

  echo ""
  echo -e "${BOLD}Manual GitHub SSH setup required${RESET}"
  echo -e "  ${YELLOW}1.${RESET} Add this public key to GitHub: ${GREEN}${pub_key_path}${RESET}"
  echo -e "  ${YELLOW}2.${RESET} For org private repos, authorize the key for the org if SAML/SSO is enforced"
  echo -e "  ${YELLOW}3.${RESET} Test access with: ${GREEN}ssh -T git@github.com${RESET}"
  echo ""
}

backup_existing_gitconfig_if_needed() {
  if [[ ! -e "$TARGET_GITCONFIG" ]]; then
    return 0
  fi

  if cmp -s "$TEMPLATE_GITCONFIG" "$TARGET_GITCONFIG"; then
    log_info "Existing ~/.gitconfig already matches the tracked template"
    return 0
  fi

  if [[ "$FORCE" != "true" ]]; then
    log_warning "A local ~/.gitconfig already exists and may contain custom settings."
    if ! confirm_yes_no "Back it up and continue?"; then
      log_info "Skipping ~/.gitconfig bootstrap"
      return 1
    fi
  fi

  local backup_path
  backup_path="$TARGET_GITCONFIG.bak.$(date +%Y%m%d_%H%M%S)"
  run_cmd cp "$TARGET_GITCONFIG" "$backup_path"
  log_success "Backed up existing ~/.gitconfig to $backup_path"
}

ensure_gitconfig_template() {
  need_local_cmd git

  if [[ ! -f "$TEMPLATE_GITCONFIG" ]]; then
    log_error "Missing template: $TEMPLATE_GITCONFIG"
    exit 1
  fi

  if [[ ! -e "$TARGET_GITCONFIG" ]]; then
    log_info "Creating ~/.gitconfig from tracked template..."
    run_cmd cp "$TEMPLATE_GITCONFIG" "$TARGET_GITCONFIG"
    log_success "Created ~/.gitconfig"
    return 0
  fi

  backup_existing_gitconfig_if_needed || return 0
  log_info "Refreshing ~/.gitconfig from tracked template..."
  run_cmd cp "$TEMPLATE_GITCONFIG" "$TARGET_GITCONFIG"
  log_success "Refreshed ~/.gitconfig"
}

configure_identity() {
  local existing_name existing_email
  existing_name="$(git config --global --get user.name || true)"
  existing_email="$(git config --global --get user.email || true)"

  if is_template_identity_value name "$existing_name"; then
    existing_name=""
  fi
  if is_template_identity_value email "$existing_email"; then
    existing_email=""
  fi

  if [[ -z "$GIT_USERNAME" ]]; then
    GIT_USERNAME="$existing_name"
  fi
  if [[ -z "$GIT_EMAIL" ]]; then
    GIT_EMAIL="$existing_email"
  fi

  prompt_if_empty GIT_USERNAME "Git user.name"
  prompt_if_empty GIT_EMAIL "Git user.email"

  if [[ -z "$GIT_USERNAME" || -z "$GIT_EMAIL" ]]; then
    log_error "Git username and email are required."
    exit 1
  fi

  run_cmd git config --global user.name "$GIT_USERNAME"
  run_cmd git config --global user.email "$GIT_EMAIL"
  run_cmd git config --global core.editor "$(command -v code >/dev/null 2>&1 && printf code || printf nano)"
  run_cmd git config --global init.defaultBranch main
  run_cmd git config --global push.autoSetupRemote true
  run_cmd git config --global credential.helper cache

  log_success "Configured Git identity for $GIT_USERNAME <$GIT_EMAIL>"
}

setup_https_auth() {
  need_local_cmd gh

  log_info "Configuring GitHub HTTPS authentication via gh..."
  run_cmd git config --global credential."https://github.com".helper '!gh auth git-credential'
  login_with_gh https
  run_cmd gh auth setup-git
  log_success "GitHub HTTPS authentication configured"
}

setup_ssh_auth() {
  need_local_cmd ssh-keygen

  local key_path="$HOME/.ssh/id_ed25519"
  local pub_key_path="$key_path.pub"

  run_cmd mkdir -p "$HOME/.ssh"

  if [[ ! -f "$key_path" ]]; then
    log_info "Generating SSH key for GitHub access..."
    run_cmd ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$key_path" -N ""
    log_success "SSH key generated: $key_path"
  else
    log_info "Existing SSH key found: $key_path"
  fi

  run_cmd git config --global url."git@github.com:".insteadOf https://github.com/

  if [[ "$SKIP_GH_AUTH" == "true" ]]; then
    log_warning "Skipping GitHub CLI authentication; Git will use SSH only"
    if [[ -f "$pub_key_path" ]]; then
      print_manual_ssh_steps "$pub_key_path"
    fi
    log_success "GitHub SSH access configured without GitHub CLI authentication"
    return 0
  fi

  need_local_cmd gh
  login_with_gh ssh

  if [[ -f "$pub_key_path" ]]; then
    log_info "Attempting to upload SSH public key to GitHub..."
    run_cmd gh ssh-key add "$pub_key_path" --title "$(hostname)-$(date +%Y%m%d)"
  fi

  log_success "GitHub SSH authentication configured"
}

print_next_steps() {
  echo ""
  echo -e "${BOLD}Git access summary${RESET}"
  echo -e "  ${YELLOW}Mode:${RESET} ${AUTH_MODE}"
  echo -e "  ${YELLOW}GitHub CLI auth:${RESET} ${SKIP_GH_AUTH}"
  echo -e "  ${YELLOW}Config:${RESET} ${TARGET_GITCONFIG}"
  echo -e "  ${YELLOW}Identity:${RESET} ${GIT_USERNAME} <${GIT_EMAIL}>"
  echo ""
  echo -e "  ${BLUE}Tip:${RESET} The live ${GREEN}~/.gitconfig${RESET} remains ignored locally."
  echo -e "       Update the tracked template in ${GREEN}git/example.gitconfig${RESET} when you want to improve the bootstrap defaults."
  echo ""
}

main() {
  parse_cli "$@"

  print_box_banner "      Git Access Bootstrap" "         clxrityy/dotfiles"

  ensure_gitconfig_template
  configure_identity

  case "$AUTH_MODE" in
    https)
      setup_https_auth
      ;;
    ssh)
      setup_ssh_auth
      ;;
    *)
      log_error "Unsupported auth mode: $AUTH_MODE"
      exit 1
      ;;
  esac

  print_next_steps
}

main "$@"
