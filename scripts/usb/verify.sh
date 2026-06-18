#!/usr/bin/env bash
# ============================================================
#  verify_usb.sh — Inspect a USB drive's partition layout
#
#  Shows partition table, filesystem info, labels, free space,
#  and Ventoy version if installed.
#
#  Usage:
#    sudo ./verify_usb.sh [DEVICE]
#
#  Examples:
#    sudo ./verify_usb.sh /dev/sdb
#    sudo ./verify_usb.sh          # prompted interactively
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# ── Colours ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERR ]${NC}  $*" >&2; exit 1; }
log_step()  { echo -e "\n${CYAN}${BOLD}──► $*${NC}"; }
separator() { echo -e "${BOLD}────────────────────────────────────────────${NC}"; }

# ── Root check ───────────────────────────────────────────────
[[ $EUID -eq 0 ]] || log_error "Run as root: sudo $0 $*"

# ── Load config (optional) ──────────────────────────────────
# shellcheck disable=SC1090
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || true

# ── Device selection ────────────────────────────────────────
USB_DEVICE="${1:-${USB_DEVICE:-}}"

if [[ -z "${USB_DEVICE:-}" ]]; then
    echo ""
    log_info "Available block devices:"
    lsblk -d -o NAME,SIZE,MODEL,TRAN,RM | grep -v "loop" | column -t
    echo ""
    read -rp "Enter device path to verify (e.g. /dev/sdb): " USB_DEVICE
fi

USB_DEVICE="${USB_DEVICE%/}"
[[ -b "$USB_DEVICE" ]] || log_error "Not a valid block device: $USB_DEVICE"

# ── Helpers ──────────────────────────────────────────────────
partition_name() {
    local dev="$1" num="$2"
    if [[ "$dev" =~ nvme|mmcblk ]]; then echo "${dev}p${num}"; else echo "${dev}${num}"; fi
}

human_size() {
    # Convert bytes to human-readable
    local bytes="$1"
    awk -v b="$bytes" 'BEGIN {
        split("B KB MB GB TB", u)
        v=b; i=1
        while(v>=1024 && i<5){ v/=1024; i++ }
        printf "%.1f %s\n", v, u[i]
    }'
}

# ── Start report ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗"
echo -e "║   USB Drive Verification: ${USB_DEVICE}$(printf '%*s' $((19-${#USB_DEVICE})) '')║"
echo -e "╚══════════════════════════════════════════════╝${NC}"

# ── 1. Disk overview ─────────────────────────────────────────
log_step "Disk overview"
lsblk -d -o NAME,SIZE,MODEL,TRAN,ROTA,RM "$USB_DEVICE" | column -t

DISK_BYTES=$(blockdev --getsize64 "$USB_DEVICE")
DISK_HUMAN=$(human_size "$DISK_BYTES")
echo ""
log_info "Raw size: $DISK_HUMAN  ($DISK_BYTES bytes)"

# ── 2. Partition table (GPT) ─────────────────────────────────
log_step "GPT partition table"
sgdisk -p "$USB_DEVICE" 2>/dev/null || {
    log_warn "Could not read GPT — disk may use MBR or be unpartitioned."
}

# ── 3. Filesystem details ────────────────────────────────────
log_step "Partition filesystem details"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT "$USB_DEVICE"

# ── 4. Partition-by-partition checks ─────────────────────────
log_step "Per-partition checks"
separator

# EXPECTED_PARTS=5

