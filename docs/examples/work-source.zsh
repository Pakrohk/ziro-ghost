#!/usr/bin/env zsh
# Example: Work-specific commands suggestion source
# Place in: ~/.config/ziro/ghost/work-source.zsh

_ghost_work_commands() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  _ghost_result_kinds=()

  local -a work_cmds=(
    'deploy prod --tag latest'
    'deploy staging'
    'kubectl get pods -n production'
    'kubectl logs -f deploy/api'
    'pnpm nx run-many --target=test'
  )

  local cmd
  for cmd in "${work_cmds[@]}"; do
    if [[ -z "$query" || "$cmd" == "$query"* ]]; then
      _ghost_results+=("$cmd")
      _ghost_result_kinds+=(cmd)
    fi
  done

  (( ${#_ghost_results} > 0 ))
}
