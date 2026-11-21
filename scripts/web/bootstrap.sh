#!/usr/bin/env bash
#
# scripts/web/bootstrap.sh - Clone-free dotfiles bootstrap
#
# Published to GitHub Pages as `install.sh` (auto-detect OS) and as
# `<os>.sh` (OS pinned). Downloads only that OS's bundle, verifies its
# checksum, extracts it to ~/.dotfiles, then runs the bundled ./install.sh.
#
# Usage:
#   curl -fsSL https://clxrityy.github.io/dotfiles/install.sh | bash
#   curl -fsSL https://clxrityy.github.io/dotfiles/macos.sh | bash -s -- --dry-run
#
# Bootstrap options (everything else is passed through to install.sh):
#   --os <key>       macos | fedora | rocky | debian (default: auto-detect)
#   --dir <path>     Install location (default: ~/.dotfiles)
#   --no-install     Download and extract only; do not run install.sh
#   --base-url <u>   Where bundles are hosted (default: the GitHub Pages site)
#   -h, --help       Show this help
#
# Environment overrides: DOTFILES_OS, DOTFILES_DIR, DOTFILES_BASE_URL.
#
# Note: kept compatible with bash 3.2 (stock macOS) and wrapped in main() so a
# truncated download never executes a partial script.

set -euo pipefail

# Stamped by scripts/dev/build-pages.sh -- keep these on single lines.
DEFAULT_BASE_URL="https://clxrityy.github.io/dotfiles"
DEFAULT_OS=""

SUPPORTED_OS="macos fedora rocky debian"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat >&2 << 'EOF'
Usage:
  curl -fsSL <site>/install.sh | bash -s -- [options] [install.sh args]

Bootstrap options:
  --os <key>       macos | fedora | rocky | debian (default: auto-detect)
  --dir <path>     Install location (default: ~/.dotfiles)
  --no-install     Download and extract only; do not run install.sh
  --base-url <u>   Where bundles are hosted
  -h, --help       Show this help

All other arguments (e.g. --dry-run, --force, --verbose) go to install.sh.
EOF
}

# Mirrors detect_os_key in scripts/lib/os.sh (cannot source it before download).
detect_os() {
  case "${OSTYPE:-$(uname -s | tr '[:upper:]' '[:lower:]')}" in
    darwin*) printf 'macos' ;;
    msys*|cygwin*|win32*|mingw*) printf 'windows' ;;
    linux*)
      local id=""
      if [ -r /etc/os-release ]; then
        id="$(awk -F= '$1=="ID"{gsub(/^"|"$/,"",$2); print $2; exit}' /etc/os-release)"
      fi
      if [ "$id" = "rocky" ]; then printf 'rocky'
      elif [ -f /etc/fedora-release ]; then printf 'fedora'
      elif [ -f /etc/debian_version ]; then printf 'debian'
      else printf 'linux'
      fi
      ;;
    *) printf 'unknown' ;;
  esac
}

