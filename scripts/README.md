# `.dotfiles/scripts`

> Scripts for managing, utilizing, and developing the dotfiles & environments

```ts
└── scripts/
    ├── usb/ 
    ├── dev/
    ├── extra/
    ├── lib/
    ├── source.sh
    ├── tests/
    │   ├── fixtures/
    │   │   └── ...
    │   ├── run
    │   ├── ...
    └── README.md
```

- [x] **`dev/`**: Development-related scripts
- [x] **`extra/`**: Miscellaneous scripts
  - [x] `convert-zip-files.sh`: Convert files within a zip archive to a different format
  - [x] `macos-stun-block.sh`: Script to block STUN traffic on macOS for enhanced privacy
  - [x] `ssh2-to-openssh.sh`: Convert SSH config files from SSH2 format to OpenSSH format
- [x] **`lib/`**: Shared libraries for scripts
- [x] **`tests/`**: Tests for scripts, with fixtures for testing
- [ ] **`usb/`**: Scripts for managing dotfiles on USB drives (e.g., [ventoy](https://www.ventoy.net/en/index.html), persistent OS environments, etc.)
  - **Note: This is a planned feature and may not be implemented yet.**
- [x] **`source.sh`**: Sources for common functions, variables, etc. used by scripts
