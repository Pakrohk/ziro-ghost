#!/usr/bin/env zsh
# ziro-ghost — Ranking & Comparator Engine
# Layer: Engine · Spec: 009 v0.2.0 (R14) · Version: 0.3.0
# Computes suggestion rankings using source weights, length penalty, and contextual kind bias.

typeset -ga _ghost_ranked=()

# Score a candidate: weight + length penalty + kind bias
ghost_score_candidate() {
  emulate -L zsh
  local cand="$1"
  local weight="${2:-10}"
  local kind="${3:-cmd}"

  local score=$weight

  # Shorter completions typically preferred for exact typing
  local len=${#cand}
  (( len < 30 )) && (( score += 5 ))

  # Contextual kind bias
  case "$kind" in
    git)
      (( score += 2 ))
      # Context-aware: higher git bias if inside a git worktree
      [[ -d .git || -f .git ]] && (( score += 3 ))
      ;;
    project)
      (( score += 3 ))
      ;;
    history)
      (( score += 1 ))
      ;;
  esac

  REPLY=$score
  print -r -- "$score"
}

# Rank array of "weight:kind:text" lines descending via pure Zsh
ghost_rank_candidates() {
  emulate -L zsh
  local lines=("$@")
  _ghost_ranked=()
  (( ${#lines} == 0 )) && return 0

  local -a scored=()
  local line weight rest kind text
  for line in "${lines[@]}"; do
    weight="${line%%:*}"
    rest="${line#*:}"
    kind="${rest%%:*}"
    text="${rest#*:}"

    ghost_score_candidate "$text" "$weight" "$kind" >/dev/null
    scored+=("${REPLY}:${kind}:${text}")
  done

  # Pure Zsh numerical sort descending — Spec 011 Cat 5
  _ghost_ranked=("${(@On)scored}")
  print -rl -- "${_ghost_ranked[@]}"
}

# Register comparator in IOP registry
if (( ${+functions[ghost_register_comparator]} )); then
  ghost_register_comparator standard \
    --intent "rank candidates by source weight, length, and contextual kind bias" \
    --handler ghost_rank_candidates
fi
