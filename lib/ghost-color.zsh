#!/usr/bin/env zsh
# ziro-ghost — Color resolution (truecolor / 256 / ansi8)

typeset -g _GHOST_COLOR_MODE="ansi8"

_ghost_detect_color_support() {
  emulate -L zsh
  if [[ -n "$COLORTERM" && "$COLORTERM" == (truecolor|24bit) ]]; then
    _GHOST_COLOR_MODE="truecolor"
  elif (( $(tput colors 2>/dev/null || echo 0) >= 256 )); then
    _GHOST_COLOR_MODE="256"
  else
    _GHOST_COLOR_MODE="ansi8"
  fi
}
_ghost_detect_color_support

_ghost_color_resolve_ghost() {
  emulate -L zsh
  local config_color=""
  if (( ${+functions[_ghost_config_get]} )); then
    config_color="$(_ghost_config_get "ghost.line.color" "")"
    [[ -z "$config_color" || "$config_color" == "auto" ]] && config_color="$(_ghost_config_get "ui.inline.color" "")"
  fi

  if [[ -n "$config_color" && "$config_color" != "auto" ]]; then
    print -r -- "$config_color"
    return 0
  fi

  # Theme preset support
  local theme=""
  if (( ${+functions[_ghost_config_get]} )); then
    theme="$(_ghost_config_get "theme.preset" "terminal")"
  fi
  local ghost_home="${GHOST_HOME:-${ROOT_DIR:-${${(%):-%x}:A:h:h}}}"
  if [[ -n "$theme" && "$theme" != "terminal" && -d "$ghost_home/themes" ]]; then
    local theme_file="$ghost_home/themes/${theme}.toml"
    if [[ -r "$theme_file" ]]; then
      local line val
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == [[:space:]]*ghost_text*[=]*\"*\"* || "$line" == ghost_text*[=]*\"*\"* ]]; then
          val="${line#*\"}"
          val="${val%\"*}"
          [[ -n "$val" ]] && { print -r -- "$val"; return 0; }
        fi
      done < "$theme_file"
    fi
  fi

  case "$_GHOST_COLOR_MODE" in
    truecolor) print -r -- "fg=#6c6c6c" ;;
    256)        print -r -- "fg=240" ;;
    *)          print -r -- "fg=brightblack" ;;
  esac
}

_ghost_ghost_color() {
  emulate -L zsh
  _ghost_color_resolve_ghost "$@"
}
