#!/usr/bin/env zsh
# Test: Bounded Levenshtein distance implementation
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/sources/typo.source.zsh"

# 1. _ghost_levenshtein_bounded: identical strings → 0
res0="$(_ghost_levenshtein_bounded "python" "python" 2)"
[[ $res0 -eq 0 ]] || { echo "FAIL: expected 0 for identical strings; got $res0"; exit 1; }

# 2. single substitution → 1
res1="$(_ghost_levenshtein_bounded "python" "pythnn" 2)"
[[ $res1 -eq 1 ]] || { echo "FAIL: expected 1 for single substitution; got $res1"; exit 1; }

# 3. single insertion → 1
res_ins="$(_ghost_levenshtein_bounded "pytho" "python" 2)"
[[ $res_ins -eq 1 ]] || { echo "FAIL: expected 1 for single insertion; got $res_ins"; exit 1; }

# 4. two substitutions → 2
res2="$(_ghost_levenshtein_bounded "pythno" "python" 2)"
[[ $res2 -eq 2 ]] || { echo "FAIL: expected 2 for two substitutions; got $res2"; exit 1; }

# 5. three substitutions → returns 3 (bounded)
res3="$(_ghost_levenshtein_bounded "pyxxxx" "python" 2)"
[[ $res3 -eq 3 ]] || { echo "FAIL: expected 3 (bounded max+1); got $res3"; exit 1; }

# 6. length diff > 2 → early exit with 3
res_diff="$(_ghost_levenshtein_bounded "py" "python" 2)"
[[ $res_diff -eq 3 ]] || { echo "FAIL: expected 3 for length difference > 2; got $res_diff"; exit 1; }

echo "ALL test_levenshtein PASSED"
