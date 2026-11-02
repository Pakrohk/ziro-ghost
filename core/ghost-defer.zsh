#!/usr/bin/env zsh
# ziro-ghost — ziro-defer integration (M7: defer warmup to stage 5)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M7)

# Detect ziro-defer availability
typeset -g _GHOST_DEFER_AVAILABLE=0
(( $+functions[ziro-defer] )) && _GHOST_DEFER_AVAILABLE=1

# The warmup command — does all cache population
_ghost_warmup() {
  emulate -L zsh
  _ghost_source_refresh history
  _ghost_source_refresh typo
  _ghost_source_refresh project
  _ghost_source_refresh zoxide
}

# Route warmup based on availability
_ghost_defer_warmup() {
  emulate -L zsh
  # Re-check in case ziro-defer was loaded after ghost-defer
  (( $+functions[ziro-defer] )) && _GHOST_DEFER_AVAILABLE=1

  if (( _GHOST_DEFER_AVAILABLE )); then
    # ziro-defer: stage 5 = after prompt, slot b = normal
    ziro-defer --stage=5 --slot=b --name="ghost-warmup" _ghost_warmup 2>/dev/null
    [[ -n $ZIRO_GHOST_DEBUG ]] && print -u2 'ghost: warmup deferred to ziro-defer stage 5'
  else
    # Standalone fallback: first precmd
    _ghost_defer_fallback_warmup() {
      emulate -L zsh
      _ghost_warmup
      # Remove self from precmd hooks after first run
      autoload -Uz add-zsh-hook 2>/dev/null
      (( $+functions[add-zsh-hook] )) && add-zsh-hook -d precmd _ghost_defer_fallback_warmup 2>/dev/null || true
    }
    autoload -Uz add-zsh-hook 2>/dev/null
    if (( $+functions[add-zsh-hook] )); then
      add-zsh-hook precmd _ghost_defer_fallback_warmup 2>/dev/null || true
      [[ -n $ZIRO_GHOST_DEBUG ]] && print -u2 'ghost: warmup deferred to first precmd (no ziro-defer)'
    else
      # Absolute last resort: run now (shell init)
      _ghost_warmup
      [[ -n $ZIRO_GHOST_DEBUG ]] && print -u2 'ghost: warmup ran at init (no ziro-defer, no add-zsh-hook)'
    fi
  fi
}

# Trigger defer (called from ghost.plugin.zsh after source registration)
_ghost_defer_warmup
