# `~/.dotfiles/os/rocky`

## Files included

- [`install.sh`](./install.sh) - Rocky Linux-specific installation entrypoint
  - Installs Rocky-only packages and dependencies using `dnf`
  - Configures shell tooling for a headless VPS workflow
  - Keeps a built-in colored shell prompt by default and supports optional [Starship](https://starship.rs/)
  - Does not run GNU Stow (symlinking is handled by the root installer)
- [`dnf-packages.txt`](./dnf-packages.txt) - Base CLI/server packages for Rocky Linux
- [`.zshrc`](./.zshrc) - Lean Zsh configuration for an SSH-first environment
- [`.bashrc`](./.bashrc) - Bash fallback configuration for interactive shells
- [`.local/share/dotfiles/rocky/login-banner.sh`](./.local/share/dotfiles/rocky/login-banner.sh) - Lightweight login banner for SSH/login shells

## Installation

Prefer running the root installer, which:

1. Detects your OS
2. Runs GNU Stow for `common/`, `shell/`, and the OS folder
3. Delegates to the Rocky installer

From the repo root:

```bash
bash install.sh
```

To run only the Rocky steps (without stow), from the repo root:

```bash
bash os/rocky/install.sh
```

## Notes

- This profile is intentionally headless: no GNOME or desktop defaults are applied.
- The package list starts conservative because server roles tend to drift; extend `dnf-packages.txt` as this VPS gains responsibilities.
- `ls` color support is restored via `dircolors`, and the default Rocky prompt is a built-in colored shell prompt.
- Set `DOTFILES_PROMPT_STYLE=starship` in `~/.zshrc.local` or `~/.bashrc.local` if you want Starship back as the active prompt.
- Prompt customization belongs in `~/.config/starship.local.toml`, `~/.zshrc.local`, or `~/.bashrc.local` to keep the tracked config clean.
