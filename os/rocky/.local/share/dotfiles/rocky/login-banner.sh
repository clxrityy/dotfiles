#!/usr/bin/env bash
# os/rocky/.local/share/dotfiles/rocky/login-banner.sh
#
# Purpose:
#   Print a lightweight MOTD-style banner for Rocky login shells.
#
# Notes:
#   - Sourced by both Bash and Zsh on login shells only.
#   - Guarded so nested shells do not spam the banner repeatedly.

if [[ -n "${DOTFILES_LOGIN_BANNER_SHOWN:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
export DOTFILES_LOGIN_BANNER_SHOWN=1

if [[ ! -t 1 ]]; then
  return 0 2>/dev/null || exit 0
fi

pretty_name="Rocky Linux"
if [[ -r /etc/os-release ]]; then
  pretty_name="$(awk -F= '/^PRETTY_NAME=/{gsub(/"/, "", $2); print $2; exit}' /etc/os-release)"
fi

host_name="$(hostname 2>/dev/null || printf '%s' 'unknown-host')"
kernel_name="$(uname -r 2>/dev/null || printf '%s' 'unknown-kernel')"
uptime_value="$(uptime -p 2>/dev/null | sed 's/^up //')"

printf '\n'
printf '  \033[1;36m%s\033[0m\n' "$host_name"
printf '  \033[0;37m%s\033[0m\n' "$pretty_name"
printf '  \033[0;33mKernel:\033[0m %s\n' "$kernel_name"

if [[ -n "$uptime_value" ]]; then
  printf '  \033[0;33mUptime:\033[0m %s\n' "$uptime_value"
fi

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  printf '  \033[0;33mSession:\033[0m ssh as %s\n' "$USER"
fi

printf '\n'
