#!/bin/bash
# ----------
# Block STUN traffic on macOS
#   << Blocks UDP traffic on port 3478 (STUN)
# ----------

RULE="block out proto udp from any to any port 3478" # STUN traffic (UDP 3478)
CONF="/etc/pf.conf"
BACKUP="/etc/pf.conf.backup.$(date +%Y%m%d%H%M%S)"

# ====
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
LIB_DIR="$REPO_DIR/scripts/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/colors.sh"
init_colors
# shellcheck source=/dev/null
source "$LIB_DIR/log.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/os.sh"

main() {

  local os
  os="$(detect_os_key)"

  case "$os" in
    macos)
      log_info "Detected macOS"
      ;;
    *)
      log_error "Unsupported OS: $os"
      exit 1
      ;;
  esac

  # Backup current pf.conf
  log_info "Backing up current pf.conf to $BACKUP"
  sudo cp "$CONF" "$BACKUP"

  # Add rule if not present
  if ! grep -Fxq "$RULE" "$CONF"; then
    log_info "Adding STUN block rule to $CONF"
    echo -e "\n# Block outbound STUN (UDP 3478)\n$RULE" | sudo tee -a "$CONF" >/dev/null
  else
    log_warning "STUN block rule already present in $CONF"
    exit 0
  fi

  # Check syntax and reload if OK
  if sudo pfctl -nf "$CONF"; then
    log_info "Reloading pf.conf with new rules"
    sudo pfctl -f "$CONF"
    sudo pfctl -e
  else
    log_error "Syntax error in $CONF. Restoring backup."
    sudo cp "$BACKUP" "$CONF"
    exit 1
  fi

  log_success "STUN block rule applied successfully"
}

main
