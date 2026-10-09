#!/usr/bin/env bash
# scripts/tests/test_lint.sh -- ShellCheck and syntax validation

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

printf 'test_lint.sh\n'

if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' relative; do
    [[ "$relative" == *.sh ]] || continue
    file="$REPO_DIR/$relative"

    # When files are moved or deleted in the working tree, `git ls-files`
    # can still report their tracked paths until the rename is staged.
    # Skip those missing paths so lint validates the current workspace state.
    if [[ ! -f "$file" ]]; then
      printf '  [SKIP] missing file: %s\n' "$relative"
      continue
    fi

    # Library files export globals consumed by sourcing scripts;
    # SC2034 (unused variable) is a false positive for them
    extra_args=()
    if [[ "$relative" == scripts/lib/* ]]; then
      extra_args=(--exclude=SC2034)
    fi

    assert_success "shellcheck: $relative" shellcheck -S warning "${extra_args[@]}" "$file"
  done < <(git -C "$REPO_DIR" ls-files -z)
else
  printf '  [SKIP] shellcheck not installed\n'
fi


test_summary
