#!/usr/bin/env zsh
# ziro-ghost — Project context source (M6: async, chpwd-refreshed)
# Layer: Sources · Spec: 010 (M6)

typeset -g _GHOST_PROJECT_KIND=''
typeset -g _GHOST_PROJECT_LAST_PWD=''

_ghost_source_project_detect() {
  emulate -L zsh
  # Cache key: current PWD. If same as last, skip.
  [[ "${_GHOST_PROJECT_LAST_PWD:-}" == "$PWD" ]] && return 0
  typeset -g _GHOST_PROJECT_LAST_PWD="$PWD"
  _GHOST_PROJECT_KIND=''

  if [[ -f Cargo.toml ]]; then
    _GHOST_PROJECT_KIND='rust'
  elif [[ -f pyproject.toml ]]; then
    _GHOST_PROJECT_KIND='python'
  elif [[ -f package.json ]]; then
    _GHOST_PROJECT_KIND='npm'
  elif [[ -d .git || -f .git ]]; then
    _GHOST_PROJECT_KIND='git'
  fi
}

_ghost_source_project_refresh() {
  emulate -L zsh
  _ghost_source_project_detect
  case "$_GHOST_PROJECT_KIND" in
    rust)   print -l 'cargo build' 'cargo test' 'cargo run' 'cargo clippy' 'cargo fmt' ;;
    python) print -l 'pytest' 'python -m pytest' 'pytest -v' ;;
    npm)    print -l 'npm test' 'npm run' 'npm install' ;;
    git)    print -l 'git status' 'git log --oneline' 'git diff' 'git stash' ;;
  esac
}

if (( ${+functions[_ghost_source_register]} )); then
  _ghost_source_register project 70 _ghost_source_project_refresh
fi

# Refresh on chpwd (project context changes)
_ghost_source_project_chpwd() {
  emulate -L zsh
  typeset -g _GHOST_PROJECT_LAST_PWD=""
  (( ${+functions[_ghost_source_refresh]} )) && _ghost_source_refresh project
}
autoload -Uz add-zsh-hook 2>/dev/null
if (( ${+functions[add-zsh-hook]} )); then
  add-zsh-hook chpwd _ghost_source_project_chpwd 2>/dev/null || true
fi

# M7: warmup deferred to ziro-defer stage 5 (see core/ghost-defer.zsh)
