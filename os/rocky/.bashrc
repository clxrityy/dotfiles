#!/bin/bash
# os/rocky/.bashrc
#
# Purpose:
#   Bash configuration specific to a Rocky Linux VPS.
#   This file is stowed to ~/.bashrc when running the root installer on Rocky.
#
# Notes:
#   - Keep this file Rocky-centric; put shared shell config in shell/.
#   - Starship can also be used in bash.

case $- in
  *i*) ;;
  *) return ;;
esac

if [[ -f "$HOME/.config/starship.local.toml" ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship.local.toml"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias update='sudo dnf upgrade --refresh -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'

if command -v fastfetch >/dev/null 2>&1; then
  alias fetch='fastfetch'
fi

if [[ -f "$HOME/.bashrc.local" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.bashrc.local"
fi
