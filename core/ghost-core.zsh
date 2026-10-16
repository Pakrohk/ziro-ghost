#!/usr/bin/env zsh
# ziro-ghost — Core ZLE Lifecycle, Contract Safety & Engine Coordinator
# Layer: Core · Spec: 009 v0.2.0 (FR-001, FR-005, R11, R13, R17) · Version: 0.8.0
# Coordinates ZLE hooks, source querying, contract enforcement, ranking, and rendering.

zmodload zsh/datetime 2>/dev/null || true

typeset -g _GHOST_CURRENT_SUGGESTION=""
typeset -g _GHOST_CURRENT_KIND="cmd"

# Invoke handler with contract-based safety (zero forks)
# Contract: max_suggestions + timeout_ms declared per custom source
_ghost_invoke_handler() {
  emulate -L zsh
  local handler="$1" query="$2" src_name="${3:-$1}"

  local max_sugg=50
  local -F timeout_ms=50.0

  if (( ${+functions[_ghost_config_get]} )); then
    local conf_timeout="$(_ghost_config_get "safety.handler_timeout_ms" "50")"
    (( timeout_ms = conf_timeout > 0 ? conf_timeout : 50 ))
  fi

  if [[ -n "${_ghost_source_contract[$src_name]:-}" ]]; then
    local contract="${_ghost_source_contract[$src_name]}"
    max_sugg="${contract%%:*}"
    timeout_ms="${contract##*:}"
  fi

  (( max_sugg = max_sugg > 0 ? max_sugg : 50 ))
  (( timeout_ms = timeout_ms > 0 ? timeout_ms : 50 ))

  _ghost_results=()
  _ghost_result_kinds=()
  local t0=$EPOCHREALTIME
  local rc=0

  {
    "$handler" "$query" 2>/dev/null
  } || rc=$?

  local -F elapsed_ms=$(( (EPOCHREALTIME - t0) * 1000.0 ))
  local -i elapsed_i=$(( elapsed_ms ))

  # Contract enforcement: timeout
  if (( elapsed_ms > timeout_ms )); then
    _ghost_source_stats[$src_name.timeout_violations]=$(( ${_ghost_source_stats[$src_name.timeout_violations]:-0} + 1 ))
    _ghost_results=()
    _ghost_result_kinds=()
    # Still record stats for observability
    _ghost_source_stats[$src_name.calls]=$(( ${_ghost_source_stats[$src_name.calls]:-0} + 1 ))
    _ghost_source_stats[$src_name.total_ms]=$(( ${_ghost_source_stats[$src_name.total_ms]:-0} + elapsed_i ))
    _ghost_source_stats[$src_name.last_ms]="$elapsed_i"
    local prev_max=${_ghost_source_stats[$src_name.max_ms]:-0}
    (( elapsed_i > prev_max )) && _ghost_source_stats[$src_name.max_ms]="$elapsed_i"
    return 1
  fi

  # Contract enforcement: max suggestions truncation
  if (( ${#_ghost_results} > max_sugg )); then
    _ghost_results=("${_ghost_results[@]:0:$max_sugg}")
    # Keep kinds in sync if handler populated them
    if (( ${#_ghost_result_kinds} > max_sugg )); then
      _ghost_result_kinds=("${_ghost_result_kinds[@]:0:$max_sugg}")
    fi
    _ghost_source_stats[$src_name.truncations]=$(( ${_ghost_source_stats[$src_name.truncations]:-0} + 1 ))
  fi

  # Stats tracking
  _ghost_source_stats[$src_name.calls]=$(( ${_ghost_source_stats[$src_name.calls]:-0} + 1 ))
  _ghost_source_stats[$src_name.total_ms]=$(( ${_ghost_source_stats[$src_name.total_ms]:-0} + elapsed_i ))
  _ghost_source_stats[$src_name.last_ms]="$elapsed_i"
  local prev_max2=${_ghost_source_stats[$src_name.max_ms]:-0}
  (( elapsed_i > prev_max2 )) && _ghost_source_stats[$src_name.max_ms]="$elapsed_i"

  return $rc
}

# Query all enabled sources and compute top ranked candidate
_ghost_compute() {
  emulate -L zsh
  local query="$BUFFER"
  _GHOST_CURRENT_SUGGESTION=""
  _GHOST_CURRENT_KIND="cmd"

  [[ -z "$query" ]] && return 0
  # Guard against multi-line buffers
  [[ "$query" == *$'\n'* ]] && return 0

  local all_candidates=()
  local src handler enabled is_fallback item=""

  # 1. Run all normal (non-fallback) sources
  for src in ${(k)_ghost_sources_handler}; do
    is_fallback="${_ghost_sources_fallback[$src]:-0}"
    (( is_fallback == 1 )) && continue

    enabled="${_ghost_sources_enabled[$src]:-true}"
    [[ "$enabled" != "true" && "$enabled" != "1" ]] && continue

    handler="${_ghost_sources_handler[$src]}"
    if (( ${+functions[$handler]} )); then
      if _ghost_invoke_handler "$handler" "$query" "$src"; then
        if (( ${#_ghost_results} > 0 )); then
          local src_weight="${_ghost_sources_weight[$src]:-10}"
          local src_kind="${_ghost_sources_kind[$src]:-cmd}"
          for item in "${_ghost_results[@]}"; do
            [[ -z "$item" ]] && continue
            if [[ "$item" == *:* ]]; then
              all_candidates+=("$item")
            else
              all_candidates+=("${src_weight}:${src_kind}:${item}")
            fi
          done
        fi
      fi
    fi
  done

  # 2. If primary sources return nothing, query fallback-only sources (e.g. typo correction)
  if (( ${#all_candidates} == 0 )); then
    for src in ${(k)_ghost_sources_handler}; do
      is_fallback="${_ghost_sources_fallback[$src]:-0}"
      (( is_fallback != 1 )) && continue

      enabled="${_ghost_sources_enabled[$src]:-true}"
      [[ "$enabled" != "true" && "$enabled" != "1" ]] && continue

      handler="${_ghost_sources_handler[$src]}"
      if (( ${+functions[$handler]} )); then
        if _ghost_invoke_handler "$handler" "$query" "$src"; then
          if (( ${#_ghost_results} > 0 )); then
            local src_weight="${_ghost_sources_weight[$src]:-10}"
            local src_kind="${_ghost_sources_kind[$src]:-cmd}"
            for item in "${_ghost_results[@]}"; do
              [[ -z "$item" ]] && continue
              if [[ "$item" == *:* ]]; then
                all_candidates+=("$item")
              else
                all_candidates+=("${src_weight}:${src_kind}:${item}")
              fi
            done
          fi
        fi
      fi
    done
  fi

  (( ${#all_candidates} == 0 )) && return 0

  # Rank candidates without subshell (Spec 011 Cat 1 & Cat 5)
  local ranked=()
  if (( ${+functions[ghost_rank_candidates]} )); then
    _ghost_ranked=()
    ghost_rank_candidates "${all_candidates[@]}" >/dev/null 2>&1
    ranked=("${_ghost_ranked[@]}")
  else
    ranked=("${all_candidates[@]}")
  fi

  (( ${#ranked} == 0 )) && return 0

  # Best candidate: format score:kind:text
  local top="${ranked[1]}"
  local rest="${top#*:}"
  _GHOST_CURRENT_KIND="${rest%%:*}"
  _GHOST_CURRENT_SUGGESTION="${rest#*:}"
}

# ZLE hook: called right before command line redraw
_ghost_line_pre_redraw() {
  emulate -L zsh
  [[ -o zle ]] || return 0

  # Compute best match
  _ghost_compute

  # Render via inline UI
  if [[ -n "$_GHOST_CURRENT_SUGGESTION" ]]; then
    if (( ${+functions[ghost_ui_inline_render]} )); then
      ghost_ui_inline_render "$_GHOST_CURRENT_SUGGESTION" "$_GHOST_CURRENT_KIND"
    fi
  else
    if (( ${+functions[ghost_ui_inline_clear]} )); then
      ghost_ui_inline_clear
    fi
  fi
}

# Widget: accept full ghost suggestion
_ghost_accept_full() {
  emulate -L zsh
  if [[ -n "$_GHOST_CURRENT_SUGGESTION" && "$_GHOST_CURRENT_SUGGESTION" == "$BUFFER"* ]]; then
    BUFFER="$_GHOST_CURRENT_SUGGESTION"
    CURSOR=${#BUFFER}
    _GHOST_CURRENT_SUGGESTION=""
    (( ${+functions[ghost_ui_inline_clear]} )) && ghost_ui_inline_clear
    zle -R
  else
    zle forward-char
  fi
}

# Widget: accept next word of ghost suggestion
_ghost_accept_word() {
  emulate -L zsh
  if [[ -n "$_GHOST_CURRENT_SUGGESTION" && "$_GHOST_CURRENT_SUGGESTION" == "$BUFFER"* ]]; then
    local suffix="${_GHOST_CURRENT_SUGGESTION#$BUFFER}"
    # Match next whitespace or non-whitespace segment
    if [[ "$suffix" =~ '^([[:space:]]*[^[:space:]]+)' ]]; then
      local word="${match[1]}"
      BUFFER+="$word"
      CURSOR=${#BUFFER}
      zle -R
      return 0
    fi
  fi
  zle forward-word
}

# Widget: dismiss ghost suggestion
_ghost_dismiss() {
  emulate -L zsh
  _GHOST_CURRENT_SUGGESTION=""
  (( ${+functions[ghost_ui_inline_clear]} )) && ghost_ui_inline_clear
  zle -R
}

# Widget: open interactive popup menu
_ghost_popup() {
  emulate -L zsh
  local query="$BUFFER"
  local all_candidates=()
  local src handler enabled is_fallback item=""

  # 1. Run all normal (non-fallback) sources
  for src in ${(k)_ghost_sources_handler}; do
    is_fallback="${_ghost_sources_fallback[$src]:-0}"
    (( is_fallback == 1 )) && continue

    enabled="${_ghost_sources_enabled[$src]:-true}"
    [[ "$enabled" != "true" && "$enabled" != "1" ]] && continue
    handler="${_ghost_sources_handler[$src]}"
    if (( ${+functions[$handler]} )); then
      if _ghost_invoke_handler "$handler" "$query" "$src"; then
        if (( ${#_ghost_results} > 0 )); then
          local src_weight="${_ghost_sources_weight[$src]:-10}"
          local src_kind="${_ghost_sources_kind[$src]:-cmd}"
          for item in "${_ghost_results[@]}"; do
            [[ -z "$item" ]] && continue
            if [[ "$item" == *:* ]]; then
              all_candidates+=("$item")
            else
              all_candidates+=("${src_weight}:${src_kind}:${item}")
            fi
          done
        fi
      fi
    fi
  done

  # 2. If primary sources return nothing, query fallback-only sources
  if (( ${#all_candidates} == 0 )); then
    for src in ${(k)_ghost_sources_handler}; do
      is_fallback="${_ghost_sources_fallback[$src]:-0}"
      (( is_fallback != 1 )) && continue

      enabled="${_ghost_sources_enabled[$src]:-true}"
      [[ "$enabled" != "true" && "$enabled" != "1" ]] && continue
      handler="${_ghost_sources_handler[$src]}"
      if (( ${+functions[$handler]} )); then
        if _ghost_invoke_handler "$handler" "$query" "$src"; then
          if (( ${#_ghost_results} > 0 )); then
            local src_weight="${_ghost_sources_weight[$src]:-10}"
            local src_kind="${_ghost_sources_kind[$src]:-cmd}"
            for item in "${_ghost_results[@]}"; do
              [[ -z "$item" ]] && continue
              if [[ "$item" == *:* ]]; then
                all_candidates+=("$item")
              else
                all_candidates+=("${src_weight}:${src_kind}:${item}")
              fi
            done
          fi
        fi
      fi
    done
  fi

  # Rank candidates before popup
  if (( ${+functions[ghost_rank_candidates]} )); then
    _ghost_ranked=()
    ghost_rank_candidates "${all_candidates[@]}" >/dev/null 2>&1
    all_candidates=("${_ghost_ranked[@]}")
  fi

  if (( ${+functions[ghost_ui_popup_open]} )); then
    ghost_ui_popup_open "${all_candidates[@]}"
  fi
}

# Directory change hook: invalidate directory-scoped caches
_ghost_on_chpwd() {
  emulate -L zsh
  typeset -gA _ghost_project_mem_cache
  _ghost_project_mem_cache=()
  typeset -gA _ghost_project_commands_cache
  _ghost_project_commands_cache=()
}

# Boot and bind ZLE widgets
_ghost_boot() {
  emulate -L zsh

  # Load custom sources configured in ghost.conf
  if (( ${+functions[ghost_load_custom_sources]} )); then
    ghost_load_custom_sources
  fi

  if ! [[ -o interactive ]] && [[ -z "${GHOST_TEST_BOOT:-}" ]]; then
    return 0
  fi

  autoload -Uz add-zsh-hook 2>/dev/null || true
  autoload -Uz add-zle-hook-widget 2>/dev/null || true

  # Register chpwd hook
  if (( ${+functions[add-zsh-hook]} )); then
    add-zsh-hook chpwd _ghost_on_chpwd
  fi

  # Register widgets
  zle -N ghost-accept-full _ghost_accept_full
  zle -N ghost-accept-word _ghost_accept_word
  zle -N ghost-dismiss     _ghost_dismiss
  zle -N ghost-popup       _ghost_popup

  # Register pre-redraw hook
  if (( ${+functions[add-zle-hook-widget]} )); then
    add-zle-hook-widget line-pre-redraw _ghost_line_pre_redraw
  fi

  # Default Keybindings (Spec 009 R13)
  bindkey '\e[C'   ghost-accept-full  # Right arrow
  bindkey '^F'     ghost-accept-word  # Ctrl-F
  bindkey '^G'     ghost-popup        # Ctrl-G
}
