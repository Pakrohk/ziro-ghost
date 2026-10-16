#!/usr/bin/env zsh
# Test: Typo correction suggestion source
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"
source "$ROOT_DIR/sources/typo.source.zsh"

# 1. typo source registered with fallback-only flag
sources=($(ghost_list_sources))
[[ "${sources[(r)typo]}" == "typo" ]] || { echo "FAIL: typo source not in registry"; exit 1; }

meta="$(ghost_get_source typo)"
[[ "$meta" == *"weight=5"* ]] || { echo "FAIL: weight mismatch in meta; got '$meta'"; exit 1; }
[[ "$meta" == *"kind=typo"* ]] || { echo "FAIL: kind mismatch in meta; got '$meta'"; exit 1; }
[[ "$meta" == *"fallback_only=1"* ]] || { echo "FAIL: fallback_only flag not set; got '$meta'"; exit 1; }

# 2. static map: sdu → sudo
ghost_typo_query "sdu" >/dev/null
[[ ${#_ghost_results} -gt 0 ]] || { echo "FAIL: sdu did not produce typo suggestions"; exit 1; }
[[ "${_ghost_results[1]}" == "5:typo:sudo" ]] || { echo "FAIL: sdu expected 5:typo:sudo; got '${_ghost_results[1]}'"; exit 1; }

# 3. static map: gti → git
ghost_typo_query "gti" >/dev/null
[[ ${#_ghost_results} -gt 0 ]] || { echo "FAIL: gti did not produce typo suggestions"; exit 1; }
[[ "${_ghost_results[1]}" == "5:typo:git" ]] || { echo "FAIL: gti expected 5:typo:git; got '${_ghost_results[1]}'"; exit 1; }

# 4. transposition: gti → git (algorithmic check)
_ghost_is_transposition "gti" "git" || { echo "FAIL: algorithmic transposition failed for gti -> git"; exit 1; }

# 5. keyboard-distance: sl → ls
_ghost_is_transposition "sl" "ls" || { echo "FAIL: transposition failed for sl -> ls"; exit 1; }
ghost_typo_query "sl" >/dev/null
[[ "${_ghost_results[1]}" == "5:typo:ls" ]] || { echo "FAIL: sl expected 5:typo:ls; got '${_ghost_results[1]}'"; exit 1; }

# 6. Levenshtein: pythno → python (distance 2)
dist="$(_ghost_levenshtein_bounded "pythno" "python" 2)"
[[ $dist -le 2 ]] || { echo "FAIL: pythno distance to python should be <= 2; got $dist"; exit 1; }
ghost_typo_query "pythno" >/dev/null
found_python=0
for item in "${_ghost_results[@]}"; do
  [[ "$item" == *"python"* ]] && found_python=1
done
[[ $found_python -eq 1 ]] || { echo "FAIL: python not found in typo results for pythno"; exit 1; }

# 7. no match for random string → returns 1
if ghost_typo_query "xyz999_completely_impossible_random_cmd" >/dev/null 2>&1; then
  [[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: random string should have 0 results; got ${_ghost_results[*]}"; exit 1; }
fi

# 8. confidence threshold respected: disabled mode turns off typo
_ghost_config_cache[correction.enabled]="false"
if ghost_typo_query "sdu" >/dev/null 2>&1; then
  [[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: disabled correction should return nothing; got ${_ghost_results[*]}"; exit 1; }
fi
_ghost_config_cache[correction.enabled]="true"

echo "ALL test_typo_source PASSED"
