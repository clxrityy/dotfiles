#!/usr/bin/env bash
# scripts/tests/test_pages.sh -- GitHub Pages bundle build + bootstrap

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

printf 'test_pages.sh\n'

if ! command -v zip >/dev/null 2>&1; then
  printf '  [SKIP] zip not installed\n'
  test_summary
  exit $?
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-pages.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/dist"

assert_success "build-pages.sh builds the site" \
  bash "$REPO_DIR/scripts/dev/build-pages.sh" --out "$OUT" --base-url "file://$WORK/dist"

for f in install.sh install.ps1 SHA256SUMS index.html .nojekyll windows.zip; do
  assert_success "dist has $f" test -f "$OUT/$f"
done

for os in macos fedora rocky debian; do
  listing="$(tar -tzf "$OUT/$os.tar.gz" 2>/dev/null)"
  assert_success "$os bundle has install.sh" grep -qx 'dotfiles/install.sh' <<< "$listing"
  assert_success "$os bundle has stow lib" grep -qx 'dotfiles/scripts/lib/stow.sh' <<< "$listing"
  assert_success "$os bundle has os/$os/install.sh" grep -qx "dotfiles/os/$os/install.sh" <<< "$listing"
  assert_failure "$os bundle excludes private/" grep -q '^dotfiles/private' <<< "$listing"
  assert_failure "$os bundle excludes other OSes" grep -Eq "^dotfiles/os/(macos|fedora|rocky|debian|windows)/" \
    <<< "$(grep -v "^dotfiles/os/$os/" <<< "$listing")"
  assert_eq "$os.sh pins the OS" "DEFAULT_OS=\"$os\"" "$(grep '^DEFAULT_OS=' "$OUT/$os.sh")"
done

assert_success "windows bundle has install.ps1" \
  bash -c "unzip -l '$OUT/windows.zip' | grep -q 'dotfiles/os/windows/install.ps1'"

if command -v sha256sum >/dev/null 2>&1; then
  assert_success "SHA256SUMS verifies" bash -c "cd '$OUT' && sha256sum -c --quiet SHA256SUMS"
else
  assert_success "SHA256SUMS verifies" bash -c "cd '$OUT' && shasum -a 256 -c --quiet SHA256SUMS"
fi

# Bootstrap end-to-end over file:// (curl supports it), download/extract only.
if command -v curl >/dev/null 2>&1; then
  dest="$WORK/home/.dotfiles"
  assert_success "bootstrap extracts debian bundle" \
    bash "$OUT/debian.sh" --dir "$dest" --no-install
  assert_success "extracted bundle has debian installer" test -f "$dest/os/debian/install.sh"

  mkdir -p "$WORK/gitco/.git"
  assert_failure "bootstrap refuses a git checkout" \
    bash "$OUT/debian.sh" --dir "$WORK/gitco" --no-install
fi

test_summary
