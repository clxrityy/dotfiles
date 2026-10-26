# Linked to ~/.bash_profile on Windows (Git Bash runs as a login shell).

shopt -s histappend cdspell nocaseglob

alias ll='ls -alF'
alias la='ls -A'

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi
