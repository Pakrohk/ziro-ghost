#!/usr/bin/env zsh
# ziro-ghost — Typo Correction Suggestion Source
# Layer: Sources · Spec: 009 v0.2.0 (FR-008, R18) · Version: 0.6.0
# Fallback-only suggestion source: fires when primary sources return no matches.

# ─── Static lookup table for common shell typos ───
typeset -gA _ghost_typo_static=(
  # Shell & root commands
  sdu     sudo
  suod    sudo
  sdo     sudo
  cd..    "cd .."
  mdkir   mkdir
  mkdri   mkdir
  mkir    mkdir
  # Git
  gti     git
  got     git
  gi      git
  gitp    "git push"
  # Docker
  dokcer  docker
  doker   docker
  dcoker  docker
  # Navigation & listing
  sl      ls
  lss     ls
  la      "ls -la"
  # Package managers
  pnmp    pnpm
  nmp     npm
  yran    yarn
  carog   cargo
  cagro   cargo
  pytohn  python
  pyhton  python
  pythno  python
  pyp     pip
  ppi     pip
  # Text & file utils
  gerp    grep
  grpe    grep
  gpre    grep
  ct      cat
  cta     cat
  # Misc
  ehco    echo
  ecoh    echo
  mak     make
  amke    make
)

# ─── Keyboard distance: QWERTY adjacent key neighbors ───
typeset -gA _ghost_kbd_neighbors=(
  q 'wa'    w 'qeas'   e 'wrsd'   r 'etdf'   t 'ryfg'
  y 'tugh'  u 'yihj'   i 'uojk'   o 'ipkl'   p 'ol'
  a 'qwsxz' s 'qwedxza' d 'wersfxc' f 'ertgvc' g 'rtyhbv'
  h 'tyujnb' j 'uiokmn' k 'iolm'   l 'opk'
  z 'asx'   x 'zsdc'   c 'xdfv'   v 'cfgb'   b 'vghn'
  n 'bhjm'  m 'njk'
)

# ─── Levenshtein Distance (bounded, pure Zsh) ───
_ghost_levenshtein_bounded() {
  emulate -L zsh
  local s="$1" t="$2"
  local -i max="${3:-2}"
  local -i m=${#s} n=${#t}

  # Quick reject: length difference > max
  if (( m - n > max || n - m > max )); then
    print $(( max + 1 ))
    return 0
  fi

  (( m == 0 )) && { print $n; return 0; }
  (( n == 0 )) && { print $m; return 0; }

  local -a prev curr
  local -i i j cost

  for (( j = 0; j <= n; j++ )); do
    prev[j+1]=$j
  done

  for (( i = 1; i <= m; i++ )); do
    curr[1]=$i
    local -i row_min=$i
    for (( j = 1; j <= n; j++ )); do
      if [[ "${s[i]}" == "${t[j]}" ]]; then
        cost=0
      else
        cost=1
      fi
      local -i del=$(( prev[j+1] + 1 ))
      local -i ins=$(( curr[j] + 1 ))
      local -i sub=$(( prev[j] + cost ))
      local -i min=$del
      (( ins < min )) && min=$ins
      (( sub < min )) && min=$sub
      curr[j+1]=$min
      (( min < row_min )) && row_min=$min
    done

    if (( row_min > max )); then
      print $(( max + 1 ))
      return 0
    fi
    prev=("${curr[@]}")
  done

  print "${prev[n+1]}"
}

# ─── Damerau (adjacent transposition check) ───
_ghost_is_transposition() {
  emulate -L zsh
  local s="$1" t="$2"
  (( ${#s} == ${#t} )) || return 1
  local -i i diffs=0 first=-1 second=-1
  for (( i = 1; i <= ${#s}; i++ )); do
    if [[ "${s[i]}" != "${t[i]}" ]]; then
      (( diffs++ ))
      if (( diffs == 1 )); then
        first=$i
      elif (( diffs == 2 )); then
        second=$i
      else
        return 1
      fi
    fi
  done
  (( diffs == 2 )) || return 1
  (( second - first == 1 )) || return 1
  [[ "${s[first]}" == "${t[second]}" && "${s[second]}" == "${t[first]}" ]] && return 0
  return 1
}

# ─── Keyboard-distance heuristic ───
_ghost_kbd_close() {
  emulate -L zsh
  local s="$1" t="$2"
  if (( ${#s} == ${#t} )); then
    local -i i diffs=0
    local c1="" c2=""
    for (( i = 1; i <= ${#s}; i++ )); do
      if [[ "${s[i]}" != "${t[i]}" ]]; then
        (( diffs++ ))
        (( diffs > 1 )) && return 1
        c1="${s[i]}"
        c2="${t[i]}"
      fi
    done
    if (( diffs == 1 )); then
      local neighbors="${_ghost_kbd_neighbors[$c1]:-}"
      [[ "$neighbors" == *"$c2"* ]] && return 0
    fi
  fi
  return 1
}

# ─── Candidate generation ───
_ghost_typo_candidates() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  (( ${#query} < 2 )) && return 1

  # Layer 1: Static map
  if [[ -n "${_ghost_typo_static[$query]:-}" ]]; then
    local repl="${_ghost_typo_static[$query]}"
    _ghost_results+=("5:typo:$repl")
    print -rl -- "${_ghost_results[@]}"
    return 0
  fi

  # Layer 2: Common commands algorithmic correction
  local -a common_commands=(
    sudo ls cd pwd mkdir rm cp mv cat grep find
    git docker kubectl uv pnpm npm yarn cargo go pip brew
    python python3 pip3 node make cmake systemctl journalctl
    vim nvim emacs code ssh scp rsync curl wget
    tar gzip unzip zip ffmpeg imagemagick
  )

  local -a matches=()
  local cmd dist
  for cmd in "${common_commands[@]}"; do
    (( ${#cmd} - ${#query} > 2 || ${#query} - ${#cmd} > 2 )) && continue

    # 1. Transposition
    if _ghost_is_transposition "$query" "$cmd"; then
      matches+=("$cmd")
      continue
    fi

    # 2. Keyboard distance
    if _ghost_kbd_close "$query" "$cmd"; then
      matches+=("$cmd")
      continue
    fi

    # 3. Levenshtein bounded at 2
    dist=$(_ghost_levenshtein_bounded "$query" "$cmd" 2)
    (( dist <= 2 )) && matches+=("$cmd")
  done

  (( ${#matches} == 0 )) && return 1

  local m
  for m in "${(@u)matches}"; do
    _ghost_results+=("5:typo:$m")
  done

  print -rl -- "${_ghost_results[@]}"
  return 0
}

# ─── Main query interface ───
_ghost_typo_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()

  # Check config: if mode is off or correction disabled
  if (( ${+functions[_ghost_config_get]} )); then
    local enabled="$(_ghost_config_get "correction.enabled" "true")"
    [[ "$enabled" == "false" || "$enabled" == "0" ]] && return 1
    local mode="$(_ghost_config_get "correction.mode" "suggest")"
    [[ "$mode" == "off" ]] && return 1
  fi

  _ghost_typo_candidates "$query"
}

# Public alias
ghost_typo_query() {
  emulate -L zsh
  _ghost_typo_query "$@"
}

# ─── Register source in IOP with --fallback-only ───
if (( ${+functions[ghost_register_source]} )); then
  ghost_register_source typo \
    --intent "correct common command typos when primary sources yield no results" \
    --handler _ghost_typo_query \
    --weight 5 \
    --kind typo \
    --enabled true \
    --fallback-only
fi
