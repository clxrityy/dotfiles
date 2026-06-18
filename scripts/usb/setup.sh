#!/usr/bin/env bash
# ============================================================
#  setup_usb.sh — Automated 1 TB USB Partition Setup
#
#  Creates the following layout on a USB drive:
#    Part 1  ~34 MiB   FAT32    Ventoy EFI bootloader  (auto)
#    Part 2  300 GiB   exFAT    Ventoy ISO storage     (drop .iso files here)
#    Part 3  150 GiB   ext4     Persistent portable OS
#    Part 4  150 GiB   ext4     Backup OS
#    Part 5  ~rest     exFAT    General data storage
#
#  All sizes are configurable in config.env.
#  Safe to re-run: use -f to skip confirmation prompts.
#
#  Usage:
#    sudo ./setup_usb.sh [OPTIONS]
#
#  Options:
#    -d DEVICE   Target device (e.g. /dev/sdb) — overrides config.env
#    -c FILE     Config file path (default: ./config.env)
#    -f          Force mode — skip confirmation prompts
#    -h          Show this help
#
#  Examples:
#    sudo ./setup_usb.sh                      # interactive
#    sudo ./setup_usb.sh -d /dev/sdb          # specific device
#    sudo ./setup_usb.sh -d /dev/sdb -f       # no prompts
# ============================================================
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# ── Colour helpers ─────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERR ]${NC}  $*" >&2; exit 1; }
log_step()  { echo -e "\n${CYAN}${BOLD}──► $*${NC}"; }
log_banner(){ echo -e "\n${BOLD}╔══════════════════════════════════════════╗\n║  $*\n╚══════════════════════════════════════════╝${NC}\n"; }

# ── Usage ──────────────────────────────────────────────────
usage() {
    sed -n '/^# *Usage:/,/^# *$/p' "$0" | sed 's/^# \{0,2\}//'
    exit 0
}

# ── Argument parsing ───────────────────────────────────────
OVERRIDE_DEVICE=""
OVERRIDE_FORCE=0

while getopts ":d:c:fh" opt; do
    case $opt in
        d) OVERRIDE_DEVICE="$OPTARG" ;;
        c) CONFIG_FILE="$OPTARG" ;;
        f) OVERRIDE_FORCE=1 ;;
        h) usage ;;
        :) log_error "Option -$OPTARG requires an argument." ;;
        \?) log_error "Unknown option: -$OPTARG" ;;
    esac
done

# ── Load config ────────────────────────────────────────────
[[ -f "$CONFIG_FILE" ]] || log_error "Config file not found: $CONFIG_FILE"
# shellcheck source=config.env
source "$CONFIG_FILE"

[[ -n "$OVERRIDE_DEVICE" ]] && USB_DEVICE="$OVERRIDE_DEVICE"
[[ "$OVERRIDE_FORCE" -eq 1 ]] && FORCE=1

# ── Privilege check ────────────────────────────────────────
check_root() {
    [[ $EUID -eq 0 ]] || log_error "Must run as root.  Try: sudo $0 $*"
}

# ── Dependency check ───────────────────────────────────────
check_dependencies() {
    log_step "Checking dependencies"
    local missing=()

    for cmd in sgdisk lsblk blockdev partprobe curl tar udevadm; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    command -v mkfs.ext4   &>/dev/null || missing+=("mkfs.ext4 (e2fsprogs)")
    command -v mkfs.exfat  &>/dev/null && EXFAT_CMD="mkfs.exfat" || {
        command -v mkexfatfs &>/dev/null && EXFAT_CMD="mkexfatfs" || missing+=("mkfs.exfat (exfatprogs or exfat-utils)")
    }

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing: ${missing[*]}"
        log_info "Attempting to install missing packages..."
        if command -v apt-get &>/dev/null; then
            apt-get install -y --no-install-recommends \
                gdisk e2fsprogs exfatprogs curl 2>/dev/null \
                || apt-get install -y gdisk e2fsprogs exfat-utils curl
        elif command -v dnf &>/dev/null; then
            dnf install -y gdisk e2fsprogs exfatprogs curl
        elif command -v pacman &>/dev/null; then
            pacman -S --noconfirm gptfdisk e2fsprogs exfatprogs curl
        else
            log_error "Cannot auto-install packages. Please install: ${missing[*]}"
        fi
    fi

    # Re-detect exfat command after install
    command -v mkfs.exfat  &>/dev/null && EXFAT_CMD="mkfs.exfat"  || true
    command -v mkexfatfs   &>/dev/null && EXFAT_CMD="mkexfatfs"   || true
    [[ -n "${EXFAT_CMD:-}" ]] || log_error "No exFAT formatting tool available."

    log_ok "All dependencies satisfied (exFAT tool: $EXFAT_CMD)"
}

