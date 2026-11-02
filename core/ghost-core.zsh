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

  # Focus mode Tab binding (preserves default completion when no suggestion active)
  if [[ "${_GHOST_FOCUS_ENABLED:-1}" != "0" ]]; then
    zle -N _ghost_focus_widget 2>/dev/null || true
    bindkey '^I' _ghost_focus_widget 2>/dev/null || true
  fi
}

_ghost_focus_widget() {
  emulate -L zsh

  # If no suggestion is currently shown or focus mode is disabled, pass through to default completion
  if [[ -z "$POSTDISPLAY" || "${_GHOST_FOCUS_ENABLED:-1}" == "0" ]]; then
    zle expand-or-complete
    return $?
  fi

  # Lazy-init bus
  _ghost_bus_init 2>/dev/null
  if (( ! _GHOST_BUS_AVAILABLE )); then
    zle expand-or-complete
    return $?
  fi

  # Collect matching items for the popup
  local -a matching=()
  local item escaped_item
  local -i count=0

  for item in "${_ghost_results[@]}"; do
    [[ "$item" == [0-9]*:[^:]*:* ]] && item="${item#*:*:}"
    [[ -z "$item" ]] && continue
    if [[ "$item" == "$BUFFER"* ]]; then
      matching+=("$item")
      (( ++count >= 10 )) && break
    fi
  done

  if (( count < 10 )); then
    for item in "${_ghost_history_cache[@]}"; do
      [[ -z "$item" || "$item" == "$BUFFER" ]] && continue
      if [[ "$item" == "$BUFFER"* ]]; then
        if (( ${matching[(Ie)$item]} == 0 )); then
          matching+=("$item")
          (( ++count >= 10 )) && break
        fi
      fi
    done
  fi

  if (( ${#matching} == 0 )); then
    zle expand-or-complete
    return $?
  fi

  # Build JSON array
  local items_json="["
  local first=1
  for item in "${matching[@]}"; do
    escaped_item="${item//\\/\\\\}"
    escaped_item="${escaped_item//\"/\\\"}"
    if (( first )); then
      items_json+="\"$escaped_item\""
      first=0
    else
      items_json+=",\"$escaped_item\""
    fi
  done
  items_json+="]"

  if _ghost_intent_publish "ghost.popup.focus_enter" "ephemeral" "{\"items\":${items_json}}"; then
    if [[ "$_GHOST_BUS_LAST_RESPONSE" =~ '"selected":"([^"]+)"' ]]; then
      BUFFER="${match[1]}"
      CURSOR=${#BUFFER}
      _ghost_ui_inline_clear
      zle reset-prompt 2>/dev/null || true
      return 0
    elif [[ "$_GHOST_BUS_LAST_RESPONSE" =~ '"cancelled":true' ]]; then
      zle reset-prompt 2>/dev/null || true
      return 0
    fi
  fi

  zle send-break
}

_ghost_suggest_v107_fallback() {
  emulate -L zsh
  local query="${1:-$BUFFER}"
  _ghost_ui_inline_clear
  [[ -z "$query" ]] && return 0
  _ghost_compute "$query"
  [[ ${#_ghost_results[@]} -eq 0 ]] && return 0
  _ghost_ui_inline_render "${_ghost_results[1]}"
}

_ghost_suggest_apply_response() {
  emulate -L zsh
  local resp="$1"
  if [[ "$resp" =~ '"suggestion":"([^"]+)"' ]]; then
    local suggestion="${match[1]}"
    _ghost_ui_inline_render "$suggestion"
    return 0
  elif [[ "$resp" =~ '"suggestion":null' ]]; then
    _ghost_ui_inline_clear
    return 0
  fi
  return 1
}

_ghost_suggest() {
  emulate -L zsh
  local query="${1:-$BUFFER}"
  _ghost_ui_inline_clear
  [[ -z "$query" ]] && return 0

  # Optional gateway validate (0.05ms, safety check)
  if (( ${+functions[_ghost_processor_validate]} )); then
    local q_esc="${query//\\/\\\\}"
    q_esc="${q_esc//\"/\\\"}"
    local intent_json="{\"id\":\"suggest-$$\",\"name\":\"ghost.suggest.query\",\"level\":\"ephemeral\",\"metadata\":{\"query\":\"$q_esc\"}}"
    typeset -g _GHOST_INTENT_INTERNAL=1
    if ! _ghost_processor_validate "$intent_json"; then
      typeset -g _GHOST_INTENT_INTERNAL=0
      return 0
    fi
    typeset -g _GHOST_INTENT_INTERNAL=0
  fi

  # Pure cache dispatch (0 forks, zero subshell)
  if (( ${+functions[_ghost_source_dispatch_sync]} )); then
    _ghost_source_dispatch_sync "$query" 1
    if (( ${#_ghost_results} > 0 )); then
      _ghost_ui_inline_render "${_ghost_results[1]}"
      (( ${+functions[_ghost_metrics_record]} )) && _ghost_metrics_record "ghost.suggest.query" "ephemeral" "${_GHOST_SUGGEST_ELAPSED:-0}" "ok" "" true
      return 0
    fi
  fi

  (( ${+functions[_ghost_metrics_record]} )) && _ghost_metrics_record "ghost.suggest.query" "ephemeral" "${_GHOST_SUGGEST_ELAPSED:-0}" "ok" "" false
  POSTDISPLAY=''
  return 0
}

_ghost_line_pre_redraw() {
  emulate -L zsh
  _ghost_suggest "$BUFFER"
}

# Register handler for ghost.suggest.response if bus available
if (( ${+functions[_ghost_intent_subscribe]} )); then
  _ghost_intent_subscribe ghost.suggest.response _ghost_suggest_apply_response
fi

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
