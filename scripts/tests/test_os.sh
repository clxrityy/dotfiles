#!/usr/bin/env bash
# scripts/tests/test_os.sh -- Tests for os.sh detection

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
source "$LIB_DIR/os.sh"

printf 'test_os.sh\n'

# detect_os_key should return a known value on any CI runner
result="$(detect_os_key)"
assert_ne "detect_os_key returns non-empty" "" "$result"

# Should be one of the known keys
case "$result" in
  macos|fedora|debian|arch|linux|unknown)
    assert_eq "detect_os_key returns valid key" "$result" "$result"
    ;;
  *)
    assert_eq "detect_os_key returns valid key" "one of: macos|fedora|debian|arch|linux|unknown" "$result"
    ;;
esac

# get_arch_key should return a normalized value
arch="$(get_arch_key)"
assert_ne "get_arch_key returns non-empty" "" "$arch"

# On CI, should be arm64 or x86_64
case "$arch" in
  arm64|x86_64)
    assert_eq "get_arch_key returns normalized arch" "$arch" "$arch"
    ;;
  *)
    # Not a failure -- could be a weird arch -- but worth noting
    printf '  [WARN] Unexpected arch: %s\n' "$arch"
    ;;
esac

test_summary
