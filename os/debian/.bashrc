# shellcheck shell=bash
# os/debian/.bashrc
#
# Purpose:
#   Bash configuration specific to Debian.
#   Zsh is the primary shell, but keep bash pleasant when it appears.

# If not running interactively, don't do anything.
case $- in
  *i*) ;;
  *) return ;;
esac

PS1='\[\e[36m\]\u\[\e[0m\]@\[\e[34m\]\h\[\e[0m\] \[\e[32m\]\w\[\e[0m\]\n\[\e[33m\]❯\[\e[0m\] '

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install -y'
alias remove='sudo apt remove -y'
alias fetch='fastfetch'

# Put user overrides in ~/.bashrc.local (not tracked).
if [[ -f "$HOME/.bashrc.local" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.bashrc.local"
fi
