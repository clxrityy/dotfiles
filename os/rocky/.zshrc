# os/rocky/.zshrc
#
# Purpose:
#   Zsh configuration specific to a Rocky Linux VPS.
#   Keep it lightweight, prompt-friendly, and easy to override locally.

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
zstyle ':vcs_info:git:*' formats ' %F{rgb(0 136 255)}git:%b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{rgb(51 90 243)}git:%b|%a%f'

if [[ -x /usr/bin/dircolors ]]; then
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

: "${DOTFILES_PROMPT_STYLE:=builtin}"
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

if [[ -f "$HOME/.config/starship.local.toml" ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship.local.toml"
fi

if [[ "$DOTFILES_PROMPT_STYLE" == "starship" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  precmd_functions+=(build_dotfiles_prompt)
fi

if [[ -o login && -f "$HOME/.local/share/dotfiles/rocky/login-banner.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.local/share/dotfiles/rocky/login-banner.sh"
fi

if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
