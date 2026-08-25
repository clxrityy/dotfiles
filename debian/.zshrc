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
zstyle ':vcs_info:git:*' formats ' %F{magenta}git:%b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta}git:%b|%a%f'

: "${DOTFILES_PROMPT_SYMBOL:=›}"
: "${DOTFILES_PROMPT_USER_COLOR:=244}"
: "${DOTFILES_PROMPT_HOST_COLOR:=109}"
: "${DOTFILES_PROMPT_PATH_COLOR:=111}"
: "${DOTFILES_PROMPT_ERROR_COLOR:=red}"
: "${DOTFILES_PROMPT_OK_COLOR:=yellow}"

build_dotfiles_prompt() {
  local exit_code="$?"
  vcs_info

  local host_part=""
  local status_part=""

  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    host_part=" %F{${DOTFILES_PROMPT_HOST_COLOR}}@%m%f"
  fi

  if [[ "$exit_code" -ne 0 ]]; then
    status_part="%F{${DOTFILES_PROMPT_ERROR_COLOR}}${exit_code} ${DOTFILES_PROMPT_SYMBOL}%f"
  else
    status_part="%F{${DOTFILES_PROMPT_OK_COLOR}}${DOTFILES_PROMPT_SYMBOL}%f"
  fi

  PROMPT="%F{${DOTFILES_PROMPT_USER_COLOR}}%n%f${host_part} %F{${DOTFILES_PROMPT_PATH_COLOR}}%~%f${vcs_info_msg_0_}"$'\n'"${status_part} "
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
