#!/usr/bin/env bash
# scripts/tests/test_stow.sh -- Tests for stow conflict parsing helpers

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
source "$LIB_DIR/run.sh"
source "$LIB_DIR/stow.sh"

printf 'test_stow.sh\n'

old_style_line='* cannot stow ../foo over existing target .bashrc since neither a link nor a directory'
new_style_line='* existing target is neither a link nor a directory: .bashrc'
other_new_style='* existing target is stowed to a different package: .config/starship.toml'

parsed_old="$(parse_stow_conflict_target "$old_style_line")"
parsed_new="$(parse_stow_conflict_target "$new_style_line")"
parsed_other="$(parse_stow_conflict_target "$other_new_style")"

assert_eq "parse old-style stow conflict" ".bashrc" "$parsed_old"
assert_eq "parse new-style stow conflict" ".bashrc" "$parsed_new"
assert_eq "parse alternate new-style stow conflict" ".config/starship.toml" "$parsed_other"
assert_failure "ignore non-conflict line" bash -lc "source '$LIB_DIR/run.sh'; source '$LIB_DIR/stow.sh'; parse_stow_conflict_target 'plain line without conflict'"

test_summary
