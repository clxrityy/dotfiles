# `~/.dotfiles/fedora`

## Files included

- [`.fedora`](./.fedora) - Fedora system preferences and settings
- [`.bashrc`](./.bashrc) - Bash shell runtime configuration
  - Aliases, functions, and environment variables for Bash sessions
- [`.zshrc`](./.zshrc) - Zsh shell runtime configuration
  - Aliases, functions, and plugins for Zsh sessions
  - Includes [Starship](https://starship.rs/) prompt configuration
- [`dnf-packages.txt`](./dnf-packages.txt) - Fedora package list for installing packages and applications
  - Development tools
  - Containerization tools
  - Utilities
- [`install.sh`](./install.sh) - Script to automate the installation and setup of dotfiles
  - Installs Fedora-only packages and dependencies using `dnf`
  - Configures shell tooling (Starship)
  - Applies Fedora system defaults via `.fedora`
  - Does not run GNU Stow (symlinking is handled by the root installer)

## Installation

Prefer running the root installer, which:

1. Detects your OS
2. Runs GNU Stow for `common/`, `shell/`, and the OS folder
3. Delegates to the OS installer

From the repo root:

```bash
bash install.sh
```

To run only the Fedora steps (without stow), from the repo root:

```bash
bash fedora/install.sh
```

---

![Example](./example.png)
