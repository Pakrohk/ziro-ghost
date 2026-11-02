#!/usr/bin/env zsh
# ziro-ghost — metrics recording and in-memory ring buffer (M8)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M8)

typeset -ga _GHOST_METRICS_BUFFER=()
typeset -g  _GHOST_METRICS_MAX_BUFFER=100
typeset -g  _GHOST_METRICS_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost/metrics.jsonl"
typeset -g  _GHOST_METRICS_MAX_FILE_LINES=10000
typeset -g  _GHOST_SESSION_ID=""
typeset -g  _GHOST_METRICS_DROP_COUNT=0
typeset -g  _GHOST_METRICS_INITIALIZED=0

_ghost_metrics_init() {
  emulate -L zsh
  [[ -z "$_GHOST_SESSION_ID" ]] && _GHOST_SESSION_ID="$$-${EPOCHSECONDS:-$(date +%s)}"

  local metrics_dir="${_GHOST_METRICS_FILE:h}"
  [[ -d "$metrics_dir" ]] || mkdir -p "$metrics_dir" 2>/dev/null || true
  chmod 700 "$metrics_dir" 2>/dev/null || true

  if [[ -f "$_GHOST_METRICS_FILE" ]]; then
    chmod 600 "$_GHOST_METRICS_FILE" 2>/dev/null || true
    # Rotate if too large
    local n=0
    n=$(wc -l < "$_GHOST_METRICS_FILE" 2>/dev/null || echo 0)
    if (( n > _GHOST_METRICS_MAX_FILE_LINES )); then
      tail -n "$_GHOST_METRICS_MAX_FILE_LINES" "$_GHOST_METRICS_FILE" > "${_GHOST_METRICS_FILE}.tmp" 2>/dev/null && \
        mv -f "${_GHOST_METRICS_FILE}.tmp" "$_GHOST_METRICS_FILE" 2>/dev/null || true
      chmod 600 "$_GHOST_METRICS_FILE" 2>/dev/null || true
    fi
  fi

  autoload -Uz add-zsh-hook 2>/dev/null || true
  if (( $+functions[add-zsh-hook] )); then
    add-zsh-hook precmd _ghost_metrics_flush 2>/dev/null || true
  fi

  _GHOST_METRICS_INITIALIZED=1
}

# Fast O(1) in-memory record — strictly zero file I/O on hot path
_ghost_metrics_record() {
  local line="{\"ts\":${EPOCHREALTIME:-0},\"intent_id\":\"${_GHOST_SESSION_ID}-${#_GHOST_METRICS_BUFFER}-${EPOCHREALTIME:-0}\",\"name\":\"$1\",\"level\":\"${2:-ephemeral}\",\"duration_ms\":${3:-0},\"status\":\"${4:-ok}\",\"source\":\"${5:-}\",\"cache_hit\":${6:-false},\"session\":\"$_GHOST_SESSION_ID\"}"
  if (( ${#_GHOST_METRICS_BUFFER} >= _GHOST_METRICS_MAX_BUFFER )); then
    shift _GHOST_METRICS_BUFFER
    (( ++_GHOST_METRICS_DROP_COUNT ))
  fi
  _GHOST_METRICS_BUFFER+=("$line")
}

# Precmd flush — batched I/O off the hot keystroke path
_ghost_metrics_flush() {
  emulate -L zsh
  (( ${#_GHOST_METRICS_BUFFER} == 0 )) && return 0

  local metrics_dir="${_GHOST_METRICS_FILE:h}"
  [[ -d "$metrics_dir" ]] || mkdir -p "$metrics_dir" 2>/dev/null || true

  print -rl -- "${_GHOST_METRICS_BUFFER[@]}" >> "$_GHOST_METRICS_FILE" 2>/dev/null || true
  chmod 600 "$_GHOST_METRICS_FILE" 2>/dev/null || true
  _GHOST_METRICS_BUFFER=()
}
