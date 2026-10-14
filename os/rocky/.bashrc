#!/bin/bash
# os/rocky/.bashrc
#
# Purpose:
#   Bash configuration specific to a Rocky Linux VPS.
#   This file is stowed to ~/.bashrc when running the root installer on Rocky.
#
# Notes:
#   - Keep this file Rocky-centric; put shared shell config in shell/.
#   - Starship can be enabled explicitly, but is not forced by default.

case $- in
  *i*) ;;
  *) return ;;
esac

if [ -x /usr/bin/dircolors ]; then
  eval "$(dircolors -b)"
  alias ls='ls --color=auto'
fi

alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias update='sudo dnf upgrade --refresh -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'

if command -v fastfetch >/dev/null 2>&1; then
  alias fetch='fastfetch'
fi

if [[ -f "$HOME/.config/starship.local.toml" ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship.local.toml"
fi

: "${DOTFILES_PROMPT_STYLE:=builtin}"

if [[ "$DOTFILES_PROMPT_STYLE" == "starship" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
else
  PS1='\[\e[36m\]\u\[\e[0m\]@\[\e[34m\]\h\[\e[0m\] \[\e[32m\]\w\[\e[0m\]\n\[\e[33m\]›\[\e[0m\] '
fi

if shopt -q login_shell && [[ -f "$HOME/.local/share/dotfiles/rocky/login-banner.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.local/share/dotfiles/rocky/login-banner.sh"
fi

if [[ -f "$HOME/.bashrc.local" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.bashrc.local"
fi

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
