#!/usr/bin/env bash
# scripts/tests/test_config.sh -- Validate config file formats

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

printf 'test_config.sh\n'

# --- packages.conf format validation ---
# Every non-comment, non-blank line must match: name=scope or name=scope:target
packages_file="$REPO_DIR/packages.conf"

if [[ -f "$packages_file" ]]; then
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    # Strip inline comments, trim whitespace
    clean="${line%%#*}"
    clean="$(echo "$clean" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$clean" ]] && continue
    # Validate format
    if [[ "$clean" =~ ^[a-zA-Z0-9_-]+=([a-zA-Z0-9_-]+)(:.+)?$ ]]; then
      assert_eq "packages.conf:$line_num valid format" "valid" "valid"
    else
      assert_eq "packages.conf:$line_num valid format" "valid" "INVALID: $clean"
    fi
  done < "$packages_file"
else
  assert_eq "packages.conf exists" "exists" "missing"
fi

# --- Verify stow packages reference real directories ---
# This catches typos like "commn=all" where the dir doesn't exist
source "$LIB_DIR/packages.sh"
# shellcheck disable=SC2034
packages_conf_dir="$REPO_DIR/packages.conf"
load_packages_conf

i=0
# shellcheck disable=SC2154
while [[ $i -lt ${#packages_conf[@]} ]]; do
  name="${packages_conf[$i]}"
  pkg_dir="$REPO_DIR/$name"
  assert_success "package dir exists: $name" test -d "$pkg_dir"
  i=$((i + 3))  # Skip triplet (name, scope, target)
done

test_summary
