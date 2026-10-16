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
