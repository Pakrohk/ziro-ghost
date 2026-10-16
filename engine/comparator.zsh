#!/usr/bin/env zsh
# ziro-ghost — Ranking & Comparator Engine
# Layer: Engine · Spec: 009 v0.2.0 (R14) · Version: 0.2.0
# Computes suggestion rankings using source weights and recency.

# Score a candidate: weight + length penalty + kind bias
ghost_score_candidate() {
  local cand="$1"
  local weight="${2:-10}"
  local kind="${3:-cmd}"

  local score=$weight

  # Shorter completions typically preferred for exact typing
  local len=${#cand}
  if (( len < 30 )); then
    (( score += 5 ))
  fi

  # Kind bias
  case "$kind" in
    git)     (( score += 2 )) ;;
    project) (( score += 3 )) ;;
    history) (( score += 1 )) ;;
  esac

  print -r -- "$score"
}

# Rank array of "score:kind:text" lines descending
ghost_rank_candidates() {
  local lines=("$@")
  (( ${#lines} == 0 )) && return 0

  # Sort numerically descending by score
  print -rl -- "${lines[@]}" | sort -t: -k1,1nr
}

# Register comparator in IOP registry
if (( ${+functions[ghost_register_comparator]} )); then
  ghost_register_comparator standard \
    --intent "rank candidates by source weight and contextual bias" \
    --handler ghost_rank_candidates
fi
