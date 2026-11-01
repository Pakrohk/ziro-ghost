#!/usr/bin/env zsh
# ziro-ghost — History Suggestion Source
# Layer: Sources · Spec: 009 v0.2.0 (FR-003, R14)
# Aggregates live and persistent shell history with kind tagging, mapfile, and disk caching.

# ─── Hoist standard modules (Spec 011 Cat 7) ───
zmodload zsh/mapfile 2>/dev/null || true
zmodload zsh/parameter 2>/dev/null || true

typeset -ga _ghost_history_cache=()
typeset -ga _ghost_results=()
typeset -g _ghost_histfile_mtime=0
typeset -g _ghost_histfile_last_check=0

# Ensure cached history reflects any changes to HISTFILE (cross-terminal sync)
ghost_history_ensure_fresh() {
  emulate -L zsh
  # Fast path: in-memory cache is already warm (zero fork, zero lag on keystroke)
  (( ${#_ghost_history_cache} > 0 )) && return 0
  ghost_history_load
}

# --- Secret filter (spec 016 R1-R4, v1.0.5) ---
ghost_history_is_sensitive() {
  emulate -L zsh
  setopt extendedglob
  local line="$1"
  [[ -z "$line" ]] && return 1

  # R2: skip lines starting with space (HIST_IGNORE_SPACE)
  [[ "$line" == [[:space:]]* ]] && return 0

  # R3: skip lines > 500 chars
  (( ${#line} > 500 )) && return 0

  # R4: skip lines with 40+ consecutive alphanumeric (likely base64/hex secrets)
  [[ "$line" == *[A-Za-z0-9](#c40,)* ]] && return 0

  # R1: check against known secret patterns
  local -a secret_patterns=(
    "*(--password|--passwd|--token|--secret*|--api[-_]key|--auth*|--passphrase)([= ]*|)*"
    "*(#i)authorization:[[:space:]]#(bearer|basic)*"
    "*-p[^[:space:]]*"
    "*(#i)(passphrase|passout|passin|credential)*"
    "*(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9](#c36)*"
    "*AKIA[0-9A-Z](#c16)*"
    "*sk-[A-Za-z0-9_-](#c20,)*"
    "*xox[bp]-[A-Za-z0-9-](#c10,)*"
    "*(#i)BEGIN*(private key|rsa private key|openssh private key)*"
    "*(id_rsa|id_ed25519|id_ecdsa|id_dsa)*"
    "*://*:[^/@[:space:]]##@*"
  )

  local pat
  for pat in "${secret_patterns[@]}"; do
    if [[ "$line" == $~pat ]]; then
      return 0
    fi
  done

  return 1
}

# Save cache to disk with filter + permissions (spec 016 R1-R6, v1.0.5)
ghost_history_save() {
  emulate -L zsh
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
  local cache_file="${GHOST_CACHE_FILE:-$cache_dir/history-cache}"
  local dir="${cache_file:h}"

  [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null || true
  chmod 700 "$dir" 2>/dev/null || true

  local line
  local -a filtered=()
  for line in "${_ghost_history_cache[@]}"; do
    ghost_history_is_sensitive "$line" || filtered+=("$line")
  done

  if (( ${#filtered} > 0 )); then
    print -rl -- "${filtered[@]}" > "$cache_file" 2>/dev/null || true
  else
    : > "$cache_file" 2>/dev/null || true
  fi
  chmod 600 "$cache_file" 2>/dev/null || true
}

# Append last command to cache immediately (same-terminal instant sync, per-command filter)
ghost_history_append_last() {
  emulate -L zsh
  local raw_last
  raw_last=$(fc -ln -1 2>/dev/null) || return 0
  # Filter single sensitive command before adding to cache (0.05ms)
  ghost_history_is_sensitive "$raw_last" && return 0

  local last="${raw_last##[[:space:]]#}"
  [[ -z "$last" ]] && return 0
  ghost_history_is_sensitive "$last" && return 0
  [[ "${_ghost_history_cache[1]}" == "$last" ]] && return 0
  _ghost_history_cache=("$last" "${_ghost_history_cache[@]}")

  # Persist clean command to history-cache file (0.1ms append)
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
  local cache_file="${GHOST_CACHE_FILE:-$cache_dir/history-cache}"
  if [[ -f "$cache_file" ]]; then
    print -r -- "$last" >> "$cache_file" 2>/dev/null || true
  fi
}

# Load history entries into memory with fast pre-filtered disk cache
ghost_history_load() {
  emulate -L zsh
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
  local cache_file="${GHOST_CACHE_FILE:-$cache_dir/history-cache}"

  # 1. Fast path: load pre-filtered disk cache directly (0.5ms, zero filter overhead)
  if [[ -r "$cache_file" ]]; then
    local -a cached_lines=(${(f)mapfile[$cache_file]})
    if (( ${#cached_lines} > 0 )); then
      _ghost_history_cache=("${(@u)cached_lines}")
      return 0
    fi
  fi

  # 2. Cold fallback: First-time boot when no disk cache exists yet
  local hist_file="${HISTFILE:-$HOME/.zsh_history}"
  local -a cleaned=()
  local line clean_line

  # Prefer in-memory Zsh history array if running interactively
  if (( ${+history} && ${#history} > 0 )); then
    local -a keys=(${(Onk)history})
    local k
    for k in "${(@)keys[1,2000]}"; do
      [[ -n "${history[$k]}" ]] && cleaned+=("${history[$k]}")
    done
  fi

  # Also load persistent history file if accessible
  if [[ -r "$hist_file" ]]; then
    local -a raw_lines=(${(f)mapfile[$hist_file]})
    local -i n_lines=${#raw_lines}
    local -i start_idx=$(( n_lines > 2000 ? n_lines - 1999 : 1 ))
    local -a recent=(${raw_lines[start_idx,-1]})
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

  # 3. Save initial sanitized cache to disk
  ghost_history_save
}

# Invalidate cached history (memory only; keeps clean disk cache intact)
ghost_history_cache_invalidate() {
  emulate -L zsh
  _ghost_history_cache=()
}

# Query history source for matching commands
# Output format: weight:kind:text
ghost_history_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  [[ -z "$query" ]] && return 0

  ghost_history_ensure_fresh
  if (( ${#_ghost_history_cache} == 0 )); then
    ghost_history_load
  fi

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

# Precmd hook for instant same-terminal history caching
autoload -Uz add-zsh-hook 2>/dev/null
if (( ${+functions[add-zsh-hook]} )); then
  add-zsh-hook precmd ghost_history_append_last 2>/dev/null
fi
