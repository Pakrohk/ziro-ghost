#!/usr/bin/env zsh
# Test: Pure-Zsh Comparator & Kind-Bias
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/engine/comparator.zsh"

# 1. ghost_score_candidate calculates score with length penalty and kind bias
score_short="$(ghost_score_candidate "ls -la" 10 history)"
# 10 + 5 (len < 30) + 1 (history) = 16
[[ $score_short -eq 16 ]] || { echo "FAIL: expected score 16; got $score_short"; exit 1; }

score_long="$(ghost_score_candidate "very_long_command_that_exceeds_thirty_chars" 10 cmd)"
# 10 + 0 = 10
[[ $score_long -eq 10 ]] || { echo "FAIL: expected score 10; got $score_long"; exit 1; }

# 2. Contextual kind-bias in git repo
# ROOT_DIR is inside a git repo (Pakrohk/ziro-ghost)
score_git="$(ghost_score_candidate "git status" 10 git)"
# 10 + 5 (len < 30) + 2 (git) + 3 (inside git repo) = 20
[[ $score_git -ge 17 ]] || { echo "FAIL: git score should have kind bias; got $score_git"; exit 1; }

# 3. ghost_rank_candidates ranks using pure Zsh without external sort
items=("10:cmd:echo hello" "10:history:ls" "10:git:git status")
ghost_rank_candidates "${items[@]}" >/dev/null

[[ ${#_ghost_ranked} -eq 3 ]] || { echo "FAIL: expected 3 ranked items"; exit 1; }
# Top item should be git due to higher contextual score
top="${_ghost_ranked[1]}"
[[ "$top" == *":git:git status" ]] || { echo "FAIL: top item expected git status; got '$top'"; exit 1; }

echo "ALL test_comparator PASSED"