# ── Device selection ───────────────────────────────────────
select_device() {
    if [[ -z "${USB_DEVICE:-}" ]]; then
        log_step "Select target USB device"
        echo ""
        log_info "Available block devices:"
        lsblk -d -o NAME,SIZE,MODEL,TRAN,RM | grep -v "loop" | column -t
        echo ""
        read -rp "Enter device path (e.g. /dev/sdb): " USB_DEVICE
    fi
    USB_DEVICE="${USB_DEVICE%/}"
    [[ -b "$USB_DEVICE" ]] || log_error "Not a valid block device: $USB_DEVICE"
    log_ok "Target device: ${BOLD}$USB_DEVICE${NC}"
}

# Return partition name, handling nvme (nvme0n1 → nvme0n1p3) vs normal (sdb → sdb3)
partition_name() {
    local dev="$1" num="$2"
    if [[ "$dev" =~ nvme|mmcblk ]]; then
        echo "${dev}p${num}"
    else
        echo "${dev}${num}"
    fi
}

# ── Size calculations ──────────────────────────────────────
calculate_sizes() {
    log_step "Calculating partition sizes"

    DISK_SIZE_BYTES=$(blockdev --getsize64 "$USB_DEVICE")
    DISK_SIZE_MiB=$(( DISK_SIZE_BYTES / 1048576 ))
    DISK_SIZE_GiB=$(( DISK_SIZE_MiB / 1024 ))

    VENTOY_DATA_MiB=$(( VENTOY_DATA_MiB * 1024 ))
    PERSISTENT_MiB=$(( PERSISTENT_MiB * 1024 ))
    BACKUP_MiB=$(( BACKUP_MiB * 1024 ))
    VENTOY_EFI_MiB=34
    ALIGN_BUFFER_MiB=128   # GPT overhead + alignment slack

    # Reserve = everything after Ventoy's two partitions
    RESERVE_MiB=$(( DISK_SIZE_MiB - VENTOY_EFI_MiB - VENTOY_DATA_MiB - ALIGN_BUFFER_MiB ))

    FIXED_MiB=$(( VENTOY_EFI_MiB + VENTOY_DATA_MiB + PERSISTENT_MiB + BACKUP_MiB ))
    DATA_MiB=$(( DISK_SIZE_MiB - FIXED_MiB - ALIGN_BUFFER_MiB ))
    DATA_MiB=$(( DATA_MiB / 1024 ))

    if (( RESERVE_MiB < (PERSISTENT_MiB + BACKUP_MiB + 1024) )); then
        log_error "Not enough disk space. Reduce VENTOY_DATA_MiB, PERSISTENT_MiB, or BACKUP_MiB."
    fi

    echo ""
    printf "  %-25s %s\n"  "Disk total:"          "~${DISK_SIZE_GiB} GiB"
    printf "  %-25s %s\n"  "Part 1 – Ventoy EFI:" "~${VENTOY_EFI_MiB} MiB  (auto)"
    printf "  %-25s %s\n"  "Part 2 – Ventoy ISOs:" "${VENTOY_DATA_MiB} MiB"
    printf "  %-25s %s\n"  "Part 3 – Persistent OS:" "${PERSISTENT_MiB} MiB  ($PERSISTENT_FS)"
    printf "  %-25s %s\n"  "Part 4 – Backup OS:"   "${BACKUP_MiB} MiB  ($BACKUP_FS)"
    printf "  %-25s %s\n"  "Part 5 – Data:"        "~${DATA_MiB} MiB  ($DATA_FS)"
    echo ""
    log_ok "Sizes calculated. Ventoy reserve: ${RESERVE_MiB} MiB"
}

# ── Wipe confirmation ──────────────────────────────────────
confirm_wipe() {
    if [[ "$FORCE" -eq 1 ]]; then
        log_warn "Force mode: skipping confirmation"
        return
    fi

    local model
    model=$(lsblk -d -o MODEL "$USB_DEVICE" 2>/dev/null | tail -1 | xargs)

    echo ""
    echo -e "${RED}${BOLD}  ⚠  ALL DATA ON $USB_DEVICE WILL BE ERASED  ⚠${NC}"
    [[ -n "$model" ]] && echo -e "     Device model: ${model}"
    echo ""
    read -rp "  Type YES to continue: " _confirm
    [[ "$_confirm" == "YES" ]] || { log_info "Aborted."; exit 0; }
}

