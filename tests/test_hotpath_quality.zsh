#!/usr/bin/env zsh
# Test: Hot-path Quality & Spec 011 Compliance
set -euo pipefail

ROOT_DIR="${0:A:h:h}"

# 1. zmodload is present at top of ghost.plugin.zsh
head_content="$(head -20 "$ROOT_DIR/ghost.plugin.zsh")"
[[ "$head_content" == *"zmodload zsh/datetime"* ]] || {
  echo "FAIL: zmodload zsh/datetime missing from top of ghost.plugin.zsh"
  exit 1
}

# 2. Check that functions have emulate -L zsh
emulate_count=$(grep -rn 'emulate -L zsh' "$ROOT_DIR"/core/*.zsh "$ROOT_DIR"/ui/*.zsh "$ROOT_DIR"/sources/*.zsh | wc -l)
[[ $emulate_count -ge 8 ]] || {
  echo "FAIL: expected at least 8 emulate -L zsh declarations; found $emulate_count"
  exit 1
}

# 3. Static check: zero forbidden forks/commands in core files (Spec 011 S6)
# Files on hot path: ghost.plugin.zsh, core/ghost-core.zsh, ui/inline.ui.zsh
forbidden_found=$(grep -nE '\bcat\b|\bgrep\b|\bsed\b|\bawk\b|\bdate \+' \
  "$ROOT_DIR/ghost.plugin.zsh" \
  "$ROOT_DIR/core/ghost-core.zsh" \
  "$ROOT_DIR/ui/inline.ui.zsh" || true)

if [[ -n "$forbidden_found" ]]; then
  echo "FAIL: Forbidden fork pattern detected in hot path:"
  echo "$forbidden_found"
  exit 1
fi

echo "ALL test_hotpath_quality PASSED"
