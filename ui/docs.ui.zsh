#!/usr/bin/env zsh
# ziro-ghost — Documentation Window UI
# Layer: UI · Spec: 009 v0.2.0 (FR-009) · Version: 0.8.0
# Invokes Python docs extractor to display tldr/man/--help in the popup preview.

_ghost_docs_render() {
  emulate -L zsh
  local candidate="$1"
  [[ -z "$candidate" ]] && return 0

  # Check if ui.docs.enabled is false
  if (( ${+functions[_ghost_config_get]} )); then
    local enabled="$(_ghost_config_get "ui.docs.enabled" "true")"
    [[ "$enabled" == "false" || "$enabled" == "0" ]] && return 0
  fi

  local text="$candidate"
  if [[ "$candidate" == *$'\t'* ]]; then
    text="${candidate#*$'\t'}"
  elif [[ "$candidate" == *:* ]]; then
    local -a parts=(${(s.:.)candidate})
    text="${candidate#${parts[1]}:${parts[2]}:}"
  fi

  # Extract command tokens (up to 2 words, e.g. "git commit" or "ls")
  local -a words=(${(z)text})
  local cmd="${words[1]:-$text}"
  if [[ "$cmd" == "git" || "$cmd" == "docker" || "$cmd" == "kubectl" || "$cmd" == "pnpm" || "$cmd" == "npm" || "$cmd" == "cargo" ]]; then
    if [[ -n "${words[2]:-}" && "${words[2]}" != -* ]]; then
      cmd="$cmd ${words[2]}"
    fi
  fi

  local helper="${GHOST_HOME:-${0:A:h:h}}/lib/docs_extractor.py"
  if [[ ! -f "$helper" ]]; then
    helper="${${(%):-%x}:A:h:h}/lib/docs_extractor.py"
  fi

  local ttl="86400"
  local max_lines="15"
  if (( ${+functions[_ghost_config_get]} )); then
    ttl="$(_ghost_config_get "ui.docs.cache_ttl" "86400")"
    max_lines="$(_ghost_config_get "ui.docs.max_lines" "15")"
  fi

  print -r -- "╭─ Documentation: $cmd ─╮"
  print -r -- ""
  if [[ -f "$helper" ]] && (( ${+commands[python3]} )); then
    python3 "$helper" --ttl "$ttl" --max-lines "$max_lines" "$cmd"
  else
    print -r -- "Documentation helper not available."
  fi
}

# Standalone execution wrapper for fzf
if [[ "${(%):-%N}" == "$0" || "${1:-}" == "--render" ]]; then
  local arg="${1:-}"
  [[ "$arg" == "--render" ]] && shift
  _ghost_docs_render "$@"
fi
