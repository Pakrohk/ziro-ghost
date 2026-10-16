#!/usr/bin/env zsh
# ziro-ghost — History Suggestion Source
# Layer: Sources · Spec: 009 v0.2.0 (FR-003, R14) · Version: 0.2.0
# Aggregates live and persistent shell history with kind tagging.

typeset -ga _ghost_history_cache

# Load history entries into memory
ghost_history_load() {
  local hist_file="${HISTFILE:-$HOME/.zsh_history}"

  # Prefer in-memory Zsh history array if populated
  if (( ${#history} > 0 )); then
    _ghost_history_cache=("${(@vu)history}")
    return 0
  fi

  if [[ -r "$hist_file" ]]; then
    # Read unique lines from file
    _ghost_history_cache=(${(f)"$(cat "$hist_file" 2>/dev/null | tail -n 2000)"})
  fi
}

# Invalidate cached history
ghost_history_cache_invalidate() {
  _ghost_history_cache=()
}

# Query history source for matching commands
# Output format: score:kind:text
ghost_history_query() {
  local query="$1"
  [[ -z "$query" ]] && return 0

  (( ${#_ghost_history_cache} == 0 )) && ghost_history_load

  local results=()
  local item count=0
  for item in "${_ghost_history_cache[@]}"; do
    # Skip exact match or empty
    [[ "$item" == "$query" || -z "$item" ]] && continue

    # Check prefix match first
    if (( ${+functions[ghost_match_prefix]} )); then
      if ghost_match_prefix "$query" "$item"; then
        results+=("40:history:$item")
        (( ++count >= 20 )) && break
      fi
    elif [[ "$item" == "$query"* ]]; then
      results+=("40:history:$item")
      (( ++count >= 20 )) && break
    fi
  done

  print -rl -- "${results[@]}"
}

# Register history source in IOP registry
if (( ${+functions[ghost_register_source]} )); then
  ghost_register_source history \
    --intent "provide history-based suggestions" \
    --handler ghost_history_query \
    --weight 40 \
    --kind history \
    --enabled true
fi
