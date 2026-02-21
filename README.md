# `~/.dotfiles/`

> - [What are dotfiles?](https://wiki.archlinux.org/title/Dotfiles)

A comprehensive repository containing all files and configurations to restore and reproduce my OS & development environment(s).

- [Environments](#environments)
- [Installation](#installation)

## Environments

Each OS folder contains OS-specific configurations, scripts, and installation instructions.

<div style="display: inline-block; gap: 10px;">
  <a href="./macos/README.md"><img src="https://img.shields.io/badge/macOS-os?style=for-the-badge&logo=apple&logoColor=%23000000&color=%23ffffff" alt="macOS"></a>
  <a href="./fedora/README.md"><img src="https://img.shields.io/badge/fedora-os?style=for-the-badge&logo=fedora&logoColor=%2351A2DA&color=%23ffffff" alt="Fedora"></a>
</div>

## Installation

### Clone the repository

```bash
# Clone the repository (HTTPS)
git clone https://github.com/clxrityy/dotfiles.git ~/.dotfiles
# Clone the repository (SSH)
# git clone git@github.com:clxrityy/dotfiles.git ~/.dotfiles
# Navigate to the dotfiles directory
cd ~/.dotfiles
```

#### Run the installation script

```bash
# Show help
bash install.sh --help

# Run installation (auto-detects OS, runs GNU Stow, then runs OS-specific steps)
bash install.sh
```

---

## Future Plans

- _More_ Linux (Ubuntu, Arch, etc.)
- Windows (WSL, PowerShell, etc.)
- Container setups (Dockerfiles, DevContainers, etc.)
- Specific development environment setups (Python, Node.js, Go, etc.)
- Configurations for copilot agents, instructions, prompts, etc.
- VPN configurations
- SSH config management
