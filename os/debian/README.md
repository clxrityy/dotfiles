# `~/.dotfiles/os/debian`

## Files included

- [`install.sh`](./install.sh) - Debian-specific installation entrypoint
  - Installs Debian-only packages and dependencies using `apt`
  - Configures shell tooling, custom MOTD, and GNOME defaults
  - Does not run GNU Stow (symlinking is handled by the root installer)
- [`apt-packages.txt`](./apt-packages.txt) - Base CLI/workstation packages
- [`gnome-packages.txt`](./gnome-packages.txt) - GNOME desktop packages
- [`.zshrc`](./.zshrc) - Lean Zsh configuration with a customizable prompt
- [`.bashrc`](./.bashrc) - Bash fallback configuration for interactive shells
- [`.local/share/dotfiles/debian/apply-gnome-defaults.sh`](./.local/share/dotfiles/debian/apply-gnome-defaults.sh) - Applies GNOME defaults and enables auto-tiling best effort
- [`.local/share/dotfiles/motd/dotfiles-debian-motd`](./.local/share/dotfiles/motd/dotfiles-debian-motd) - Custom MOTD renderer
- [`.local/share/dotfiles/motd/dotfiles-motd.conf.example`](./.local/share/dotfiles/motd/dotfiles-motd.conf.example) - Example personalization file for `/etc/default/dotfiles-motd`

## Installation

Prefer running the root installer, which:

1. Detects your OS
2. Runs GNU Stow for `common/`, `shell/`, and the OS folder
3. Delegates to the Debian installer

From the repo root:

```bash
bash install.sh
```

To run only the Debian steps (without stow), from the repo root:

```bash
bash os/debian/install.sh
```

## Notes

- `gh` is installed separately from the base apt package list; if your Debian repos do not provide it, the installer adds the official GitHub CLI apt source and retries.
- GNOME auto-tiling is installed on a best-effort basis using distro packages when available.
- Prompt customization belongs in `~/.zshrc.local` to keep the tracked config clean.
- MOTD personalization belongs in `/etc/default/dotfiles-motd`.
- Git identity/auth bootstrap is available via `make setup-git-access`.
