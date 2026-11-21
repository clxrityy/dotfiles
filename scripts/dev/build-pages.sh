#!/usr/bin/env bash
# scripts/dev/build-pages.sh
#
# Purpose:
#   Build the GitHub Pages site that serves clone-free, per-OS dotfiles bundles.
#
# Output (default: ./dist):
#   install.sh            Bootstrap with OS auto-detection
#   <os>.sh               Bootstrap with the OS pinned (macos, fedora, rocky, debian)
#   <os>.tar.gz           Minimal bundle for that OS (root installer + shared libs + packages)
#   install.ps1           Windows bootstrap
#   windows.zip           Windows bundle
#   SHA256SUMS            Checksums verified by the bootstrap scripts
#   index.html            Landing page listing the commands
#
# Usage:
#   ./scripts/dev/build-pages.sh [--out <dir>] [--base-url <url>]
#
# Example (local test):
#   ./scripts/dev/build-pages.sh --base-url http://localhost:8000
#   (cd dist && python3 -m http.server 8000)
#   curl -fsSL localhost:8000/install.sh | bash -s -- --dir /tmp/df-test --dry-run
#
# Notes:
#   - Only git-tracked files are bundled, so private/ and ignored secrets never ship.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$REPO_DIR/dist"
BASE_URL="https://clxrityy.github.io/dotfiles"

UNIX_OSES=(macos fedora rocky debian)

# Shared by every Unix bundle: root installer, its libs, and the stow packages
# that packages.conf applies to all systems.
UNIX_COMMON_PATHS=(
  install.sh
  packages.conf
  .stowrc
  .stow-local-ignore
  scripts/source.sh
  scripts/lib
  common
  shell
  git
  os/.stow-local-ignore
)

# os/windows/install.ps1 resolves Root as ..\.. and links from common/ and git/.
WINDOWS_PATHS=(common git os/windows)

usage() {
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)      OUT_DIR="$2"; shift 2 ;;
    --base-url) BASE_URL="${2%/}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage; exit 1 ;;
  esac
done

for tool in git tar zip; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Missing required tool: %s\n' "$tool" >&2; exit 1; }
done

sha256_line() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1"
  else
    shasum -a 256 "$1"
  fi
}

COMMIT="$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [[ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]]; then
  COMMIT="$COMMIT-dirty"
fi
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pages.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Avoid macOS AppleDouble (._*) entries in tarballs.
export COPYFILE_DISABLE=1

# stage_bundle <stage_dir> <label> <paths...>
# Copies the tracked files under <paths> into <stage_dir>/dotfiles.
stage_bundle() {
  local stage="$1/dotfiles" label="$2"
  shift 2
  mkdir -p "$stage"

  local file count=0
  while IFS= read -r -d '' file; do
    [[ -f "$REPO_DIR/$file" ]] || continue   # tracked but deleted in worktree
    mkdir -p "$stage/$(dirname "$file")"
    cp -p "$REPO_DIR/$file" "$stage/$file"
    count=$((count + 1))
  done < <(git -C "$REPO_DIR" ls-files -z -- "$@")

  printf '%s %s\nbuilt %s\n' "$label" "$COMMIT" "$BUILD_DATE" > "$stage/.bundle-version"
  printf '  %-8s %3d files\n' "$label" "$count"
}

stamp_bootstrap() {
  # stamp_bootstrap <os-or-empty> <dest>
  sed -e "s|^DEFAULT_BASE_URL=.*|DEFAULT_BASE_URL=\"$BASE_URL\"|" \
      -e "s|^DEFAULT_OS=.*|DEFAULT_OS=\"$1\"|" \
      "$REPO_DIR/scripts/web/bootstrap.sh" > "$2"
  chmod 644 "$2"
}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
# Absolute, so steps that cd elsewhere (zip) still write to the right place.
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

printf 'Building bundles (%s) -> %s\n' "$COMMIT" "$OUT_DIR"

for os in "${UNIX_OSES[@]}"; do
  stage_bundle "$WORK/$os" "$os" "${UNIX_COMMON_PATHS[@]}" "os/$os"
  tar -czf "$OUT_DIR/$os.tar.gz" -C "$WORK/$os" dotfiles
  stamp_bootstrap "$os" "$OUT_DIR/$os.sh"
done

stage_bundle "$WORK/windows" "windows" "${WINDOWS_PATHS[@]}"
(cd "$WORK/windows" && zip -qrX "$OUT_DIR/windows.zip" dotfiles)

stamp_bootstrap "" "$OUT_DIR/install.sh"
sed -e "s|'https://clxrityy.github.io/dotfiles'|'$BASE_URL'|" \
    "$REPO_DIR/scripts/web/bootstrap.ps1" > "$OUT_DIR/install.ps1"

(
  cd "$OUT_DIR"
  for f in install.sh install.ps1 ./*.sh ./*.tar.gz windows.zip; do
    sha256_line "${f#./}"
  done | sort -u -k2 > SHA256SUMS
)

touch "$OUT_DIR/.nojekyll"

cat > "$OUT_DIR/index.html" << EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>clxrityy/dotfiles</title>
<style>
  :root { color-scheme: light dark; --bg: #ffffff; --fg: #1f2328; --muted: #59636e; --code: #f6f8fa; --border: #d1d9e0; }
  @media (prefers-color-scheme: dark) { :root { --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --code: #161b22; --border: #30363d; } }
  body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.6 system-ui, -apple-system, sans-serif; }
  main { max-width: 760px; margin: 0 auto; padding: 48px 16px; }
  h1 { font-size: 1.6rem; margin: 0 0 4px; }
  h2 { font-size: 1.05rem; margin: 32px 0 8px; }
  p, small { color: var(--muted); }
  pre { background: var(--code); border: 1px solid var(--border); border-radius: 8px; padding: 12px 14px; overflow-x: auto; font-size: 14px; }
  a { color: inherit; }
</style>
</head>
<body>
<main>
  <h1>~/.dotfiles</h1>
  <p>Clone-free bootstrap for <a href="https://github.com/clxrityy/dotfiles">clxrityy/dotfiles</a>. Each command downloads only that OS's bundle, verifies it against <a href="SHA256SUMS">SHA256SUMS</a>, extracts it to <code>~/.dotfiles</code> and runs the installer.</p>

  <h2>Auto-detect (macOS, Fedora, Rocky, Debian)</h2>
  <pre>curl -fsSL $BASE_URL/install.sh | bash</pre>

  <h2>Pick an OS / pass flags</h2>
  <pre>curl -fsSL $BASE_URL/macos.sh  | bash -s -- --dry-run --verbose
curl -fsSL $BASE_URL/fedora.sh | bash
curl -fsSL $BASE_URL/rocky.sh  | bash
curl -fsSL $BASE_URL/debian.sh | bash</pre>

  <h2>Windows 11 (elevated PowerShell)</h2>
  <pre>irm $BASE_URL/install.ps1 | iex
&amp; ([scriptblock]::Create((irm $BASE_URL/install.ps1))) -DryRun</pre>

  <h2>Read before you run</h2>
  <pre>curl -fsSL $BASE_URL/install.sh | less</pre>

  <small>Built from ${COMMIT} on ${BUILD_DATE}.</small>
</main>
</body>
</html>
EOF

printf 'Done. %s files in %s\n' "$(find "$OUT_DIR" -type f | wc -l | tr -d ' ')" "$OUT_DIR"
