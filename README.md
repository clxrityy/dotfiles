# `~/.dotfiles/`

> - [What are dotfiles?](https://wiki.archlinux.org/title/Dotfiles)

A comprehensive repository containing all files and configurations to restore and reproduce my OS environment(s).

> [!NOTE]
> This is currently a minimal setup for macOS systems.
> Future plans include expanding support for Linux systems and adding more configurations.

- [Files included](#files-included)
- [Installation](#installation)

---

## Files included

### Configurations
> Core configuration files for various shells and system settings.

- [`.bash_profile`](./.bash_profile) - Bash shell profile configuration
- [`.macos`](./.macos) - macOS system preferences and settings
- [`.stowrc`](./.stowrc) - GNU Stow configuration file for managing [symlinks](https://www.gnu.org/software/stow/manual/stow.html)
    - Points to `~/.dotfiles/` as the target directory
- [`.zprofile`](./.zprofile) - Zsh shell profile configuration
    - Sets up environment variables and paths for Zsh sessions
- [`.zshrc`](./.zshrc) - Zsh shell runtime configuration
    - Aliases, functions, and plugins for Zsh sessions
    - Includes [Oh My Zsh](https://ohmyz.sh/) framework
- [`Brewfile`](./Brewfile) - Homebrew script for installing macOS packages and applications
    - Essential & development tools
    - Applications

### Utilities
> Files that assist in managing or enhancing the dotfiles repository.

- [`.editorconfig`](./.editorconfig) - EditorConfig file for consistent coding styles across different editors and IDEs
- [`.markdownlint.json`](./.markdownlint.json) - Configuration for Markdown linting rules
- [`.stow-local-ignore`](./.stow-local-ignore) - Local ignore patterns for GNU Stow
    - Specifies files or directories to exclude from symlink management

### Scripts
> Custom scripts for automating tasks related to dotfiles management.
> See [installation section](#installation) for usage.

- [`install.sh`](./install.sh) - Script to automate the installation and setup of dotfiles
    - Installs necessary packages and dependencies
    - Sets up symlinks using GNU Stow
    - Configures system settings as per the dotfiles
    - Provides an easy way to bootstrap a new system with the desired configurations

---

# Installation

## Clone the repository

```zsh
# Clone the repository
git clone https://github.com/clxrityy/dotfiles.git ~/.dotfiles
# Navigate to the dotfiles directory
cd ~/.dotfiles
```

## Run the installation script

```zsh
# Make the install script executable
chmod +x install.sh
# Run the install script with --help for further options
./install.sh --help
```
