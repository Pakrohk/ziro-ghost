#!/usr/bin/env zsh
# Test: Zoxide Suggestion Source
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"

tmp_zo="$(mktemp -d)"
export _ZO_DATA_DIR="$tmp_zo"
trap 'rm -rf "$tmp_zo"' EXIT

# Add test directories to zoxide database
mkdir -p "$tmp_zo/projects/alpha" "$tmp_zo/projects/beta"
zoxide add "$tmp_zo/projects/alpha"
zoxide add "$tmp_zo/projects/beta"

source "$ROOT_DIR/sources/zoxide.source.zsh"

# 1. zoxide source registered in IOP registry
meta="$(ghost_get_source zoxide)"
[[ -n "$meta" ]] || { echo "FAIL: zoxide source was not registered"; exit 1; }

# 2. weight = 15 as configured
[[ "$meta" == *"weight=15"* ]] || { echo "FAIL: weight mismatch; got '$meta'"; exit 1; }

# 3. kind = path
[[ "$meta" == *"kind=path"* ]] || { echo "FAIL: kind mismatch; got '$meta'"; exit 1; }

# 4. query returns cd targets from db matching term
_ghost_zoxide_query "cd alpha"
[[ ${#_ghost_results} -ge 1 ]] || { echo "FAIL: expected results for 'cd alpha'"; exit 1; }
sample="${_ghost_results[1]}"
[[ "$sample" == "15:path:cd "*"/projects/alpha" ]] || {
  echo "FAIL: unexpected suggestion format; got '$sample'"
  exit 1
}

# 5. non-matching query or non-cd query returns false
! _ghost_zoxide_query "git status" || { echo "FAIL: zoxide source should not trigger on git query"; exit 1; }

# 6. graceful skip if zoxide is missing
(
  path=()
  unfunction zoxide 2>/dev/null || true
  # Should return 0 cleanly without throwing
  source "$ROOT_DIR/sources/zoxide.source.zsh"
) || { echo "FAIL: source crashed when zoxide missing"; exit 1; }

echo "ALL test_zoxide_source PASSED"
