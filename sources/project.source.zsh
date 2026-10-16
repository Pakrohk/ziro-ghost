#!/usr/bin/env zsh
# ziro-ghost — Project Markers Suggestion Source
# Layer: Sources · Spec: 009 v0.2.0 (R12, R14) · Version: 0.4.0
# Detects project ecosystems (Python, Node, Rust, Go, etc.) and provides contextual recipes.

# ─── Hoist standard modules (Spec 011 Cat 7) ───
zmodload zsh/datetime 2>/dev/null || true
zmodload zsh/mapfile 2>/dev/null || true

typeset -g _ghost_project_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost/project-cache"
typeset -gA _ghost_project_mem_cache
typeset -gA _ghost_project_commands_cache

# Detect project info with per-directory caching and mtime invalidation
_ghost_project_detect() {
  emulate -L zsh
  local dir="${1:-${PWD:A}}"
  local cache_key="${dir//\//_}"
  local cache_file="$_ghost_project_cache_dir/$cache_key.json"

  # 1. In-memory cache hit
  if [[ -n "${_ghost_project_mem_cache[$dir]:-}" ]]; then
    print -r -- "${_ghost_project_mem_cache[$dir]}"
    return 0
  fi

  # 2. Disk cache hit (valid if newer than markers in dir)
  if [[ -f "$cache_file" ]]; then
    local stale=0
    local marker
    for marker in pyproject.toml package.json Cargo.toml go.mod Gemfile composer.json Makefile docker-compose.yml Dockerfile justfile requirements.txt; do
      if [[ -f "$dir/$marker" && "$dir/$marker" -nt "$cache_file" ]]; then
        stale=1
        break
      fi
    done

    if (( ! stale )); then
      local out="${mapfile[$cache_file]:-}"
      if [[ -n "$out" ]]; then
        _ghost_project_mem_cache[$dir]="$out"
        print -r -- "$out"
        return 0
      fi
    fi
  fi

  # 3. Cache miss: invoke Python helper (Cold-path only)
  [[ -d "$_ghost_project_cache_dir" ]] || mkdir -p "$_ghost_project_cache_dir" 2>/dev/null || true

  local helper="${GHOST_HOME:-${0:A:h:h}}/lib/project_markers.py"
  if [[ ! -f "$helper" ]]; then
    helper="${${(%):-%x}:A:h:h}/lib/project_markers.py"
  fi

  (( ${+functions[_ghost_loading_start]} )) && _ghost_loading_start "project"
  local out
  out="$(python3 "$helper" "$dir" 2>/dev/null)" || {
    (( ${+functions[_ghost_loading_stop]} )) && _ghost_loading_stop
    return 1
  }
  (( ${+functions[_ghost_loading_stop]} )) && _ghost_loading_stop
  if [[ -n "$out" ]]; then
    print -r -- "$out" > "$cache_file" 2>/dev/null || true
    _ghost_project_mem_cache[$dir]="$out"
  fi

  print -r -- "$out"
}

# Query project suggestions for matching commands
# Output format: score:kind:text
_ghost_project_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()

  local dir="${PWD:A}"
  local -a commands=()

  if [[ -n "${_ghost_project_commands_cache[$dir]:-}" ]]; then
    commands=(${(f)_ghost_project_commands_cache[$dir]})
  else
    local data
    data="$(_ghost_project_detect "$dir")" || return 0
    [[ -z "$data" ]] && return 0

    commands=(${(f)"$(python3 -c "import json,sys; d=json.load(sys.stdin); [print(c) for c in d.get('commands',[])]" <<< "$data" 2>/dev/null)"})
    _ghost_project_commands_cache[$dir]="${(F)commands}"
  fi

  local cmd
  for cmd in "${commands[@]}"; do
    [[ -z "$cmd" ]] && continue
    if [[ -z "$query" || "$cmd" == "$query"* ]]; then
      _ghost_results+=("30:project:$cmd")
    fi
  done

  print -rl -- "${_ghost_results[@]}"
}

# Public aliases
ghost_project_detect() {
  emulate -L zsh
  _ghost_project_detect "$@"
}

ghost_project_query() {
  emulate -L zsh
  _ghost_project_query "$@"
}

# Register project source in IOP registry
if (( ${+functions[ghost_register_source]} )); then
  ghost_register_source project \
    --intent "provide project-aware suggestions based on detected project markers" \
    --handler _ghost_project_query \
    --weight 30 \
    --kind project \
    --enabled true
fi
