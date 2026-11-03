#!/usr/bin/env zsh
# ziro-ghost — health command (M9: produces JSON for ziro-shell protocol v1)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M9)

_ghost_health_json() {
  emulate -L zsh
  local overall_status='ok'
  local -a checks=()
  local checks_json=''

  # Check 1: cache dir
  local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
  if [[ -d $cache_root ]]; then
    local perm
    if whence -p stat >/dev/null 2>&1; then
      perm=$(stat -c '%a' "$cache_root" 2>/dev/null)
    else
      zmodload zsh/stat 2>/dev/null || true
      local -A st
      zstat -A st +mode "$cache_root" 2>/dev/null
      perm=$(printf '%o' $(( st[mode] & 0777 )))
    fi
    if [[ $perm == '700' ]]; then
      checks+=("{\"name\":\"cache_dir\",\"status\":\"ok\",\"message\":\"$cache_root (700)\"}")
    else
      checks+=("{\"name\":\"cache_dir\",\"status\":\"warn\",\"message\":\"$cache_root ($perm — expected 700)\"}")
      [[ $overall_status == 'ok' ]] && overall_status='warn'
    fi
  else
    checks+=("{\"name\":\"cache_dir\",\"status\":\"error\",\"message\":\"$cache_root missing\"}")
    overall_status='error'
  fi

  # Check 2: cache files perms
  local -a cfiles=($cache_root/*-cache(N))
  local files=${#cfiles}
  local bad=0
  local f="" p_mode=""
  for f in "${cfiles[@]}"; do
    if whence -p stat >/dev/null 2>&1; then
      p_mode=$(stat -c '%a' "$f" 2>/dev/null)
    else
      local -A st
      zstat -A st +mode "$f" 2>/dev/null
      p_mode=$(printf '%o' $(( st[mode] & 0777 )))
    fi
    [[ $p_mode != '600' ]] && (( bad++ ))
  done
  if (( bad == 0 )); then
    checks+=("{\"name\":\"cache_files\",\"status\":\"ok\",\"message\":\"$files files, all 600\"}")
  else
    checks+=("{\"name\":\"cache_files\",\"status\":\"warn\",\"message\":\"$bad files not 600\"}")
    [[ $overall_status == 'ok' ]] && overall_status='warn'
  fi

  # Check 3: metrics file
  local mfile="$cache_root/metrics.jsonl"
  if [[ -f $mfile ]]; then
    local msize mlines
    if whence -p stat >/dev/null 2>&1; then
      msize=$(stat -c '%s' "$mfile" 2>/dev/null)
    else
      msize=$(wc -c < "$mfile" 2>/dev/null | tr -d ' ')
    fi
    mlines=$(wc -l < "$mfile" 2>/dev/null | tr -d ' ')
    checks+=("{\"name\":\"metrics\",\"status\":\"ok\",\"message\":\"${msize}B, ${mlines} lines\"}")
  else
    checks+=("{\"name\":\"metrics\",\"status\":\"info\",\"message\":\"not yet created\"}")
  fi

  # Check 4: binary
  local repo_dir="${${(%):-%x}:A:h:h}"
  local bin=""
  local -a candidates=(
    "$repo_dir/target/release/ghost-popup"
    "$repo_dir/crates/ghost-popup/target/release/ghost-popup"
    "${GHOST_HOME:-$HOME/Projects/ziro-ghost}/target/release/ghost-popup"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then
      bin="$c"
      break
    fi
  done
  if [[ -z "$bin" ]]; then
    bin="$(whence -p ghost-popup 2>/dev/null || true)"
  fi

  if [[ -n "$bin" && -x "$bin" ]]; then
    local bsize
    if whence -p stat >/dev/null 2>&1; then
      bsize=$(stat -c '%s' "$bin" 2>/dev/null)
    else
      bsize=$(wc -c < "$bin" 2>/dev/null | tr -d ' ')
    fi
    checks+=("{\"name\":\"binary\",\"status\":\"ok\",\"message\":\"$(( bsize / 1024 ))KB\"}")
  else
    checks+=("{\"name\":\"binary\",\"status\":\"info\",\"message\":\"not built (fallback active)\"}")
  fi

  # Check 5: ziro-defer
  if (( $+functions[ziro-defer] )); then
    checks+=("{\"name\":\"ziro_defer\",\"status\":\"ok\",\"message\":\"available (stage 5 warmup)\"}")
  else
    checks+=("{\"name\":\"ziro_defer\",\"status\":\"ok\",\"message\":\"info: unavailable (precmd fallback active)\"}")
  fi

  # Check 6: sources registered
  local -a req_sources=(history typo project zoxide)
  local n_sources=0
  local s
  for s in "${req_sources[@]}"; do
    if (( ${+_GHOST_SOURCE_CACHE[$s]} )) || (( ${+_GHOST_SOURCES[$s]} )); then
      (( n_sources++ ))
    fi
  done
  if (( n_sources >= 4 )); then
    checks+=("{\"name\":\"sources\",\"status\":\"ok\",\"message\":\"$n_sources registered\"}")
  else
    checks+=("{\"name\":\"sources\",\"status\":\"warn\",\"message\":\"only $n_sources registered\"}")
    [[ $overall_status == 'ok' ]] && overall_status='warn'
  fi

  # Check 7: gateway processors
  local -a req_procs=(validate authorize audit protect)
  local n_procs=0
  local proc_name=""
  for proc_name in "${req_procs[@]}"; do
    if (( ${+_GHOST_PROCESSORS[$proc_name]} )); then
      (( n_procs++ ))
    fi
  done
  if (( n_procs >= 4 )); then
    checks+=("{\"name\":\"gateway\",\"status\":\"ok\",\"message\":\"$n_procs processors\"}")
  else
    checks+=("{\"name\":\"gateway\",\"status\":\"warn\",\"message\":\"only $n_procs processors\"}")
    [[ $overall_status == 'ok' ]] && overall_status='warn'
  fi

  # Check 8: metrics buffer
  local buf_size=${#_GHOST_METRICS_BUFFER}
  local drops=${_GHOST_METRICS_DROP_COUNT:-0}
  if (( buf_size <= 100 )) && (( drops == 0 )); then
    checks+=("{\"name\":\"buffer\",\"status\":\"ok\",\"message\":\"${buf_size} buffered, 0 dropped\"}")
  else
    checks+=("{\"name\":\"buffer\",\"status\":\"warn\",\"message\":\"drops=${drops}\"}")
    [[ $overall_status == 'ok' ]] && overall_status='warn'
  fi

  # Build JSON (pure Zsh, no fork)
  local IFS=','
  checks_json="${checks[*]}"
  unset IFS
  local version="${GHOST_VERSION:-2.0.0-M9}"
  print -r -- "{\"status\":\"$overall_status\",\"message\":\"ghost $version healthy check\",\"version\":\"$version\",\"checks\":[$checks_json]}"
}

_ghost_health_cli() {
  emulate -L zsh
  case "$1" in
    --json)
      _ghost_health_json
      ;;
    '')
      _ghost_health_json | python3 -m json.tool 2>/dev/null || _ghost_health_json
      ;;
    *)
      print -u2 "Usage: ghost health [--json]"
      return 1
      ;;
  esac
}