# ── Ventoy download ────────────────────────────────────────
download_ventoy() {
    log_step "Preparing Ventoy"

    mkdir -p "$VENTOY_DOWNLOAD_DIR"

    if [[ "$VENTOY_VERSION" == "auto" ]]; then
        log_info "Fetching latest Ventoy release tag..."
        VENTOY_VERSION=$(
            curl -fsSL https://api.github.com/repos/ventoy/Ventoy/releases/latest \
            | grep '"tag_name"' \
            | sed 's/.*"v\([^"]*\)".*/\1/'
        )
        [[ -n "$VENTOY_VERSION" ]] || log_error "Could not determine latest Ventoy version. Set VENTOY_VERSION manually in config.env."
        log_info "Latest Ventoy: v${VENTOY_VERSION}"
    fi

    local tarball="ventoy-${VENTOY_VERSION}-linux.tar.gz"
    local url="https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VERSION}/${tarball}"
    local dest="${VENTOY_DOWNLOAD_DIR}/${tarball}"

    if [[ -f "$dest" ]]; then
        log_info "Already downloaded: $dest"
    else
        log_info "Downloading from: $url"
        curl -fL --progress-bar -o "$dest" "$url" \
            || log_error "Download failed. Check your internet connection."
    fi

    log_info "Extracting..."
    tar -xzf "$dest" -C "$VENTOY_DOWNLOAD_DIR" \
        --overwrite

    VENTOY_DIR="${VENTOY_DOWNLOAD_DIR}/ventoy-${VENTOY_VERSION}"
    VENTOY_SCRIPT="${VENTOY_DIR}/Ventoy2Disk.sh"

    [[ -f "$VENTOY_SCRIPT" ]] \
        || log_error "Ventoy install script not found at: $VENTOY_SCRIPT"
    chmod +x "$VENTOY_SCRIPT"

    log_ok "Ventoy v${VENTOY_VERSION} ready at: $VENTOY_DIR"
}

# ── Ventoy install ─────────────────────────────────────────
install_ventoy() {
    log_step "Installing Ventoy → $USB_DEVICE"
    log_info "Reserving ${RESERVE_MiB} MiB for extra partitions"

    # -I : force install (safe to re-run; overwrites existing Ventoy)
    # -g : GPT partition table (required for > 2 TiB; better for UEFI)
    # -r : reserve MiB at end for our extra partitions
    # -L : label for the ISO storage partition
    (
        cd "$VENTOY_DIR"
        bash Ventoy2Disk.sh -I -g -r "$RESERVE_MiB" -L "$VENTOY_LABEL" "$USB_DEVICE"
    )

    log_info "Waiting for kernel to update partition table..."
    partprobe "$USB_DEVICE" 2>/dev/null || true
    udevadm settle 2>/dev/null || sleep 3

    log_ok "Ventoy installed"
}

# ── Create partitions ──────────────────────────────────────
create_partitions() {
    log_step "Creating partitions 3, 4, 5 in reserved space"

    # Verify Ventoy created its two partitions
    local vtoy_part2
    vtoy_part2=$(partition_name "$USB_DEVICE" 2)
    [[ -b "$vtoy_part2" ]] \
        || log_error "Ventoy partition 2 not found ($vtoy_part2). Ventoy install may have failed."

    # Partition 3 – Persistent OS
    log_info "Creating partition 3: Persistent OS  (+${PERSISTENT_MiB} MiB, type linux)"
    sgdisk \
        --new="3:0:+${PERSISTENT_MiB}M" \
        --typecode="3:8300" \
        --change-name="3:${PERSISTENT_LABEL}" \
        "$USB_DEVICE"

    # Partition 4 – Backup OS
    log_info "Creating partition 4: Backup OS       (+${BACKUP_MiB} MiB, type linux)"
    sgdisk \
        --new="4:0:+${BACKUP_MiB}M" \
        --typecode="4:8300" \
        --change-name="4:${BACKUP_LABEL}" \
        "$USB_DEVICE"

    # Partition 5 – Data (rest of disk)
    log_info "Creating partition 5: Data            (remaining space)"
    sgdisk \
        --new="5:0:0" \
        --typecode="5:0700" \
        --change-name="5:${DATA_LABEL}" \
        "$USB_DEVICE"

    log_info "Refreshing partition table..."
    partprobe "$USB_DEVICE" 2>/dev/null || true
    udevadm settle 2>/dev/null || sleep 3

    log_ok "Partitions 3–5 created"
}

# ── Format partitions ──────────────────────────────────────
format_exfat() {
    local dev="$1" label="$2"
    if [[ "${EXFAT_CMD:-}" == "mkfs.exfat" ]]; then
        mkfs.exfat -L "$label" "$dev"
    else
        mkexfatfs -n "$label" "$dev"
    fi
}

