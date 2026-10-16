#!/usr/bin/env zsh
# ziro-ghost — Subcommand Suggestion Source
# Layer: Sources · Spec: 009 v0.2.0 (FR-007, R15) · Version: 0.5.0
# Provides fast subcommand completions via static tables and dynamic completion fallback.

# ─── Static lookup table for common CLI ecosystems ───
typeset -gA _ghost_subcommand_table=(
  git     "status add commit push pull branch checkout merge rebase log diff stash remote fetch tag reset"
  docker  "run ps build images exec logs stop start rm rmi pull push compose network volume"
  kubectl "get describe apply delete create edit logs exec port-forward config rollout scale"
  uv      "sync add remove lock run pip venv python tool"
  pnpm    "install add remove update dev build test lint run exec why why-not"
  npm     "install uninstall update run test build start publish"
  yarn    "install add remove upgrade run test build start"
  cargo   "build test run clippy fmt check clean doc update publish bench"
  go      "build test run mod get install fmt vet env"
  pip     "install uninstall list show freeze search download"
  brew    "install uninstall upgrade update search info list doctor cleanup"
)

# ─── Dynamic extraction via completion function (best-effort) ───
_ghost_subcommand_extract() {
  emulate -L zsh
  local cmd="$1"
  local comp_func="_${cmd}"

  (( $+functions[$comp_func] )) || return 1

  local -a _ghost_dynamic_captures=()
  compadd() {
    emulate -L zsh
    local arg
    for arg in "$@"; do
      [[ "$arg" == -* || "$arg" == "--" ]] && continue
      _ghost_dynamic_captures+=("$arg")
    done
    return 0
  }

  local curcontext="::"
  local -a words=("$cmd")
  local CURRENT=1
  "$comp_func" 2>/dev/null || true
  unfunction compadd 2>/dev/null || true

  local sub
  for sub in "${_ghost_dynamic_captures[@]}"; do
    [[ -n "$sub" ]] && _ghost_results+=("10:cmd:${cmd} ${sub}")
  done
}

# ─── Main query interface ───
_ghost_subcommand_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  [[ -z "$query" ]] && return 1

  local -a words=(${(z)query})
  (( ${#words} == 0 || ${#words} > 2 )) && return 1

  local cmd="${words[1]}"
  local sub_prefix="${words[2]:-}"

  # Check if command exists in static table or has completion function
  local has_static=0
  [[ -n "${_ghost_subcommand_table[$cmd]:-}" ]] && has_static=1
  local comp_func="_${cmd}"
  local has_comp=0
  (( $+functions[$comp_func] )) && has_comp=1

  (( ! has_static && ! has_comp )) && return 1

  # 1. Add static subcommands
  if (( has_static )); then
    local sub
    for sub in ${(z)_ghost_subcommand_table[$cmd]}; do
      if [[ -z "$sub_prefix" || "$sub" == "$sub_prefix"* ]]; then
        _ghost_results+=("10:cmd:${cmd} ${sub}")
      fi
    done
  fi

  # 2. Add dynamic subcommands if available
  if (( has_comp )); then
    _ghost_subcommand_extract "$cmd" 2>/dev/null || true
  fi

  # Deduplicate results
  _ghost_results=(${(u)_ghost_results})
  print -rl -- "${_ghost_results[@]}"
  (( ${#_ghost_results} > 0 ))
}

# Public alias
ghost_subcommand_query() {
  emulate -L zsh
  _ghost_subcommand_query "$@"
}

# ─── Register with IOP ───
if (( ${+functions[ghost_register_source]} )); then
  ghost_register_source subcommand \
    --intent "provide subcommand suggestions via static tables and completion extraction" \
    --handler _ghost_subcommand_query \
    --weight 10 \
    --kind cmd \
    --enabled true
fi
