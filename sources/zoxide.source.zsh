#!/usr/bin/env zsh
# ziro-ghost — Zoxide source (M6: async, precmd-refreshed every 5s)
# Layer: Sources · Spec: 010 (M6)

typeset -g _GHOST_ZOXIDE_AVAILABLE=0
typeset -g _GHOST_ZOXIDE_CHECKED=0
typeset -g _GHOST_ZOXIDE_LAST_REFRESH=0

_ghost_source_zoxide_check() {
  emulate -L zsh
  _GHOST_ZOXIDE_AVAILABLE=0
  if (( $+commands[zoxide] )); then
    local zdb="${_ZO_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zoxide}/db.zo"
    [[ -f "$zdb" ]] && _GHOST_ZOXIDE_AVAILABLE=1
  fi
  typeset -g _GHOST_ZOXIDE_CHECKED=1
}

_ghost_source_zoxide_refresh() {
  emulate -L zsh
  (( _GHOST_ZOXIDE_CHECKED )) || _ghost_source_zoxide_check
  [[ $_GHOST_ZOXIDE_AVAILABLE -eq 1 ]] || return 0
  zmodload zsh/datetime 2>/dev/null || true
  local now=${EPOCHSECONDS:-$(date +%s)}

  # Refresh at most every 5s
  if (( now - _GHOST_ZOXIDE_LAST_REFRESH < 5 )) && (( _GHOST_ZOXIDE_LAST_REFRESH > 0 )); then
    return 0
  fi
  _GHOST_ZOXIDE_LAST_REFRESH=$now

  # Fork happens HERE (precmd) — off keystroke path
  local -a top=(${(f)"$(zoxide query -l 2>/dev/null | head -20)"})
  [[ ${#top} -gt 0 ]] && print -l -- "${top[@]}"
}

if (( ${+functions[_ghost_source_register]} )); then
  _ghost_source_register zoxide 50 _ghost_source_zoxide_refresh
fi

# Refresh in precmd (background off keystroke path)
_ghost_source_zoxide_precmd() {
  emulate -L zsh
  (( ${+functions[_ghost_source_refresh]} )) && _ghost_source_refresh zoxide
}
autoload -Uz add-zsh-hook 2>/dev/null
if (( ${+functions[add-zsh-hook]} )); then
  add-zsh-hook precmd _ghost_source_zoxide_precmd 2>/dev/null || true
fi
