# os/rocky/.zshrc
#
# Purpose:
#   Zsh configuration specific to a Rocky Linux VPS.
#   Keep it lightweight, prompt-friendly, and easy to override locally.

[[ $- != *i* ]] && return

if [[ -f "$HOME/.config/starship.local.toml" ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship.local.toml"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
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

if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