format_partition() {
    local dev="$1" fs="$2" label="$3"
    case "$fs" in
        ext4)  mkfs.ext4  -L "$label" -F "$dev" ;;
        ext3)  mkfs.ext3  -L "$label" -F "$dev" ;;
        btrfs) mkfs.btrfs -L "$label" -f "$dev" ;;
        exfat) format_exfat "$dev" "$label" ;;
        fat32|vfat) mkfs.fat -F32 -n "$label" "$dev" ;;
        ntfs)  mkfs.ntfs  -Q  -L "$label" "$dev" ;;
        *)     log_error "Unsupported filesystem: $fs" ;;
    esac
}

wait_for_partition() {
    local part="$1"
    local retries=10
    while [[ ! -b "$part" && $retries -gt 0 ]]; do
        sleep 1
        partprobe "$USB_DEVICE" 2>/dev/null || true
        udevadm settle 2>/dev/null || true
        (( retries-- ))
    done
    [[ -b "$part" ]] || log_error "Partition node $part never appeared. Check 'dmesg' for errors."
}

format_partitions() {
    log_step "Formatting partitions"

    local p3 p4 p5
    p3=$(partition_name "$USB_DEVICE" 3)
    p4=$(partition_name "$USB_DEVICE" 4)
    p5=$(partition_name "$USB_DEVICE" 5)

    log_info "Waiting for partition nodes..."
    wait_for_partition "$p3"
    wait_for_partition "$p4"
    wait_for_partition "$p5"

    log_info "Formatting $p3 → $PERSISTENT_FS  (label: $PERSISTENT_LABEL)"
    format_partition "$p3" "$PERSISTENT_FS" "$PERSISTENT_LABEL"

    log_info "Formatting $p4 → $BACKUP_FS      (label: $BACKUP_LABEL)"
    format_partition "$p4" "$BACKUP_FS" "$BACKUP_LABEL"

    log_info "Formatting $p5 → $DATA_FS         (label: $DATA_LABEL)"
    format_partition "$p5" "$DATA_FS" "$DATA_LABEL"

    log_ok "All partitions formatted"
}

# ── Summary ────────────────────────────────────────────────
print_summary() {
    log_banner "Setup Complete"

    lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,TYPE "$USB_DEVICE"
    echo ""

    local p1 p2 p3 p4 p5
    p1=$(partition_name "$USB_DEVICE" 1)
    p2=$(partition_name "$USB_DEVICE" 2)
    p3=$(partition_name "$USB_DEVICE" 3)
    p4=$(partition_name "$USB_DEVICE" 4)
    p5=$(partition_name "$USB_DEVICE" 5)

    echo -e "${BOLD}Partition summary:${NC}"
    printf "  ${GREEN}%-14s${NC} %s\n" "$p1" "Ventoy EFI — do not touch"
    printf "  ${GREEN}%-14s${NC} %s\n" "$p2" "Ventoy ISOs — copy your .iso files here"
    printf "  ${GREEN}%-14s${NC} %s\n" "$p3" "Persistent OS — casper-rw or full distro install"
    printf "  ${GREEN}%-14s${NC} %s\n" "$p4" "Backup OS — recovery distro or secondary OS"
    printf "  ${GREEN}%-14s${NC} %s\n" "$p5" "Data — exFAT, readable on Windows/macOS/Linux"

    local p3_partuuid
    p3_partuuid=$(blkid -s PARTUUID -o value "$p3" 2>/dev/null || echo "run: blkid -s PARTUUID -o value $p3")

    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Copy ISO files into the mounted VENTOY partition ($p2)"
    echo "  2. To enable persistence for a live ISO, create ventoy/ventoy.json"
    echo "     on the VENTOY partition. Example for Ubuntu (uses partition 3):"
    echo ""
    echo '     {
        "persistence": [
          {
            "image": "/ubuntu-24.04.iso",
            "backend": [
                {
                "id": "PARTUUID='"${p3_partuuid}"'",
                "mode": "x-casper-rw"
              }
            ]
          }
        ]
      }'
    echo ""
    echo "  3. Run ./verify_usb.sh to check the layout at any time."
    echo ""
}

# ── Entry point ────────────────────────────────────────────
main() {
    log_banner "USB Drive Partition Setup"

    check_root "$@"
    check_dependencies
    select_device
    calculate_sizes
    confirm_wipe
    download_ventoy
    install_ventoy
    create_partitions
    format_partitions
    print_summary
}

main "$@"
