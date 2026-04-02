#!/usr/bin/env bash
# scripts/tests/test_lint.sh -- ShellCheck and syntax validation

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

printf 'test_lint.sh\n'

# --- bash -n syntax check on all .sh files ---
while IFS= read -r -d '' file; do
  relative="${file#"$REPO_DIR"/}"
  assert_success "bash -n: $relative" bash -n "$file"
done < <(find "$REPO_DIR" -name '*.sh' -not -path '*/.git/*' -print0)

# --- ShellCheck (if available) ---
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' file; do
    relative="${file#"$REPO_DIR"/}"
    assert_success "shellcheck: $relative" shellcheck -S warning "$file"
  done < <(find "$REPO_DIR" -name '*.sh' -not -path '*/.git/*' -print0)
else
  printf '  [SKIP] shellcheck not installed\n'
fi

test_summary
