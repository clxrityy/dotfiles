#!/usr/bin/env bash
# scripts/tests/test_packages.sh -- Tests for packages.sh parsing

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
source "$LIB_DIR/packages.sh"

printf 'test_packages.sh\n'

# --- trim ---

assert_eq "trim strips leading spaces" "hello" "$(trim "   hello")"
assert_eq "trim strips trailing spaces" "hello" "$(trim "hello   ")"
assert_eq "trim strips both sides" "hello" "$(trim "  hello  ")"
assert_eq "trim handles no whitespace" "hello" "$(trim "hello")"

# --- load_packages_conf with fixture ---

# Override the config path to use a test fixture
# shellcheck disable=SC2034
packages_conf_dir="$(dirname "${BASH_SOURCE[0]}")/fixtures/packages_valid.conf"
load_packages_conf

# packages_conf is a flat triplet array: (name, scope, target) x N
# So element count should be 3x the number of entries
# shellcheck disable=SC2154
assert_ne "packages_conf is not empty" "0" "${#packages_conf[@]}"

# First entry should be the first non-comment, non-blank line from fixture
assert_eq "first package name" "common" "${packages_conf[0]}"
assert_eq "first package scope" "all" "${packages_conf[1]}"
assert_eq "first package target (empty = default)" "" "${packages_conf[2]}"

test_summary
