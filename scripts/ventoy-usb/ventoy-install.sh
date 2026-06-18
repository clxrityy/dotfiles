#!/bin/bash
# Ventoy USB setup script for macOS/Linux
# Read more: https://www.ventoy.net/en/doc_start.html
#   - Detects removable drives
#   - User selects a drive
#   - Refuse system disks
#   - Download Ventoy if missing
#   - Install Ventoy
#   - Verify installation

set -euo pipefail

# ======
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

# shellcheck source=/dev/null
source "$SCRIPTS_DIR/source.sh"

OS=$(detect_os_key)
log_info "Detected OS: $OS"
# ======

VENTOY_VERSION="1.1.12"
WORKDIR="/tmp/ventoy-installer"

# require_root() {
#   [[ "$EUID" -eq 0 ]] || { log_error "This script must be run as root. Use sudo."; exit 1; }
# }

list_drives() {
  if [[ "$OS" == "macos" ]]; then
    diskutil list external physical
    return
  fi
  lsblk -d -o NAME,SIZE,MODEL,TRAN,RM
}

select_drive() {
  echo
  log_info "Available drives:"
  echo

  list_drives
  echo

  if [[ "$OS" == "macos" ]]; then
    read -rp "Disk identifier (example: disk4): " disk
    DEVICE="/dev/$disk"
  else
    read -rp "Disk identifier (example: sdb): " disk
    DEVICE="/dev/$disk"
  fi

  [[ -b "$DEVICE" ]] || { log_error "Invalid device: $DEVICE"; exit 1; }
}

protect_system_disk() {
  if [[ "$OS" == "macos" ]]; then
    
    ROOT_DISK=$(
      diskutil info / \
      | awk -F': *' '/Part of Whole/ {print $2}'
    )

    [[ "$DEVICE" != "/dev/$ROOT_DISK" ]] || {
      log_error "Selected device $DEVICE is the system disk (/dev/$ROOT_DISK). Aborting."
      exit 1
    }
  else
    ROOT_SOURCE=$(findmnt -n -o SOURCE /)

    if [[ "$ROOT_SOURCE" =~ nvme ]]; then
      ROOT_DISK=$(echo "$ROOT_SOURCE" | sed 's/p[0-9]\+$//')
    else
      ROOT_DISK=$(echo "$ROOT_SOURCE" | sed 's/[0-9]\+$//')
    fi

    [[ "$DEVICE" != "$ROOT_DISK" ]] || {
      log_error "Selected device $DEVICE is the system disk ($ROOT_DISK). Aborting."
      exit 1
    }
  fi
}

confirm_drive() {
  echo
  if [[ "$OS" == "macos" ]]; then
    diskutil info "$DEVICE"
  else
    lsblk "$DEVICE"
  fi
  echo

  read -rp "Erase and install Ventoy to $DEVICE? (yes/no): " ANSWER
  [[ "$ANSWER" == "yes" ]] \
    || { log_error "Aborting installation."; exit 1; } 
}

download_ventoy() {
  mkdir -p "$WORKDIR"

  local archive="$WORKDIR/ventoy-$VENTOY_VERSION.tar.gz"

  local url="https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VERSION}/ventoy-${VENTOY_VERSION}-linux.tar.gz" 
  log_info "Downloading Ventoy..." 
  curl -L "$url" -o "$archive"
}

extract_ventoy() {
  local archive="$WORKDIR/ventoy-$VENTOY_VERSION.tar.gz"
  
  rm -rf "$WORKDIR/extracted"
  mkdir -p "$WORKDIR/extracted"

  tar -xf "$archive" -C "$WORKDIR/extracted"

  INSTALLER=$(find "$WORKDIR/extracted" \
    -name Ventoy2Disk.sh \
    | head -n1)
  
  [[ -f "$INSTALLER" ]] \
    || { log_error "Ventoy installer not found in extracted files."; exit 1; }
}

install_ventoy() {
  log_info "Installing Ventoy to $DEVICE..."
  
  sudo "$INSTALLER" -I "$DEVICE"
}

verify_installation() {
  log_info "Verifying Ventoy installation on $DEVICE..."

  sleep 2

  echo
  if [[ "$OS" == "macos" ]]; then
    diskutil list "$DEVICE"
  else
    partprobe "$DEVICE" || true
    lsblk "$DEVICE"
  fi

  log_success "Ventoy installation completed."
}

main() {
  select_drive
  protect_system_disk
  confirm_drive
  download_ventoy
  extract_ventoy
  install_ventoy
  verify_installation
}

main "$@"
