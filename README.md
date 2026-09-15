# `~/.dotfiles/`

A comprehensive repository containing all files and configurations to restore and reproduce my OS & development environment(s).

- [Operating systems](#operating-systems)
- [Scripts & Utilities](#scripts--utilities)
- [Installation](#installation)

<details>
  <summary><b>What are <i>dotfiles</i>?</b></summary>
  <br>

  > User-specific application configuration is traditionally stored in so called [dotfiles](https://en.wikipedia.org/wiki/dotfile) (files whose filename starts with a dot). It is common practice to track dotfiles with a [version control system](https://wiki.archlinux.org/title/Version_control_system) such as [Git](https://wiki.archlinux.org/title/Git) to keep track of changes and synchronize dotfiles across various hosts.
  >
> ###### *Reference:* [Arch Linux | Dotfiles](https://wiki.archlinux.org/title/Dotfiles)

</details>

---

## Operating systems

Each OS folder under `os/` contains specific configurations, scripts, and installation instructions.

> Note: shared shell configs and repo-wide config live outside OS folders:
>
> - `shell/` (e.g. `.bash_profile`)
> - `common/` (e.g. `.editorconfig`)

- [macOS](./os/macos/README.md)
- [Fedora](./os/fedora/README.md)
- [Debian](./os/debian/README.md)

<table>
  <tr style="text-align:center;">
    <th><a href="./os/macos/README.md"><img src="https://img.shields.io/badge/macOS-os?style=for-the-badge&logo=apple&logoColor=%23000000&color=%23ffffff" alt="macOS"></a></th>
    <th><a href="./os/fedora/README.md"><img src="https://img.shields.io/badge/fedora-os?style=for-the-badge&logo=fedora&logoColor=%2351A2DA&color=%23ffffff" alt="Fedora"></a></th>
    <th><a href="./os/debian/README.md"><img src="https://img.shields.io/badge/Debian-os?style=for-the-badge&logo=debian&logoColor=%23A81D33&color=%23ffffff" alt="Debian"></a></th>
  </tr>
  <tr>
    <td><img src="./.github/img/macos.gif" alt="macOS Example" width="200"/></td>
    <td><img src="./.github/img/fedora.png" alt="Fedora Example" width="200"/></td>
    <td><img src="./.github/img/debian.png" alt="Debian Example" width="200"/></td>
  </tr>
</table>

## Scripts & Utilities

- [scripts/README.md](./scripts/README.md)

View all scripts/utilities and how to use them by running:

```bash
make help
```

> [!NOTE]
> 
> When using `make` to execute script-wrapper targets, pass arguments like:
>
> ```bash
> make <target> ARGS="<args to pass to script>"
> ```
>
> *OR:*
>
> ```bash
> make <target> -- <args to pass to script>
> ```

## Installation

### Clone the repository

<details>
  <summary><b>SSH</b> (alternative)</summary>
  <br>
  <blockquote>
    Cloning with SSH requires that you have your SSH keys set up with GitHub.
  </blockquote>

###### See [Connecting to GitHub with SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) for instructions

  ```bash
  git clone git@github.com:clxrityy/dotfiles.git ~/.dotfiles
  ```

</details>

##### Using HTTPS (recommended for most users)

```bash
# Clone the repository (HTTPS)
git clone https://github.com/clxrityy/dotfiles.git ~/.dotfiles
# Navigate to the dotfiles directory
cd ~/.dotfiles
```

#### Run the installation script

```bash
# Show help
bash install.sh --help

# Run installation as a dry-run with verbose output
bash install.sh --dry-run --verbose

# Run installation (auto-detects OS, runs GNU Stow, then runs OS-specific steps)
bash install.sh
```

---

## TO-DO

- [x] CI
- [ ] Windows
- [x] Debian
- [ ] Ventoy USB setup
- [x] Package migration script
- [ ] Development-specific environments
- [ ] VPN configurations
- [ ] SSH config management
- [ ] Container setups (Docker)
