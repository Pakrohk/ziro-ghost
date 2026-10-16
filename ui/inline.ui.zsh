# ziro-ghost v1.0.2 — Minimal inline renderer

zmodload zsh/datetime 2>/dev/null || true

if ! (( ${+functions[_ghost_color_resolve_ghost]} )); then
  local _inline_dir="${${(%):-%x}:A:h:h}"
  [[ -r "$_inline_dir/lib/ghost-color.zsh" ]] && source "$_inline_dir/lib/ghost-color.zsh"
fi

_GHOST_HIGHLIGHT_MARK=""

_ghost_ui_inline_render() {
  emulate -L zsh
  local suggestion="$1"
  [[ -z "$suggestion" ]] && { _ghost_ui_inline_clear; return 0; }

  # Strip weight:kind: prefix if present (e.g. 40:history:git push -> git push)
  if [[ "$suggestion" == [0-9]*:[^:]*:* ]]; then
    suggestion="${suggestion#*:*:}"
  fi

  # Suffix only
  [[ "$suggestion" == "$BUFFER"* ]] || { _ghost_ui_inline_clear; return 0; }
  local suffix="${suggestion#$BUFFER}"
  [[ -z "$suffix" ]] && { _ghost_ui_inline_clear; return 0; }

  # Store for accept
  typeset -g _ghost_last_suggestion="$suggestion"

  # POSTDISPLAY
  POSTDISPLAY="$suffix"

  # Color
  local color=""
  if (( ${+functions[_ghost_color_resolve_ghost]} )); then
    color="$(_ghost_color_resolve_ghost)"
  fi
  [[ -z "$color" ]] && color="fg=8"

  local start=$#BUFFER
  local end=$(( start + ${#POSTDISPLAY} ))
  typeset -g _GHOST_HIGHLIGHT_MARK="_ghost_${start}_${end}"
  typeset -g _GHOST_HIGHLIGHT_RANGE="$start $end $color $_GHOST_HIGHLIGHT_MARK"

  _ghost_ui_inline_clear_highlight
  region_highlight+=("$_GHOST_HIGHLIGHT_RANGE")
}

_ghost_ui_inline_clear_highlight() {
  emulate -L zsh
  region_highlight=(${region_highlight:#*_ghost_*})
  typeset -g _GHOST_HIGHLIGHT_MARK=""
}

_ghost_ui_inline_clear() {
  emulate -L zsh
  POSTDISPLAY=""
  typeset -g _ghost_last_suggestion=""
  _ghost_ui_inline_clear_highlight
}

# Public / test compatibility wrappers
ghost_ui_inline_render() {
  emulate -L zsh
  _ghost_ui_inline_render "$@"
}

ghost_ui_inline_clear() {
  emulate -L zsh
  _ghost_ui_inline_clear "$@"
}

_ghost_parse_candidate() {
  emulate -L zsh
  local raw="$1"
  if [[ "$raw" == [0-9]*:[^:]*:* ]]; then
    typeset -g _ghost_candidate_text="${raw#*:*:}"
  else
    typeset -g _ghost_candidate_text="$raw"
  fi
}
