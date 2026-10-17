# ziro-ghost v1.0.3 — Minimal core

zmodload zsh/datetime 2>/dev/null || true

typeset -g _ghost_last_suggestion=""
typeset -g _GHOST_CURRENT_SUGGESTION=""
typeset -g _GHOST_CURRENT_KIND="cmd"

_ghost_parse_candidate() {
  emulate -L zsh
  local raw="$1"
  if [[ -z "$raw" ]]; then
    typeset -g _ghost_candidate_weight=""
    typeset -g _ghost_candidate_kind=""
    typeset -g _ghost_candidate_text=""
    return 0
  fi
  if [[ "$raw" =~ '^([0-9]+):([^:]+):(.*)$' ]]; then
    typeset -g _ghost_candidate_weight="${match[1]}"
    typeset -g _ghost_candidate_kind="${match[2]}"
    typeset -g _ghost_candidate_text="${match[3]}"
  else
    typeset -g _ghost_candidate_weight="10"
    typeset -g _ghost_candidate_kind="cmd"
    typeset -g _ghost_candidate_text="$raw"
  fi
}

_ghost_invoke_handler() {
  emulate -L zsh
  local handler="$1" query="$2" src_name="${3:-}"
  local -i timeout_ms=50 max_sugg=50

  if [[ -n "$src_name" && -n "${_ghost_source_contract[$src_name]:-}" ]]; then
    local contract="${_ghost_source_contract[$src_name]}"
    max_sugg="${contract%:*}"
    timeout_ms="${contract#*:}"
  elif (( ${+functions[_ghost_config_get]} )); then
    local conf_timeout="$(_ghost_config_get "safety.handler_timeout_ms" "50")"
    (( timeout_ms = conf_timeout > 0 ? conf_timeout : 50 ))
  fi

  _ghost_results=()
  local t0=$EPOCHREALTIME

  {
    $handler "$query" >/dev/null 2>&1
  } || {
    return 1
  }

  local t1=$EPOCHREALTIME
  local -F elapsed_ms=$(( (t1 - t0) * 1000.0 ))
  if (( elapsed_ms > timeout_ms )); then
    _ghost_results=()
    if [[ -n "$src_name" ]]; then
      (( _ghost_source_stats[${src_name}.timeout_violations]++ )) || true
    fi
    return 1
  fi

  if (( max_sugg > 0 && ${#_ghost_results} > max_sugg )); then
    _ghost_results=("${(@)_ghost_results[1,$max_sugg]}")
    if [[ -n "$src_name" ]]; then
      (( _ghost_source_stats[${src_name}.truncations]++ )) || true
    fi
  fi

  return 0
}

_ghost_line_finish() {
  emulate -L zsh
  _ghost_ui_inline_clear
}

_ghost_boot() {
  emulate -L zsh
  autoload -Uz add-zle-hook-widget 2>/dev/null || true
  zle -N _ghost_line_pre_redraw 2>/dev/null || true
  zle -N _ghost_line_finish 2>/dev/null || true
  add-zle-hook-widget line-pre-redraw _ghost_line_pre_redraw 2>/dev/null || true
  add-zle-hook-widget line-finish _ghost_line_finish 2>/dev/null || true
  
  # Key bindings for inline accept (Right Arrow, Ctrl+F, Ctrl+E)
  zle -N _ghost_accept_widget 2>/dev/null || true
  bindkey '^F' _ghost_accept_widget 2>/dev/null || true
  bindkey '^E' _ghost_accept_widget 2>/dev/null || true
  bindkey '^[[C' _ghost_accept_widget 2>/dev/null || true
  bindkey '^[OC' _ghost_accept_widget 2>/dev/null || true
}

_ghost_line_pre_redraw() {
  emulate -L zsh
  local query="$BUFFER"
  
  # Clear previous
  _ghost_ui_inline_clear
  
  # Empty buffer — nothing to do
  [[ -z "$query" ]] && return 0
  
  # Compute suggestions
  _ghost_compute "$query"
  [[ ${#_ghost_results[@]} -eq 0 ]] && return 0
  
  # Render top suggestion
  _ghost_ui_inline_render "${_ghost_results[1]}"
}

_ghost_compute() {
  emulate -L zsh
  local query="${1:-$BUFFER}"
  _ghost_results=()
  local -a all_candidates=()

  # Query primary sources
  local source handler enabled is_fallback
  for source in ${(k)_ghost_sources_handler}; do
    is_fallback="${_ghost_sources_fallback[$source]:-0}"
    [[ "$is_fallback" == "1" || "$source" == "typo" ]] && continue
    enabled="${_ghost_sources_enabled[$source]:-0}"
    [[ "$enabled" != ("1"|"true"|"yes") ]] && continue
    handler="${_ghost_sources_handler[$source]}"
    if [[ -n "$handler" ]]; then
      if _ghost_invoke_handler "$handler" "$query" "$source"; then
        (( ${#_ghost_results} > 0 )) && all_candidates+=("${_ghost_results[@]}")
      fi
    fi
  done

  # If no primary results, query fallback sources
  if (( ${#all_candidates} == 0 )); then
    for source in ${(k)_ghost_sources_handler}; do
      is_fallback="${_ghost_sources_fallback[$source]:-0}"
      [[ "$is_fallback" != "1" && "$source" != "typo" ]] && continue
      enabled="${_ghost_sources_enabled[$source]:-0}"
      [[ "$enabled" != ("1"|"true"|"yes") ]] && continue
      handler="${_ghost_sources_handler[$source]}"
      if [[ -n "$handler" ]]; then
        if _ghost_invoke_handler "$handler" "$query" "$source"; then
          (( ${#_ghost_results} > 0 )) && all_candidates+=("${_ghost_results[@]}")
        fi
      fi
    done
  fi

  _ghost_results=("${all_candidates[@]}")

  if (( ${#_ghost_results} > 0 )); then
    _ghost_parse_candidate "${_ghost_results[1]}"
    typeset -g _GHOST_CURRENT_SUGGESTION="$_ghost_candidate_text"
    typeset -g _GHOST_CURRENT_KIND="$_ghost_candidate_kind"
  else
    typeset -g _GHOST_CURRENT_SUGGESTION=""
    typeset -g _GHOST_CURRENT_KIND="cmd"
  fi
}

_ghost_accept_widget() {
  emulate -L zsh
  if [[ -n "$_ghost_last_suggestion" ]]; then
    BUFFER="$_ghost_last_suggestion"
    CURSOR=${#BUFFER}
    zle -R
  else
    zle end-of-line
  fi
}
