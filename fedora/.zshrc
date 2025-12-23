# fedora/.zshrc
#
# Purpose:
#   Zsh configuration specific to Fedora.
#   This file is stowed to ~/.zshrc when running the root installer on Fedora.
#
# Notes:
#   - Keep this file Fedora-centric; put shared shell config in shell/.
#   - Starship is used as a cross-platform prompt (works on Linux/macOS).
#
# References:
#   - Starship: https://starship.rs/
#   - Zsh manual: https://zsh.sourceforge.io/Doc/

# Optional local override (not tracked in git):
#
# Starship loads config from ~/.config/starship.toml by default.
# If you want machine-specific prompt tweaks, create:
#   ~/.config/starship.local.toml
# and we will point Starship at it.
#
# Reference:
#   - STARSHIP_CONFIG env var: https://starship.rs/config/#configuration
if [[ -f "$HOME/.config/starship.local.toml" ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship.local.toml"
fi

# Load Starship prompt if installed.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Quality-of-life aliases.
alias ll='ls -lah'
alias update='sudo dnf upgrade -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'

# Put user overrides in ~/.zshrc.local (not tracked).
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
