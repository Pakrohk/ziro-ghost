# ziro-ghost v2.0.0 — Unified Source Registry (M6: Everything-Async)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M6)
# Manages async cache-based sources. Keystroke suggestion is a pure memory read (<1ms).

zmodload zsh/datetime 2>/dev/null || true

typeset -gA _GHOST_SOURCE_CACHE=()
typeset -gA _GHOST_SOURCE_PRIORITY=()
typeset -gA _GHOST_SOURCE_ENABLED=()
typeset -gA _GHOST_SOURCE_REFRESH_FN=()
typeset -ga _GHOST_SOURCE_SORTED=()
typeset -g  _GHOST_SUGGEST_BUDGET_MS=1.0
typeset -gF _GHOST_SUGGEST_ELAPSED=0.0

_ghost_source_sort() {
  emulate -L zsh
  local -a pairs=()
  local s p
  for s in "${(@k)_GHOST_SOURCE_PRIORITY}"; do
    p="${_GHOST_SOURCE_PRIORITY[$s]:-0}"
    pairs+=("${(l:5::0:)p}:$s")
  done
  pairs=(${(On)pairs})
  _GHOST_SOURCE_SORTED=()
  for p in "${pairs[@]}"; do
    _GHOST_SOURCE_SORTED+=("${p#*:}")
  done
}

_ghost_source_register() {
  emulate -L zsh
  local name="$1"
  local priority="${2:-50}"
  local refresh_fn="${3:-}"

  [[ -z "$name" ]] && return 1

  _GHOST_SOURCE_CACHE[$name]="${_GHOST_SOURCE_CACHE[$name]:-}"
  _GHOST_SOURCE_PRIORITY[$name]=$priority

  local env_var="ZIRO_GHOST_SOURCE_${(U)name}"
  if (( ${+parameters[$env_var]} )); then
    _GHOST_SOURCE_ENABLED[$name]="${(P)env_var}"
  else
    _GHOST_SOURCE_ENABLED[$name]=1
  fi

  _GHOST_SOURCE_REFRESH_FN[$name]="$refresh_fn"
  _ghost_source_sort
}

_ghost_source_refresh() {
  emulate -L zsh
  local name="$1"
  [[ -z "$name" ]] && return 0

  local env_var="ZIRO_GHOST_SOURCE_${(U)name}"
  if (( ${+parameters[$env_var]} )) && [[ "${(P)env_var}" == "0" ]]; then
    return 0
  fi
  [[ "${_GHOST_SOURCE_ENABLED[$name]:-1}" == "0" ]] && return 0

  local fn="${_GHOST_SOURCE_REFRESH_FN[$name]:-}"
  [[ -z "$fn" || ! $+functions[$fn] ]] && return 0

  local out
  out="$("$fn" 2>/dev/null)" || true
  _GHOST_SOURCE_CACHE[$name]="$out"
  typeset -ga "_GHOST_SOURCE_LINES_${name}"
  set -A "_GHOST_SOURCE_LINES_${name}" ${(f)out}
}

_ghost_source_refresh_all() {
  emulate -L zsh
  local name
  for name in "${(@k)_GHOST_SOURCE_REFRESH_FN}"; do
    _ghost_source_refresh "$name"
  done
}

_ghost_source_dispatch_sync() {
  emulate -L zsh
  local query="$1"
  local silent="${2:-0}"
  _ghost_results=()

  [[ -z "$query" ]] && return 0

  local t0=${EPOCHREALTIME:-0}
  local -a raw_matches=()
  local name arr_var

  for name in "${_GHOST_SOURCE_SORTED[@]}"; do
    local env_var="ZIRO_GHOST_SOURCE_${(U)name}"
    if (( ${+parameters[$env_var]} )) && [[ "${(P)env_var}" == "0" ]]; then
      continue
    fi
    [[ "${_GHOST_SOURCE_ENABLED[$name]:-1}" == "0" ]] && continue

    arr_var="_GHOST_SOURCE_LINES_${name}"
    if (( ${+parameters[$arr_var]} )); then
      local -a m=(${(M)${(P)arr_var}:#${query}*})
      m=(${m:#$query})
      if (( ${#m} > 0 )); then
        raw_matches+=("${(@)m[1,10]}")
        (( ${#raw_matches} >= 10 )) && break
      fi
    elif [[ -n "${_GHOST_SOURCE_CACHE[$name]:-}" ]]; then
      local -a m=(${(M)${(f)_GHOST_SOURCE_CACHE[$name]}:#${query}*})
      m=(${m:#$query})
      if (( ${#m} > 0 )); then
        raw_matches+=("${(@)m[1,10]}")
        (( ${#raw_matches} >= 10 )) && break
      fi
    fi
  done

  # Dedupe in-memory (O(N) native C deduplication)
  local -a deduped=()
  if (( ${#raw_matches} > 0 )); then
    deduped=("${(@u)raw_matches[1,5]}")
  fi
  _ghost_results=("${deduped[@]}")

  local t1=${EPOCHREALTIME:-0}
  _GHOST_SUGGEST_ELAPSED=$(( (t1 - t0) * 1000.0 ))

  # Defensive budget guard
  if (( _GHOST_SUGGEST_ELAPSED > 1.5 )) && [[ "${ZIRO_GHOST_DEBUG:-0}" == "1" ]]; then
    print -u2 -- "ziro-ghost: budget exceeded: ${_GHOST_SUGGEST_ELAPSED}ms for query '$query'"
  fi

  (( silent )) || print -l -- "${deduped[@]}"
  return 0
}
