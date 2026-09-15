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
not_owned_line='* existing target is not owned by stow: .zshrc'

parsed_old="$(parse_stow_conflict_target "$old_style_line")"
parsed_new="$(parse_stow_conflict_target "$new_style_line")"
parsed_other="$(parse_stow_conflict_target "$other_new_style")"
parsed_not_owned="$(parse_stow_conflict_target "$not_owned_line")"

assert_eq "parse old-style stow conflict" ".bashrc" "$parsed_old"
assert_eq "parse new-style stow conflict" ".bashrc" "$parsed_new"
assert_eq "parse alternate new-style stow conflict" ".config/starship.toml" "$parsed_other"
assert_eq "parse not-owned-by-stow conflict" ".zshrc" "$parsed_not_owned"
assert_failure "ignore non-conflict line" bash -lc "source '$LIB_DIR/run.sh'; source '$LIB_DIR/stow.sh'; parse_stow_conflict_target 'plain line without conflict'"

# --- dangling symlink cleanup ---

tmp_dir="$(mktemp -d)"
stow_dir="$tmp_dir/os"
stow_target="$tmp_dir/target"
backup_dir="$tmp_dir/backup"
mkdir -p "$stow_dir/macos" "$stow_target" "$backup_dir"
ln -s "$stow_dir/macos/.zshrc" "$stow_target/.zshrc"

stow_calls=()

stow() {
	cat <<'EOF'
* existing target is not owned by stow: .zshrc
EOF
	return 1
}

run_cmd() {
	stow_calls+=("$*")
	"$@"
}

backup_stow_conflicts "$stow_dir" "macos" "$stow_target" "$backup_dir"

assert_eq "dangling symlink removed" "no entry" "$(test -e "$stow_target/.zshrc" && printf 'entry' || printf 'no entry')"
assert_eq "dangling symlink cleanup uses rm" "rm $stow_target/.zshrc" "${stow_calls[0]}"

test_summary
