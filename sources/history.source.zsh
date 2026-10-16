#!/usr/bin/env zsh
# ziro-ghost — History Suggestion Source
# Layer: Sources · Spec: 009 v0.2.0 (FR-003, R14)
# Aggregates live and persistent shell history with kind tagging, mapfile, and disk caching.

# ─── Hoist standard modules (Spec 011 Cat 7) ───
zmodload zsh/mapfile 2>/dev/null || true
zmodload zsh/parameter 2>/dev/null || true

typeset -ga _ghost_history_cache=()
typeset -ga _ghost_results=()

# Load history entries into memory with mtime-based disk cache
ghost_history_load() {
  emulate -L zsh
  local hist_file="${HISTFILE:-$HOME/.zsh_history}"

  local -a cleaned=()
  local line clean_line

  # 1. Prefer in-memory Zsh history array if running interactively
  if (( ${+history} && ${#history} > 0 )); then
    local -a keys=(${(Onk)history})
    local k
    for k in "${(@)keys[1,2000]}"; do
      [[ -n "${history[$k]}" ]] && cleaned+=("${history[$k]}")
    done
  fi

  # 2. Also load persistent history file if accessible
  if [[ -r "$hist_file" ]]; then
    local -a raw_lines=(${(f)mapfile[$hist_file]})
    local -a recent=(${raw_lines[-2000,-1]})
    local -i i

    for (( i = ${#recent}; i >= 1; i-- )); do
      line="${recent[i]}"
      # Strip zsh extended history timestamp format if present (: <timestamp>:<elapsed>;<cmd>)
      if [[ "$line" == ": "*";"* ]]; then
        clean_line="${line#*:*;}"
      else
        clean_line="$line"
      fi
      [[ -n "$clean_line" ]] && cleaned+=("$clean_line")
    done
  fi

  _ghost_history_cache=("${(@u)cleaned}")

  # 3. Save to disk cache
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
  local cache_file="$cache_dir/history-cache"
  if (( ${#_ghost_history_cache} > 0 )); then
    [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir" 2>/dev/null || true
    print -rl -- "${_ghost_history_cache[@]}" > "$cache_file" 2>/dev/null || true
  fi
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
}

_ghost_history_query() {
  emulate -L zsh
  ghost_history_query "$@"
}

_ghost_source_history() {
  emulate -L zsh
  ghost_history_query "$@"
}

# Register history source in IOP registry
if (( ${+functions[ghost_register_source]} )); then
  ghost_register_source history \
    --intent "provide history-based suggestions" \
    --handler _ghost_source_history \
    --weight 40 \
    --kind history \
    --enabled true
fi
