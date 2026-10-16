#!/usr/bin/env zsh
# ziro-ghost — Matching Engine
# Layer: Engine · Spec: 009 v0.2.0 (FR-004) · Version: 0.3.0
# Provides prefix and fuzzy matching algorithms.

# Strict prefix matcher: candidate starts with query
ghost_match_prefix() {
  emulate -L zsh
  local query="$1"
  local cand="$2"

  [[ -z "$query" ]] && return 1
  [[ "$cand" == "$query"* ]] && return 0
  return 1
}

# Fuzzy matcher: candidate contains characters of query in order
ghost_match_fuzzy() {
  emulate -L zsh
  local query="$1"
  local cand="$2"

  [[ -z "$query" ]] && return 1

  # Construct glob pattern: *q*u*e*r*y*
  local pattern="*"
  local i
  for (( i = 1; i <= ${#query}; i++ )); do
    pattern+="${query[$i]}*"
  done

  [[ "$cand" == ${~pattern} ]] && return 0
  return 1
}

# Register matchers in IOP registry
if (( ${+functions[ghost_register_matcher]} )); then
  ghost_register_matcher prefix --intent "match candidates that start with query" --handler ghost_match_prefix
  ghost_register_matcher fuzzy  --intent "match candidates fuzzy in sequence"     --handler ghost_match_fuzzy
fi
