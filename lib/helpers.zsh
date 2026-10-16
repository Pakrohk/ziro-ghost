#!/usr/bin/env zsh
# ziro-ghost — Shell Helpers & Shortcuts
# Layer: Lib · Spec: 009 v0.2.0 · Version: 0.9.0

_ghost_j() {
  emulate -L zsh
  if ! (( $+commands[zoxide] )); then
    print -u2 "j: zoxide not installed"
    return 1
  fi

  if ! (( $+commands[fzf] )); then
    # Fallback: jump to best match without fzf
    local target
    target="$(zoxide query "$@" 2>/dev/null)" || return $?
    if [[ -n "$target" && -d "$target" ]]; then
      cd "$target"
      return $?
    fi
    return 1
  fi

  # Interactive jump with fzf preview
  local raw_entry target
  raw_entry="$(
    zoxide query -ls 2>/dev/null | fzf \
      --height=40% \
      --reverse \
      --no-info \
      --prompt="Jump> " \
      --preview='ls -la {2..}' \
      --nth=2.. 2>/dev/null
  )" || return 0

  target="${raw_entry#*[[:space:]]}"
  target="${target#"${target%%[![:space:]]*}"}"
  if [[ -n "$target" && -d "$target" ]]; then
    cd "$target"
  fi
}

# Alias shortcut
alias j='_ghost_j'
