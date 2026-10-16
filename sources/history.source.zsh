#!/usr/bin/env zsh
# ziro-ghost — History Suggestion Source
# Layer: Sources · Spec: 009 v0.2.0 (FR-003, R14) · Version: 0.3.0
# Aggregates live and persistent shell history with kind tagging, mapfile, and disk caching.

# ─── Hoist standard modules (Spec 011 Cat 7) ───
zmodload zsh/mapfile 2>/dev/null || true

typeset -ga _ghost_history_cache
typeset -ga _ghost_results=()

# Load history entries into memory with mtime-based disk cache
ghost_history_load() {
  emulate -L zsh
  local hist_file="${HISTFILE:-$HOME/.zsh_history}"

  # 1. Prefer in-memory Zsh history array if running interactively
  if (( ${#history} > 0 )); then
    _ghost_history_cache=("${(@vu)history}")
    return 0
  fi

  [[ -r "$hist_file" ]] || return 0

  # 2. Check disk cache with mtime-based invalidation (Spec 011 Cat 13)
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
  local cache_file="$cache_dir/history-cache"

  if [[ -f "$cache_file" && ! "$hist_file" -nt "$cache_file" ]]; then
    _ghost_history_cache=(${(f)mapfile[$cache_file]})
    (( ${#_ghost_history_cache} > 0 )) && return 0
  fi

  # 3. Read history file via mapfile (Zero Fork — Spec 011 Cat 1 & Cat 11)
  local -a raw_lines=(${(f)mapfile[$hist_file]})
  local -a recent=("${raw_lines[-2000,-1]}")
  local line clean_line
  local -a cleaned=()

  for line in "${recent[@]}"; do
    # Strip zsh extended history timestamp format if present (: <timestamp>:<elapsed>;<cmd>)
    if [[ "$line" == ': <->:<->;'* ]]; then
      clean_line="${line#*:*;}"
    else
      clean_line="$line"
    fi
    [[ -n "$clean_line" ]] && cleaned+=("$clean_line")
  done

  _ghost_history_cache=("${(@u)cleaned}")

  # 4. Save to disk cache
  [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir" 2>/dev/null || true
  print -rl -- "${_ghost_history_cache[@]}" > "$cache_file" 2>/dev/null || true
}

# Invalidate cached history
ghost_history_cache_invalidate() {
  emulate -L zsh
  _ghost_history_cache=()
  local cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost/history-cache"
  rm -f "$cache_file" 2>/dev/null || true
}

# Query history source for matching commands
# Output format: weight:kind:text
ghost_history_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
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

  _ghost_results=("${results[@]}")
  print -rl -- "${results[@]}"
}

_ghost_history_query() {
  emulate -L zsh
  ghost_history_query "$@"
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
