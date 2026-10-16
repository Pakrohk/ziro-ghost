#!/usr/bin/env zsh
# ziro-ghost — Zsh Completions Bridge Source
# Layer: Sources · Spec: 009 v0.2.0 (FR-007, R16) · Version: 0.5.0
# Bridges native zsh-completions into ghost suggestion pipeline via compadd interception.

# ─── Capture completions via compadd wrapper ───
_ghost_capture_via_compadd() {
  emulate -L zsh
  local cmd="$1"; shift
  local -a args=("$@")
  local -a _ghost_captures=()

  # Local compadd override (restored on exit)
  compadd() {
    emulate -L zsh
    local -a captured=()
    local arg skip_next=0
    for arg in "$@"; do
      if (( skip_next )); then
        skip_next=0
        continue
      fi
      case "$arg" in
        --) continue ;;
        -[adkUOAODXxyJV12nFWMsqQ])
          # flags with option arguments
          skip_next=1
          continue
          ;;
        -*)
          continue
          ;;
        *)
          captured+=("$arg")
          ;;
      esac
    done
    (( ${#captured} > 0 )) && _ghost_captures+=("${captured[@]}")
    return 0
  }

  local curcontext="::"
  local -a words=("$cmd" "${args[@]}")
  local CURRENT=${#words}
  local comp_func="_${cmd}"

  if (( $+functions[$comp_func] )); then
    "$comp_func" 2>/dev/null || true
  fi

  unfunction compadd 2>/dev/null || true

  local item
  local -a results=()
  local last_arg="${args[-1]:-}"
  for item in "${(@u)_ghost_captures}"; do
    [[ -z "$item" ]] && continue
    if [[ -z "$last_arg" || "$item" == "$last_arg"* ]]; then
      results+=("10:cmd:${cmd} ${item}")
    fi
  done

  _ghost_results=("${results[@]}")
  (( ${#_ghost_results} > 0 ))
}

# ─── Query interface ───
_ghost_completions_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  [[ -z "$query" ]] && return 1

  # Check if compinit has initialized
  (( $+functions[compdef] )) || return 1

  # Split into words
  local -a words=(${(z)query})
  (( ${#words} == 0 )) && return 1

  local cmd="${words[1]}"
  local -a args=("${words[2,-1]}")

  # Defer bare command names to subcommand source
  (( ${#args} == 0 )) && return 1

  # Check for completion function
  local comp_func="_${cmd}"
  (( $+functions[$comp_func] )) || return 1

  _ghost_capture_via_compadd "$cmd" "${args[@]}"
  print -rl -- "${_ghost_results[@]}"
}

# Public alias
ghost_completions_query() {
  emulate -L zsh
  _ghost_completions_query "$@"
}

# ─── Register with IOP ───
if (( ${+functions[ghost_register_source]} )); then
  ghost_register_source completions \
    --intent "bridge zsh-completions into popup" \
    --handler _ghost_completions_query \
    --weight 10 \
    --kind cmd \
    --enabled true
fi
