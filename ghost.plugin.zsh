#!/usr/bin/env zsh
# ziro-ghost v1.0.2 — Minimal Ghost Line
# Repository: https://github.com/Pakrohk/ziro-ghost
# License: MIT
#
# This is a MINIMAL version. Only inline gray suggestions.
# Full featured version (popup, focus mode) coming in v2.0.0.

zmodload zsh/datetime 2>/dev/null || true

(( ${+_GHOST_LOADED} )) && return 0
typeset -g _GHOST_LOADED=1
typeset -g GHOST_HOME="${${(%):-%x}:A:h}"

# Lazy init: register hook, load rest on first keystroke
_ghost_lazy_init() {
  emulate -L zsh
  add-zle-hook-widget -d line-pre-redraw _ghost_lazy_init 2>/dev/null
  unfunction _ghost_lazy_init 2>/dev/null

  source "$GHOST_HOME/core/ghost-version.zsh"
  source "$GHOST_HOME/core/ghost-config.zsh"
  source "$GHOST_HOME/core/ghost-kinds.zsh"
  source "$GHOST_HOME/core/ghost-registry.zsh"
  source "$GHOST_HOME/lib/ghost-color.zsh"
  source "$GHOST_HOME/ui/inline.ui.zsh"
  source "$GHOST_HOME/sources/history.source.zsh"
  source "$GHOST_HOME/sources/typo.source.zsh"
  source "$GHOST_HOME/core/ghost-core.zsh"
  _ghost_boot
}

autoload -Uz add-zle-hook-widget 2>/dev/null || true

if [[ -o interactive ]]; then
  zle -N _ghost_lazy_init 2>/dev/null || true
  add-zle-hook-widget line-pre-redraw _ghost_lazy_init 2>/dev/null || true
else
  _ghost_lazy_init
fi
