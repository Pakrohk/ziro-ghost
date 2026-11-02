#!/usr/bin/env zsh
# ziro-ghost v1.0.3 — Minimal Ghost Line
# Repository: https://github.com/Pakrohk/ziro-ghost
# License: MIT
#
# This is a MINIMAL version. Only inline gray suggestions.
# Full featured version (popup, focus mode) coming in v2.0.0.

zmodload zsh/datetime 2>/dev/null || true

(( ${+_GHOST_LOADED} )) && return 0
typeset -g _GHOST_LOADED=1
typeset -g GHOST_HOME="${${(%):-%x}:A:h}"

source "$GHOST_HOME/core/ghost-version.zsh"
source "$GHOST_HOME/core/ghost-config.zsh"
source "$GHOST_HOME/core/ghost-kinds.zsh"
source "$GHOST_HOME/core/ghost-bus.zsh"
source "$GHOST_HOME/core/ghost-gateway.zsh"
source "$GHOST_HOME/core/ghost-dependency.zsh"
source "$GHOST_HOME/core/ghost-cache.zsh"
source "$GHOST_HOME/core/ghost-source-registry.zsh"
source "$GHOST_HOME/core/ghost-registry.zsh"
source "$GHOST_HOME/lib/ghost-color.zsh"
source "$GHOST_HOME/ui/inline.ui.zsh"
source "$GHOST_HOME/sources/history.source.zsh"
source "$GHOST_HOME/sources/typo.source.zsh"
source "$GHOST_HOME/sources/project.source.zsh"
source "$GHOST_HOME/sources/zoxide.source.zsh"
source "$GHOST_HOME/core/ghost-core.zsh"

ghost() {
  emulate -L zsh
  local cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    cache)
      _ghost_cache_cli "$@"
      ;;
    suggest)
      _ghost_suggest "$@"
      ;;
    *)
      print -r -- "Usage: ghost {cache|suggest|popup|stats}"
      return 1
      ;;
  esac
}

_ghost_boot
_ghost_color_cache_init 2>/dev/null || true
_ghost_cache_init 2>/dev/null || true
_ghost_gateway_init 2>/dev/null || true

# M7: defer cache warmup to ziro-defer stage 5 (or first precmd fallback)
source "$GHOST_HOME/core/ghost-defer.zsh"
