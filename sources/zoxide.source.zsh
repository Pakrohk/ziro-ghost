#!/usr/bin/env zsh
# ziro-ghost — Zoxide Suggestion Source
# Layer: Sources · Spec: 009 v0.2.0 (FR-001, FR-007) · Version: 0.9.0
# Proposes cd target directories ranked by zoxide frecency database.

# Guard: skip if zoxide is not installed
(( $+commands[zoxide] )) || return 0

_ghost_zoxide_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  _ghost_result_kinds=()

  # Only trigger if query starts with 'cd ' or is bare 'cd'
  [[ "$query" == cd\ * || "$query" == "cd" ]] || return 1

  local term=""
  if [[ "$query" == cd\ * ]]; then
    term="${query#cd }"
  fi

  local -a entries
  local raw_out
  raw_out="$(zoxide query -ls 2>/dev/null | head -20)" || return 1
  [[ -z "$raw_out" ]] && return 1

  entries=(${(f)raw_out})

  local entry dir
  for entry in "${entries[@]}"; do
    [[ -z "$entry" ]] && continue
    # Format from 'zoxide query -ls': '<score> <path>'
    dir="${entry#*[[:space:]]}"
    # Strip any leading whitespace
    dir="${dir#"${dir%%[![:space:]]*}"}"
    [[ -z "$dir" ]] && continue

    # Case-insensitive substring match if term is provided
    if [[ -n "$term" ]]; then
      local lower_dir="${(L)dir}"
      local lower_term="${(L)term}"
      [[ "$lower_dir" != *"$lower_term"* ]] && continue
    fi

    _ghost_results+=("15:path:cd $dir")
    _ghost_result_kinds+=(path)
  done

  (( ${#_ghost_results} > 0 ))
}

# Register source in IOP registry
if (( ${+functions[ghost_register_source]} )); then
  ghost_register_source zoxide \
    --intent 'provide cd targets from zoxide frecency db' \
    --handler _ghost_zoxide_query \
    --weight 15 \
    --kind path \
    --enabled true
fi
