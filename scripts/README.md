# `.dotfiles/scripts`

Scripts for managing, utilizing, and developing the dotfiles & environments

```ts
└── scripts/
    ├── usb/ <<< // Planned feature for managing dotfiles on USB drives
    ├── dev/ <<< // Development-related scripts
    ├── extra/ <<< // Miscellaneous scripts
    ├── lib/ <<< // Shared libraries for scripts
    ├── source.sh <<< // Common functions, variables, etc. for scripts
    ├── tests/ <<< // Tests for scripts
    │   ├── fixtures/
    │   │   └── ...
    │   ├── run
    │   ├── ...
    └── README.md
```

- [x] **`dev/`**: Development-related scripts
  - [x] `copy-package.sh`: Copy a specified package's live target contents into a destination directory (via [`packages.conf`](../packages.conf))
  - [x] `macos-write-settings.sh`: Reads current macOS defaults and system settings and writes them to [`macos/.macos`](../macos/.macos)
  - [x] `migrate-package.sh`: Migrate a single package
    - Unstow current package from its target
    - Rename package directory
    - Stow new package to new target
    - Update `packages.conf` entry
- [x] **`extra/`**: Miscellaneous scripts
  - [x] `convert-zip-files.sh`: Convert files within a zip archive to a different format
  - [x] `macos-stun-block.sh`: Script to block STUN traffic on macOS for enhanced privacy
  - [x] `ssh2-to-openssh.sh`: Convert SSH config files from SSH2 format to OpenSSH format
- [x] **`lib/`**: Shared libraries for scripts
  - [x] `args.sh`: Parse common installer flags such as `--dry-run`, `--verbose`, etc.
  - [x] `banner.sh`: Print a standardized banner for installers
  - [x] `colors.sh`: Define color variables for consistent script output
  - [x] `fs.sh`: Small filesystem helpers
  - [x] `log.sh`: Logging functions for consistent log formatting and levels
  - [x] `os.sh`: OS detection and related utilities
  - [x] `packages.sh`: Package management utilities for installation scripts
  - [x] `prompt.sh`: Functions for prompting user input in scripts
  - [x] `run.sh`: Helpers for executing commands with dry-run support and dependency checks
  - [x] `stow.sh`: Centralize stow orchestration (backup + stow per package)
- [x] **`tests/`**: Tests for scripts, with fixtures for testing
- [ ] **`usb/`**: Scripts for managing dotfiles on USB drives (e.g., [ventoy](https://www.ventoy.net/en/index.html), persistent OS environments, etc.)
  - **Note: This is a planned feature and may not be implemented yet.**
- [x] **`source.sh`**: Sources for common functions, variables, etc. used by scripts
