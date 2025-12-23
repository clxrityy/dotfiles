# `~/.dotfiles/`

> - [What are dotfiles?](https://wiki.archlinux.org/title/Dotfiles)

A comprehensive repository containing all files and configurations to restore and reproduce my OS environment(s).

---

# Installation

## Clone the repository

```bash
# Clone the repository
git clone https://github.com/clxrityy/dotfiles.git ~/.dotfiles
# Navigate to the dotfiles directory
cd ~/.dotfiles
```

## Run the installation script

```bash
# Show help
bash install.sh --help

# Run installation (auto-detects OS, runs GNU Stow, then runs OS-specific steps)
bash install.sh
```