fetch() {
  # fetch <url> <dest>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    die "curl or wget is required"
  fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

# True if dir is missing, empty, or contains only a `private/` directory.
dir_is_free() {
  local d="$1" entry
  [ -d "$d" ] || return 0
  for entry in "$d"/* "$d"/.[!.]* "$d"/..?*; do
    [ -e "$entry" ] || continue
    [ "$(basename "$entry")" = "private" ] && continue
    return 1
  done
  return 0
}

main() {
  local os="${DOTFILES_OS:-$DEFAULT_OS}"
  local dir="${DOTFILES_DIR:-$HOME/.dotfiles}"
  local base_url="${DOTFILES_BASE_URL:-$DEFAULT_BASE_URL}"
  local run_install=true
  local -a passthru=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --os)         [ $# -ge 2 ] || die "--os needs a value"; os="$2"; shift 2 ;;
      --os=*)       os="${1#*=}"; shift ;;
      --dir)        [ $# -ge 2 ] || die "--dir needs a value"; dir="$2"; shift 2 ;;
      --dir=*)      dir="${1#*=}"; shift ;;
      --base-url)   [ $# -ge 2 ] || die "--base-url needs a value"; base_url="$2"; shift 2 ;;
      --base-url=*) base_url="${1#*=}"; shift ;;
      --no-install) run_install=false; shift ;;
      -h|--help)    usage; exit 0 ;;
      *)            passthru+=("$1"); shift ;;
    esac
  done

  base_url="${base_url%/}"
  dir="${dir/#\~/$HOME}"
  [ -n "$os" ] || os="$(detect_os)"

  case " $SUPPORTED_OS " in
    *" $os "*) ;;
    *)
      if [ "$os" = "windows" ]; then
        die "On Windows, use PowerShell: & ([scriptblock]::Create((irm $base_url/install.ps1)))"
      fi
      die "Unsupported OS '$os'. Supported: $SUPPORTED_OS (use --os to override)"
      ;;
  esac

  command -v tar >/dev/null 2>&1 || die "tar is required"

  if [ -e "$dir/.git" ]; then
    die "$dir is a git checkout. Update it with: git -C \"$dir\" pull && bash \"$dir/install.sh\""
  fi
  if [ ! -f "$dir/.bundle-version" ] && ! dir_is_free "$dir"; then
    die "$dir already exists and is not a dotfiles bundle. Move it aside or pass --dir <path>."
  fi

  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  say "Downloading $os bundle from $base_url"
  fetch "$base_url/$os.tar.gz" "$tmp/$os.tar.gz" || die "Download failed: $base_url/$os.tar.gz"

  if fetch "$base_url/SHA256SUMS" "$tmp/SHA256SUMS" 2>/dev/null; then
    local expected actual
    expected="$(awk -v f="$os.tar.gz" '$2==f || $2=="*"f {print $1; exit}' "$tmp/SHA256SUMS")"
    [ -n "$expected" ] || die "No checksum listed for $os.tar.gz"
    actual="$(sha256_of "$tmp/$os.tar.gz")" || die "sha256sum or shasum is required to verify the download"
    [ "$expected" = "$actual" ] || die "Checksum mismatch for $os.tar.gz (expected $expected, got $actual)"
    say "Checksum verified"
  else
    die "Could not fetch $base_url/SHA256SUMS to verify the download"
  fi

  tar -xzf "$tmp/$os.tar.gz" -C "$tmp"
  [ -f "$tmp/dotfiles/install.sh" ] || die "Bundle is malformed (no install.sh)"

  # Keep anything private the user placed in the install dir.
  if [ -d "$dir/private" ]; then
    mv "$dir/private" "$tmp/dotfiles/private"
  fi

  mkdir -p "$(dirname "$dir")"
  if [ -d "$dir" ]; then
    rm -rf "$dir"
  fi
  mv "$tmp/dotfiles" "$dir"

  # exec below skips the EXIT trap, so clean up now.
  rm -rf "$tmp"
  trap - EXIT

  say "Installed $(head -n 1 "$dir/.bundle-version" 2>/dev/null || echo bundle) to $dir"

  if [ "$run_install" != "true" ]; then
    say "Skipping install. Run it later with: bash \"$dir/install.sh\""
    return 0
  fi

  say "Running $dir/install.sh ${passthru[*]+"${passthru[*]}"}"
  cd "$dir"
  # When piped (curl | bash), stdin is the script itself; reattach the
  # terminal so the installers' y/n prompts work.
  if [ ! -t 0 ] && { : < /dev/tty; } 2>/dev/null; then
    exec bash "$dir/install.sh" ${passthru[@]+"${passthru[@]}"} < /dev/tty
  fi
  exec bash "$dir/install.sh" ${passthru[@]+"${passthru[@]}"}
}

main "$@"
