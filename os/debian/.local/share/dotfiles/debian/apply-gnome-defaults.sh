#!/usr/bin/env bash
# os/debian/.local/share/dotfiles/debian/apply-gnome-defaults.sh
#
# Purpose:
#   Apply GNOME defaults for a Debian workstation that feels polished without
#   requiring heavy keyboard-first tiling workflows.

set -euo pipefail

enable_extension_if_present() {
  local extension_id="$1"

  if ! command -v gnome-extensions >/dev/null 2>&1; then
    return 1
  fi

  if [[ -d "/usr/share/gnome-shell/extensions/$extension_id" ]] || [[ -d "$HOME/.local/share/gnome-shell/extensions/$extension_id" ]]; then
    gnome-extensions enable "$extension_id" >/dev/null 2>&1 || true
    return 0
  fi

  return 1
}

if ! command -v gsettings >/dev/null 2>&1; then
  echo "gsettings not found; skipping GNOME defaults" >&2
  exit 0
fi

# General desktop behavior.
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.interface clock-show-weekday true || true
gsettings set org.gnome.desktop.interface enable-hot-corners false || true
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' || true
gsettings set org.gnome.desktop.wm.preferences num-workspaces 6 || true
gsettings set org.gnome.mutter dynamic-workspaces true || true
gsettings set org.gnome.mutter edge-tiling true || true

# Prefer a sensible terminal default when Nautilus opens a terminal action.
gsettings set org.gnome.desktop.default-applications.terminal exec 'gnome-terminal' || true

# Best-effort auto-tiling extension enablement.
if enable_extension_if_present 'tiling-assistant@leleat-on-github'; then
  echo 'Enabled Tiling Assistant extension.'
elif enable_extension_if_present 'pop-shell@system76.com'; then
  echo 'Enabled Pop Shell extension.'
else
  echo 'No supported auto-tiling extension was found; built-in GNOME edge tiling remains enabled.' >&2
fi
