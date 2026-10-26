# `~/.dotfiles/os/windows`

Windows 11 setup. Not managed by GNU Stow: `install.ps1` creates symlinks itself.

## Usage

Fresh machine (elevated PowerShell, after downloading [`bootstrap.ps1`](../../bootstrap.ps1)):

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 [-DryRun] [-Force]
```

Existing clone (Git Bash):

```bash
./install.sh [--dry-run] [--force] [--verbose]
```

`install.sh` detects Windows (`OSTYPE=msys|cygwin|win32`) and runs [`install.ps1`](./install.ps1) through Windows PowerShell. Direct use: `install.ps1 [-DryRun] [-Force] [-VerboseLog] [-SkipDebloat] [-SkipSettings]`.

## Layout

- [`choco-packages.txt`](./choco-packages.txt) - Chocolatey packages (Git, gh, pwsh 7, Windows Terminal, starship, Hack Nerd Font, VS Code)
- [`modules/settings.ps1`](./modules/settings.ps1) - Explorer, taskbar, dark mode, telemetry/ads, Bing search, long paths, Developer Mode
- [`modules/links.ps1`](./modules/links.ps1) - Symlinks for terminal, pwsh profile, starship, VS Code; git config
- [`modules/debloat.ps1`](./modules/debloat.ps1) - Removes a fixed Appx list, OneDrive (unless Known Folder Move is active), Copilot, Cortana; Edge policies
- [`config/`](./config) - Files that get linked (Windows Terminal uses the Solarized Dark scheme)

## Notes

- Debloat writes every removal to `%LOCALAPPDATA%\dotfiles\debloat-<timestamp>.log`.
- Edge shows "managed by your organization" once the Edge policies are set.
- Git identity is not set; run `make setup-git-access` from Git Bash.
