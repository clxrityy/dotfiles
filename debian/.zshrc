# debian/.zshrc
#
# Purpose:
#   Lean Zsh configuration for Debian workstations.
#   Keep it lightweight, customizable, and friendly to local overrides.

# If not running interactively, don't do anything.
[[ $- != *i* ]] && return

autoload -Uz colors vcs_info
colors

setopt auto_cd
setopt hist_ignore_all_dups
setopt share_history
setopt prompt_subst

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{magenta}[%b]%f'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta}[%b|%a]%f'

: "${DOTFILES_PROMPT_SYMBOL:=❯}"
: "${DOTFILES_PROMPT_USER_COLOR:=cyan}"
: "${DOTFILES_PROMPT_HOST_COLOR:=blue}"
: "${DOTFILES_PROMPT_PATH_COLOR:=green}"
: "${DOTFILES_PROMPT_ERROR_COLOR:=red}"

build_dotfiles_prompt() {
  local exit_code="$?"
  vcs_info

  local status_part=""
  if [[ "$exit_code" -ne 0 ]]; then
    status_part="%F{${DOTFILES_PROMPT_ERROR_COLOR}}${exit_code}%f "
  fi

  PROMPT="%F{${DOTFILES_PROMPT_USER_COLOR}}%n%f@%F{${DOTFILES_PROMPT_HOST_COLOR}}%m%f %F{${DOTFILES_PROMPT_PATH_COLOR}}%~%f${vcs_info_msg_0_}\n${status_part}%F{yellow}${DOTFILES_PROMPT_SYMBOL}%f "
}

precmd_functions+=(build_dotfiles_prompt)

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install -y'
alias remove='sudo apt remove -y'
alias fetch='fastfetch'

# Put user overrides in ~/.zshrc.local (not tracked).
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
