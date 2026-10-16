#!/usr/bin/env zsh
# ziro-ghost — Core ZLE Lifecycle & Engine Coordinator
# Layer: Core · Spec: 009 v0.2.0 (FR-001, FR-005, R11, R13) · Version: 0.2.0
# Coordinates ZLE hooks, source querying, ranking, and rendering.

typeset -g _GHOST_CURRENT_SUGGESTION=""
typeset -g _GHOST_CURRENT_KIND="cmd"

# Query all enabled sources and compute top ranked candidate
_ghost_compute() {
  local query="$BUFFER"
  _GHOST_CURRENT_SUGGESTION=""
  _GHOST_CURRENT_KIND="cmd"

  [[ -z "$query" ]] && return 0
  # Guard against multi-line buffers
  [[ "$query" == *$'\n'* ]] && return 0

  local all_candidates=()
  local src handler enabled
  for src in ${(k)_ghost_sources_handler}; do
    enabled="${_ghost_sources_enabled[$src]:-true}"
    [[ "$enabled" != "true" && "$enabled" != "1" ]] && continue

    handler="${_ghost_sources_handler[$src]}"
    if (( ${+functions[$handler]} )); then
      local lines=(${(f)"$($handler "$query")"})
      all_candidates+=("${lines[@]}")
    fi
  done

  (( ${#all_candidates} == 0 )) && return 0

  # Rank candidates
  local ranked=()
  if (( ${+functions[ghost_rank_candidates]} )); then
    ranked=(${(f)"$(ghost_rank_candidates "${all_candidates[@]}")"})
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
  _GHOST_CURRENT_SUGGESTION=""
  (( ${+functions[ghost_ui_inline_clear]} )) && ghost_ui_inline_clear
  zle -R
}

# Widget: open interactive popup menu
_ghost_popup() {
  local query="$BUFFER"
  local all_candidates=()

  local src handler enabled
  for src in ${(k)_ghost_sources_handler}; do
    enabled="${_ghost_sources_enabled[$src]:-true}"
    [[ "$enabled" != "true" && "$enabled" != "1" ]] && continue
    handler="${_ghost_sources_handler[$src]}"
    if (( ${+functions[$handler]} )); then
      local lines=(${(f)"$($handler "$query")"})
      all_candidates+=("${lines[@]}")
    fi
  done

  if (( ${+functions[ghost_ui_popup_open]} )); then
    ghost_ui_popup_open "${all_candidates[@]}"
  fi
}

# Boot and bind ZLE widgets
_ghost_boot() {
  [[ -o interactive ]] || return 0

  autoload -Uz add-zsh-hook 2>/dev/null || true
  autoload -Uz add-zle-hook-widget 2>/dev/null || true

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
