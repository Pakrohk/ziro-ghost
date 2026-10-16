#!/usr/bin/env zsh
# ziro-ghost — Preview Pane UI
# Layer: UI · Spec: 009 v0.2.0 (FR-002, FR-009) · Version: 0.8.0
# Renders metadata preview for candidates in the interactive popup.

(( ${+parameters[_ghost_preview_source_map]} )) || typeset -gA _ghost_preview_source_map
(( ${+parameters[_ghost_preview_frecency_map]} )) || typeset -gA _ghost_preview_frecency_map

_ghost_preview_render() {
  emulate -L zsh
  local candidate="$1"
  [[ -z "$candidate" ]] && return 0

  # Check if ui.preview.enabled is false
  if (( ${+functions[_ghost_config_get]} )); then
    local enabled="$(_ghost_config_get "ui.preview.enabled" "true")"
    [[ "$enabled" == "false" || "$enabled" == "0" ]] && return 0
  fi

  local weight="10" kind="cmd" text="$candidate"

  # Strip tab-delimited raw payload if passed from fzf formatted line
  if [[ "$candidate" == *$'\t'* ]]; then
    text="${candidate#*$'\t'}"
    # Extract kind from first column if available
    local col1="${candidate%%$'\t'*}"
    if [[ "$col1" =~ '│[[:space:]]*([a-zA-Z0-9_-]+)' ]]; then
      kind="${match[1]}"
    fi
  elif [[ "$candidate" == *:* ]]; then
    local -a parts=(${(s.:.)candidate})
    weight="${parts[1]}"
    kind="${parts[2]}"
    text="${candidate#${weight}:${kind}:}"
  fi

  local source="${_ghost_preview_source_map[$text]:-unknown}"
  local frecency="${_ghost_preview_frecency_map[$text]:-0}"

  local kind_badge="$kind"
  if (( ${+functions[ghost_kind_render]} )); then
    ghost_kind_render "$kind" >/dev/null
    kind_badge="${REPLY} ${kind}"
  fi

  print -r -- "╭─ Suggestion ─────────────────╮"
  print -r -- "│ $text"
  print -r -- "╰──────────────────────────────╯"
  print -r -- ""
  print -r -- "Kind:     $kind_badge"
  print -r -- "Source:   $source"
  print -r -- "Weight:   $weight"
  print -r -- "Frecency: $frecency"
}

# Standalone execution wrapper for fzf --preview
if [[ "${(%):-%N}" == "$0" || "${1:-}" == "--render" ]]; then
  local arg="${1:-}"
  [[ "$arg" == "--render" ]] && shift
  _ghost_preview_render "$@"
fi
