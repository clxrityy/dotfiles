#!/usr/bin/env bash
# scripts/tests/test_lint.sh -- ShellCheck and syntax validation

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

printf 'test_lint.sh\n'

if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' file; do
    relative="${file#"$REPO_DIR"/}"

    # Library files export globals consumed by sourcing scripts;
    # SC2034 (unused variable) is a false positive for them
    extra_args=()
    if [[ "$relative" == scripts/lib/* ]]; then
      extra_args=(--exclude=SC2034)
    fi

    assert_success "shellcheck: $relative" shellcheck -S warning "${extra_args[@]}" "$file"
  done < <(find "$REPO_DIR" -name '*.sh' -not -path '*/.git/*' -print0)
else
  printf '  [SKIP] shellcheck not installed\n'
fi


test_summary