for n in 1 2 3 4 5; do
    part=$(partition_name "$USB_DEVICE" "$n")
    printf "\n  ${BOLD}Partition %d  (%s)${NC}\n" "$n" "$part"

    if [[ ! -b "$part" ]]; then
        echo -e "    ${RED}✗  Not found${NC}"
        continue
    fi

    # blkid info
    FSTYPE=$(blkid -s TYPE   -o value "$part" 2>/dev/null || echo "—")
    LABEL=$(blkid -s LABEL  -o value "$part" 2>/dev/null || echo "—")
    UUID=$(blkid -s UUID   -o value "$part" 2>/dev/null || echo "—")
    PARTUUID=$(blkid -s PARTUUID -o value "$part" 2>/dev/null || echo "—")
    SIZE=$(lsblk -d -n -o SIZE "$part" 2>/dev/null || echo "—")

    printf "    %-12s %s\n"  "Size:"     "$SIZE"
    printf "    %-12s %s\n"  "FS type:"  "$FSTYPE"
    printf "    %-12s %s\n"  "Label:"    "$LABEL"
    printf "    %-12s %s\n"  "UUID:"     "$UUID"
    printf "    %-12s %s\n"  "PARTUUID:" "$PARTUUID"

    # Mount and check free space
    TMPDIR_MNT=$(mktemp -d)

    if mount -o ro "$part" "$TMPDIR_MNT" 2>/dev/null; then
        DF=$(df -h "$TMPDIR_MNT" | tail -1)
        USED=$(echo "$DF" | awk '{print $3}')
        AVAIL=$(echo "$DF" | awk '{print $4}')
        PCT=$(echo "$DF" | awk '{print $5}')
        printf "    %-12s %s used, %s free (%s)\n" "Space:" "$USED" "$AVAIL" "$PCT"
        umount "$TMPDIR_MNT" 2>/dev/null || true
    else
        echo -e "    ${YELLOW}(Could not mount for space check — may be swap or unformatted)${NC}"
    fi
    rmdir "$TMPDIR_MNT" 2>/dev/null || true

    # Expected-role hint
    case $n in
        1) echo -e "    ${CYAN}↳ Expected: Ventoy EFI bootloader (FAT16/FAT32)${NC}" ;;
        2) echo -e "    ${CYAN}↳ Expected: Ventoy ISO storage — drop .iso files here${NC}" ;;
        3) echo -e "    ${CYAN}↳ Expected: Persistent OS (ext4 or btrfs)${NC}" ;;
        4) echo -e "    ${CYAN}↳ Expected: Backup OS (ext4, btrfs, or ntfs)${NC}" ;;
        5) echo -e "    ${CYAN}↳ Expected: Data storage (exFAT)${NC}" ;;
    esac
done

# ── 5. Ventoy version check ──────────────────────────────────
log_step "Ventoy version"

VTOY_PART=$(partition_name "$USB_DEVICE" 2)
if [[ ! -b "$VTOY_PART" ]]; then
    log_warn "Ventoy partition ($VTOY_PART) not found — Ventoy may not be installed."
else
    VTOY_MNT=$(mktemp -d)
    if mount -o ro "$VTOY_PART" "$VTOY_MNT" 2>/dev/null; then

        VERSION_FILE=""
        for candidate in \
            "$VTOY_MNT/.ventoy/ventoy.json" \
            "$VTOY_MNT/ventoy/ventoy.json"; do
            [[ -f "$candidate" ]] && VERSION_FILE="$candidate" && break
        done

        if [[ -n "$VERSION_FILE" ]]; then
            VTOY_VER=$(grep -o '"ventoy_version"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" \
                | sed 's/.*"\([0-9.]*\)".*/\1/' || echo "unknown")
            log_ok "Ventoy version: $VTOY_VER"
        else
            log_warn "Ventoy JSON not found — may be an older install or non-Ventoy partition."
        fi

        # Count ISOs
        ISO_COUNT=$(find "$VTOY_MNT" -maxdepth 2 -name "*.iso" 2>/dev/null | wc -l)
        log_info "ISO files on Ventoy partition: $ISO_COUNT"

        umount "$VTOY_MNT" 2>/dev/null || true
    else
        log_warn "Could not mount Ventoy partition for inspection."
    fi
    rmdir "$VTOY_MNT" 2>/dev/null || true
fi

# ── 6. S.M.A.R.T. (USB passthrough, best-effort) ────────────
log_step "S.M.A.R.T. health (best-effort)"
if command -v smartctl &>/dev/null; then
    SMART_STATUS=$(smartctl -H "$USB_DEVICE" 2>&1 | grep -i "overall-health\|result" || true)
    if [[ -n "$SMART_STATUS" ]]; then
        if echo "$SMART_STATUS" | grep -qi "PASSED\|OK"; then
            log_ok "$SMART_STATUS"
        else
            log_warn "$SMART_STATUS"
        fi
    else
        log_warn "S.M.A.R.T. data not available for this device (common for USB flash drives)."
    fi
else
    log_info "smartmontools not installed — skipping SMART check."
    log_info "  Install with: apt-get install smartmontools"
fi

# ── Done ─────────────────────────────────────────────────────
echo ""
separator
echo -e "${GREEN}${BOLD}  Verification complete.${NC}"
echo ""
echo "  To re-partition this drive:"
echo "    sudo ${SCRIPT_DIR}/setup_usb.sh -d $USB_DEVICE"
echo ""
