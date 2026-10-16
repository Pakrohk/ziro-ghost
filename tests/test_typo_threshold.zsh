#!/usr/bin/env zsh
# Test: Typo source thresholds and query length guards (TF-1..TF-4)
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"
source "$ROOT_DIR/sources/typo.source.zsh"

# Case 1: Single char 'z' -> 0 results
_ghost_typo_query "z" 2>/dev/null || true
[[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: 'z' should yield 0 results; got ${_ghost_results[*]}"; exit 1; }

# Case 2: 2-char unrelated 'zu' -> 0 results
_ghost_typo_query "zu" 2>/dev/null || true
[[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: 'zu' should yield 0 results; got ${_ghost_results[*]}"; exit 1; }

# Case 3: 3-char unrelated 'zuo' -> 0 results
_ghost_typo_query "zuo" 2>/dev/null || true
[[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: 'zuo' should yield 0 results; got ${_ghost_results[*]}"; exit 1; }

# Case 4: Static map typo 'sdu' -> sudo (1 result)
_ghost_typo_query "sdu" 2>/dev/null || true
[[ ${#_ghost_results} -eq 1 ]] || { echo "FAIL: 'sdu' should yield 1 result; got ${#_ghost_results}"; exit 1; }
[[ "${_ghost_results[1]}" == "5:typo:sudo" ]] || { echo "FAIL: 'sdu' expected 5:typo:sudo; got ${_ghost_results[1]}"; exit 1; }

# Case 5: Static map typo 'gti' -> git (1 result)
_ghost_typo_query "gti" 2>/dev/null || true
[[ ${#_ghost_results} -eq 1 ]] || { echo "FAIL: 'gti' should yield 1 result; got ${#_ghost_results}"; exit 1; }
[[ "${_ghost_results[1]}" == "5:typo:git" ]] || { echo "FAIL: 'gti' expected 5:typo:git; got ${_ghost_results[1]}"; exit 1; }

# Case 6: Algorithmic typo 'dokcer' -> docker (1 result)
_ghost_typo_query "dokcer" 2>/dev/null || true
[[ ${#_ghost_results} -eq 1 ]] || { echo "FAIL: 'dokcer' should yield 1 result; got ${#_ghost_results}"; exit 1; }
[[ "${_ghost_results[1]}" == "5:typo:docker" ]] || { echo "FAIL: 'dokcer' expected 5:typo:docker; got ${_ghost_results[1]}"; exit 1; }

# Case 7: Valid command 'git' -> 0 typo results
_ghost_typo_query "git" 2>/dev/null || true
[[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: valid command 'git' should yield 0 typo results; got ${_ghost_results[*]}"; exit 1; }

echo "ALL test_typo_threshold PASSED"
