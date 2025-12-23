# fedora/.bashrc
#
# Purpose:
#   Bash configuration specific to Fedora.
#   This file is stowed to ~/.bashrc when running the root installer on Fedora.
#
# Notes:
#   - Keep this file Fedora-centric; put shared shell config in shell/.
#   - Starship can also be used in bash.
#
# References:
#   - Bash manual: https://www.gnu.org/software/bash/manual/
#   - Starship: https://starship.rs/

# If not running interactively, don't do anything.
case $- in
  *i*) ;;
  *) return ;;
esac

# Load Starship prompt if installed.
#
# Optional local override (not tracked in git):
#   ~/.config/starship.local.toml
#
# Reference:
#   - STARSHIP_CONFIG env var: https://starship.rs/config/#configuration
if [[ -f "$HOME/.config/starship.local.toml" ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship.local.toml"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

alias ll='ls -lah'
alias update='sudo dnf upgrade -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'

# Put user overrides in ~/.bashrc.local (not tracked).
if [[ -f "$HOME/.bashrc.local" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.bashrc.local"
fi
