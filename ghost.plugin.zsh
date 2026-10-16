#!/usr/bin/env zsh
# ziro-ghost — standalone IDE-like autocomplete for Zsh
# Version: 1.0.0
# Repository: https://github.com/Pakrohk/ziro-ghost
# License: MIT
#
# This plugin can be sourced standalone:
#   source /path/to/ghost.plugin.zsh
# Or via znap:
#   znap source Pakrohk/ziro-ghost

# Guard: prevent double-loading
(( ${+functions[_ghost_boot]} )) && return 0

# ─── Hoist standard modules (Spec 011 Cat 7) ───
zmodload zsh/datetime 2>/dev/null || true

# ─── Resolve plugin root ───
typeset -g GHOST_HOME="${${(%):-%x}:A:h}"

# ─── Load core (Kind system + IOP registry + config + lifecycle) ───
source "$GHOST_HOME/core/ghost-kinds.zsh"
source "$GHOST_HOME/core/ghost-registry.zsh"
source "$GHOST_HOME/core/ghost-config.zsh"
source "$GHOST_HOME/core/ghost-core.zsh"

# ─── Load engine (matcher + comparator) ───
source "$GHOST_HOME/engine/matcher.zsh"
source "$GHOST_HOME/engine/comparator.zsh"

# ─── Load UI (inline + popup + preview + docs + loading) ───
source "$GHOST_HOME/ui/inline.ui.zsh"
source "$GHOST_HOME/ui/popup.ui.zsh"
source "$GHOST_HOME/ui/preview.ui.zsh"
source "$GHOST_HOME/ui/docs.ui.zsh"
source "$GHOST_HOME/ui/loading.ui.zsh"

# ─── Load sources (each registers itself via registry) ───
source "$GHOST_HOME/sources/history.source.zsh"
source "$GHOST_HOME/sources/project.source.zsh"
source "$GHOST_HOME/sources/subcommand.source.zsh"
source "$GHOST_HOME/sources/completions.source.zsh"
source "$GHOST_HOME/sources/typo.source.zsh"
source "$GHOST_HOME/sources/zoxide.source.zsh"

# ─── Load helpers ───
source "$GHOST_HOME/lib/helpers.zsh"

# ─── Boot ───
_ghost_boot
