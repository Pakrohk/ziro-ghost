# ziro-ghost v2.0.0 — Dependency Graph & Kahn's Algorithm (EVOID IOP)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M5)
# Manages source dependency graphs, topological ordering, and cycle detection.

typeset -gA _GHOST_DEP_NODES=()
typeset -gA _GHOST_DEP_PREREQS=()
typeset -gA _GHOST_DEP_CHILDREN=()
typeset -gA _GHOST_DEP_INDEGREE=()

_ghost_dep_reset() {
  emulate -L zsh
  _GHOST_DEP_NODES=()
  _GHOST_DEP_PREREQS=()
  _GHOST_DEP_CHILDREN=()
  _GHOST_DEP_INDEGREE=()
}

_ghost_dep_add() {
  emulate -L zsh
  local node="$1"
  shift 2>/dev/null || true
  local -a deps=($@)

  [[ -z "$node" ]] && return 1

  _GHOST_DEP_NODES[$node]=1
  _GHOST_DEP_PREREQS[$node]="${(j: :)deps}"

  (( ${+_GHOST_DEP_INDEGREE[$node]} )) || _GHOST_DEP_INDEGREE[$node]=0

  local dep
  for dep in "${deps[@]}"; do
    [[ -z "$dep" ]] && continue
    _GHOST_DEP_NODES[$dep]=1
    (( ${+_GHOST_DEP_INDEGREE[$dep]} )) || _GHOST_DEP_INDEGREE[$dep]=0

    _GHOST_DEP_CHILDREN[$dep]="${_GHOST_DEP_CHILDREN[$dep]:-} $node"
    _GHOST_DEP_INDEGREE[$node]=$(( ${_GHOST_DEP_INDEGREE[$node]:-0} + 1 ))
  done

  return 0
}

_ghost_dep_topo_sort() {
  emulate -L zsh
  local -A indeg=()
  local n
  for n in "${(@k)_GHOST_DEP_NODES}"; do
    indeg[$n]=${_GHOST_DEP_INDEGREE[$n]:-0}
  done

  local -a queue=() result=()
  for n in "${(@k)indeg}"; do
    (( indeg[$n] == 0 )) && queue+=("$n")
  done

  # Deterministic sorting
  queue=(${(o)queue})

  local cur="" child=""
  local -a children=()

  while (( ${#queue} > 0 )); do
    cur="${queue[1]}"
    queue=("${queue[@]:1}")
    result+=("$cur")

    children=(${(s: :)_GHOST_DEP_CHILDREN[$cur]})
    for child in "${children[@]}"; do
      [[ -z "$child" ]] && continue
      indeg[$child]=$(( indeg[$child] - 1 ))
      if (( indeg[$child] == 0 )); then
        queue+=("$child")
        queue=(${(o)queue})
      fi
    done
  done

  if (( ${#result} < ${#indeg} )); then
    print -r -- "CYCLE"
    return 1
  fi

  print -r -- "${(j: :)result}"
  return 0
}

_ghost_dep_find_cycle() {
  emulate -L zsh
  local order
  order="$(_ghost_dep_topo_sort 2>/dev/null)" || true

  if [[ "$order" == "CYCLE" ]]; then
    local -A indeg=()
    local n
    for n in "${(@k)_GHOST_DEP_NODES}"; do
      indeg[$n]=${_GHOST_DEP_INDEGREE[$n]:-0}
    done

    local -a queue=()
    for n in "${(@k)indeg}"; do
      (( indeg[$n] == 0 )) && queue+=("$n")
    done

    local cur="" child=""
    local -a children=()

    while (( ${#queue} > 0 )); do
      cur="${queue[1]}"
      queue=("${queue[@]:1}")
      children=(${(s: :)_GHOST_DEP_CHILDREN[$cur]})
      for child in "${children[@]}"; do
        [[ -z "$child" ]] && continue
        indeg[$child]=$(( indeg[$child] - 1 ))
        (( indeg[$child] == 0 )) && queue+=("$child")
      done
    done

    local -a remaining=()
    for n in "${(@k)indeg}"; do
      (( indeg[$n] > 0 )) && remaining+=("$n")
    done
    remaining=(${(o)remaining})
    print -r -- "${(j: :)remaining}"
    return 1
  fi

  return 0
}
