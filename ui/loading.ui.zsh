#!/usr/bin/env zsh
# ziro-ghost — Pure Zsh Loading Indicator
# Layer: UI · Spec: 009 v0.2.0 (FR-005, Spec 011) · Version: 1.0.0
# Zero forks, pure Zsh spinner for RPROMPT / async queries.

zmodload zsh/datetime 2>/dev/null || true

typeset -ga _ghost_spinner_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
typeset -g _ghost_spinner_index=1
typeset -g _ghost_loading_state="idle"
typeset -g _ghost_loading_label=""
typeset -g _ghost_loading_t0=0
typeset -g _ghost_loading_indicator=""

# Start tracking an operation
_ghost_loading_start() {
  emulate -L zsh
  local label="${1:-loading}"
  _ghost_loading_state="computing"
  _ghost_loading_label="$label"
  _ghost_loading_t0=$EPOCHREALTIME
  _ghost_loading_indicator=""
}

# Stop tracking an operation
_ghost_loading_stop() {
  emulate -L zsh
  _ghost_loading_state="idle"
  _ghost_loading_label=""
  _ghost_loading_t0=0
  _ghost_loading_indicator=""
}

# Refresh indicator value based on elapsed time & config
_ghost_loading_refresh() {
  emulate -L zsh
  [[ "$_ghost_loading_state" == "idle" ]] && { _ghost_loading_indicator=""; return 0; }

  # Check config: enabled
  if (( ${+functions[_ghost_config_get]} )); then
    local enabled="$(_ghost_config_get "ui.loading.enabled" "true")"
    [[ "$enabled" == "false" || "$enabled" == "0" ]] && { _ghost_loading_indicator=""; return 0; }
  fi

  # Check config: threshold
  local -F threshold_ms=200.0
  if (( ${+functions[_ghost_config_get]} )); then
    local conf_th="$(_ghost_config_get "ui.loading.threshold_ms" "200")"
    (( threshold_ms = conf_th > 0 ? conf_th : 200.0 ))
  fi

  local t1=$EPOCHREALTIME
  local -F elapsed=$(( (t1 - _ghost_loading_t0) * 1000.0 ))
  if (( elapsed < threshold_ms )); then
    _ghost_loading_indicator=""
    return 0
  fi

  # Style resolution
  local style="minimal"
  local show_label="false"
  if (( ${+functions[_ghost_config_get]} )); then
    style="$(_ghost_config_get "ui.loading.style" "minimal")"
    show_label="$(_ghost_config_get "ui.loading.show_label" "false")"
  fi

  local ind=""
  case "$style" in
    spinner)
      (( _ghost_spinner_index = _ghost_spinner_index % ${#_ghost_spinner_chars} + 1 ))
      ind="${_ghost_spinner_chars[$_ghost_spinner_index]}"
      ;;
    text)
      ind="[${_ghost_loading_label:-loading}...]"
      ;;
    minimal|*)
      ind="⏳"
      ;;
  esac

  if [[ "$show_label" == "true" && "$style" != "text" && -n "$_ghost_loading_label" ]]; then
    ind="${ind} ${_ghost_loading_label}"
  fi

  _ghost_loading_indicator="$ind"
}

# RPROMPT wrapper: outputs indicator safely
_ghost_loading_rprompt_wrap() {
  emulate -L zsh
  _ghost_loading_refresh
  print -rn -- "$_ghost_loading_indicator"
}
