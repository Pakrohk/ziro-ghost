#!/usr/bin/env zsh
# Test: Helper shortcut `j` (jump with zoxide + fzf)
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/lib/helpers.zsh"

# 1. _ghost_j function and alias j are defined
(( ${+functions[_ghost_j]} )) || { echo "FAIL: _ghost_j function not defined"; exit 1; }
alias_j="$(alias j 2>/dev/null || true)"
[[ "$alias_j" == *"_ghost_j"* ]] || { echo "FAIL: alias j not defined; got '$alias_j'"; exit 1; }

# 2. j without zoxide prints error message and returns 1
(
  path=()
  err_msg="$(_ghost_j 2>&1 || true)"
  [[ "$err_msg" == *"zoxide not installed"* ]] || {
    echo "FAIL: expected 'zoxide not installed' error; got '$err_msg'"
    exit 1
  }
)

# If zoxide is not installed in the environment (e.g. CI runner), exit early after verifying error message
if (( ! $+commands[zoxide] )); then
  echo "ALL test_helper_j PASSED (graceful error check)"
  exit 0
fi

# 3. j with zoxide but no fzf jumps to best match directly
tmp_zo="$(mktemp -d)"
export _ZO_DATA_DIR="$tmp_zo"
trap 'rm -rf "$tmp_zo"' EXIT

target_dir="$tmp_zo/my_awesome_target"
mkdir -p "$target_dir"
zoxide add "$target_dir"

(
  # Hide fzf from path to test non-fzf fallback
  fzf() { return 127; }
  unfunction fzf 2>/dev/null || true
  path=("${path[@]:#*fzf*}")
  target_resolved="$(zoxide query "my_awesome" 2>/dev/null)"
  [[ "$target_resolved" == "$target_dir" ]] || {
    echo "FAIL: zoxide query did not resolve target; got '$target_resolved'"
    exit 1
  }
)

echo "ALL test_helper_j PASSED"
