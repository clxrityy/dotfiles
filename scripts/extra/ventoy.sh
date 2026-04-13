#!/bin/bash
# ----------------
# Setup Ventoy USB
# Read more: https://www.ventoy.net/en/doc_start.html
# ----------------

set -euo pipefail

# ======
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

# shellcheck source=/dev/null
source "$SCRIPTS_DIR/source.sh"

# =====
# Get the external drive device identifier
#   << Returns the device identifier of the external drive (e.g., /dev/sdb)
#     |- Searches for external drives using OS-specific commands:
#       |- `diskutil list external` (macOS)
#       |- `lsblk -o NAME,TYPE | grep disk` (Linux)
# =====
get_external_drive() {
  local drive=""
  if command -v diskutil &> /dev/null 2>&1; then
    # Get the first external physical disk (not partition)
    drive=$(diskutil list external | awk '/^\/dev\// {print $1; exit}')
  elif command -v lsblk &> /dev/null 2>&1; then
    # Get the first removable disk (not partition)
    drive=$(lsblk -ndo NAME,TYPE,RM | awk '$2=="disk" && $3==1 {print "/dev/"$1; exit}')
    # Fallback: get any disk if no removable found
    if [[ -z "$drive" ]]; then
      drive=$(lsblk -ndo NAME,TYPE | awk '$2=="disk" {print "/dev/"$1; exit}')
    fi
  else
    log_error "No suitable command found to list external drives (macOS: diskutil, Linux: lsblk)"
    exit 1
  fi
  if [[ -z "$drive" ]]; then
    log_error "No external drive detected."
    exit 1
  fi
  log_info "Detected external drive: $drive"
  echo "$drive"
}

# =====
# Unmount all partitions (macOS/Linux)
#   |- ARGS:
#       $1: The device identifier of the external drive (e.g., /dev/sdb)  
# =====
unmount_partitions() {
  # macOS
  if command -v diskutil &> /dev/null 2>&1; then
    sudo diskutil unmountDisk "$1" >/dev/null 2>&1
  # Linux
  elif command -v umount &> /dev/null 2>&1; then
    sudo umount "$1" >/dev/null 2>&1
  else
    log_error "No suitable unmount command found (macOS: diskutil, Linux: umount)"
  fi
}

# =====
# Format the external drive
#   << exFAT (modern, widely supported)
#     << FAT32 (older, widely supported)
# |- ARGS:
#     $1: The device identifier of the external drive (e.g., /dev/sdb)
#         |- Auto-detects OS and chooses the appropriate format command
# =====
format_drive() {
  if command -v diskutil &> /dev/null 2>&1; then
    # macOS (requires exFAT support in Sierra or later)
    sudo diskutil eraseDisk ZEROED F0 exfat "$1" >/dev/null 2>&1
    log_success "Drive formatted successfully (exFAT)"
  elif command -v mkfs.exfat &> /dev/null 2>&1; then
    # Linux (installs exfat-utils if needed)
    if command -v mkfs.exfat &> /dev/null 2>&1; then
      sudo mkfs.exfat "$1" >/dev/null 2>&1
      log_success "Drive formatted successfully (exFAT)"
    else
      # install exfat-utils if needed
      if sudo apt-get install -y exfat-utils; then
        sudo mkfs.exfat "$1" >/dev/null 2>&1
        log_success "Drive formatted successfully (exFAT)"
      else
        log_error "Failed to install exfat-utils"
      fi
    fi

  elif command -v mkfs.fat &> /dev/null 2>&1; then
    # Fallback to FAT32 (Linux/macOS)
    sudo mkfs.fat -F 32 "$1" >/dev/null 2>&1
    log_success "Drive formatted successfully (FAT32)"
  else
    log_error "No suitable format command found (macOS: diskutil, Linux: mkfs.exfat/mkfs.fat)"
    exit 1
  fi
}

# =====
# Download Ventoy ISO
# (offical Ventoy release from https://github.com/ventoy/Ventoy/releases)
# =====
download_ventoy() {
  local url="https://github.com/ventoy/Ventoy/releases/download/v1.1.10/ventoy-1.1.10-livecd.iso"
  local output="/tmp/ventoy.iso"
  confirm_yes_no "Confirm to download Ventoy ISO to $output"
  log_info "Downloading Ventoy ISO from $url to $output"
  if sudo curl -sL "$url" -o "$output"; then
    log_success "Ventoy ISO downloaded successfully ($output)"
  else
    log_error "Failed to download Ventoy ISO"
    return 1
  fi
}

# =====
# Write Ventoy ISO to the external drive
# |- ARGS:
#     $1: The device identifier of the external drive (e.g., /dev/sdb)
# =====
write_ventoy_iso() {
  local drive=$1
  local iso="/tmp/ventoy.iso"
  log_warning "About to write Ventoy ISO to $drive. This will erase all data on the drive."
  confirm_yes_no "Confirm to write Ventoy ISO to $drive"
  log_info "Writing Ventoy ISO to $drive"
  if sudo dd if="$iso" of="$drive" bs=4M status=progress; then
    log_success "Ventoy USB setup completed successfully"
  else
    log_error "Failed to setup Ventoy USB"
    return 1
  fi
}

cleanup() {
  rm -f /tmp/ventoy.iso
  log_success "Cleaned up temporary files"
}

main() {
  print_box_banner "       Ventoy USB Setup" "         clxrityy/dotfiles"
  local drive
  drive=$(get_external_drive)

  confirm_yes_no "Confirm to use external drive: $drive"

  unmount_partitions "$drive"

  format_drive "$drive"

  download_ventoy

  write_ventoy_iso "$drive"
  cleanup

  log_success "Ventoy USB setup completed"
}

main
