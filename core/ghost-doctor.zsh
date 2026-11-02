#!/usr/bin/env zsh
# ziro-ghost — standalone doctor diagnostics (M8)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M8)

_ghost_doctor_file_mode() {
  local f="$1"
  if whence -p stat >/dev/null 2>&1; then
    stat -c '%a' "$f" 2>/dev/null
  else
    zmodload zsh/stat 2>/dev/null || true
    local -A st
    zstat -A st +mode "$f" 2>/dev/null
    printf '%o\n' $(( st[mode] & 0777 ))
  fi
}

_ghost_doctor_file_size() {
  local f="$1"
  if whence -p stat >/dev/null 2>&1; then
    stat -c '%s' "$f" 2>/dev/null
  else
    wc -c < "$f" 2>/dev/null | tr -d ' '
  fi
}

_ghost_doctor_cli() {
  emulate -L zsh
  local passed=0
  local errors=0
  local info_count=0

  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"

  # 1. cache_dir: exists and 700
  if [[ -d "$cache_dir" ]]; then
    local cdir_mode
    cdir_mode=$(_ghost_doctor_file_mode "$cache_dir")
    if [[ "$cdir_mode" == "700" ]]; then
      print -r -- "✅ OK cache_dir: $cache_dir ($cdir_mode)"
      (( ++passed ))
    else
      print -r -- "❌ ERROR cache_dir: bad permissions on $cache_dir (expected 700, got $cdir_mode)"
      (( ++errors ))
    fi
  else
    print -r -- "❌ ERROR cache_dir: directory does not exist: $cache_dir"
    (( ++errors ))
  fi

  # 2. cache_files_perms: each *-cache file is 600
  local -a cfiles=($cache_dir/*-cache(N))
  if (( ${#cfiles} == 0 )); then
    print -r -- "✅ OK cache_files: 0 files (none created yet)"
    (( ++passed ))
  else
    local all_600=1
    local bad_file="" bad_mode=""
    local f
    for f in "${cfiles[@]}"; do
      local fmode
      fmode=$(_ghost_doctor_file_mode "$f")
      if [[ "$fmode" != "600" ]]; then
        all_600=0
        bad_file="$f"
        bad_mode="$fmode"
        break
      fi
    done
    if (( all_600 )); then
      print -r -- "✅ OK cache_files: ${#cfiles} files, all 600"
      (( ++passed ))
    else
      print -r -- "❌ ERROR cache_files: bad permissions on ${bad_file:t} (expected 600, got $bad_mode)"
      (( ++errors ))
    fi
  fi

  # 3. metrics_file: exists (if sessions ran), 600, size <10MB
  local metrics_file="${_GHOST_METRICS_FILE:-$cache_dir/metrics.jsonl}"
  if [[ -f "$metrics_file" ]]; then
    local mmode msize mlines
    mmode=$(_ghost_doctor_file_mode "$metrics_file")
    msize=$(_ghost_doctor_file_size "$metrics_file")
    mlines=$(wc -l < "$metrics_file" 2>/dev/null | tr -d ' ')
    local drops="${_GHOST_METRICS_DROP_COUNT:-0}"
    local size_kb=$(( (msize + 1023) / 1024 ))

    if [[ "$mmode" == "600" ]] && (( msize < 10485760 )); then
      print -r -- "✅ OK metrics: ${size_kb}KB, ${mlines} lines, ${drops} dropped"
      (( ++passed ))
    else
      print -r -- "❌ ERROR metrics: invalid state (mode=$mmode expected 600, size=${size_kb}KB)"
      (( ++errors ))
    fi
  else
    print -r -- "ℹ️  INFO metrics: metrics.jsonl not yet created"
    (( ++info_count ))
  fi

  # 4. ghost_popup_binary: binary exists and executable
  local bin_path="${_GHOST_DOCTOR_BINARY_OVERRIDE:-}"
  if [[ -z "$bin_path" ]]; then
    local repo_root="${${(%):-%x}:A:h:h}"
    local -a candidates=(
      "$repo_root/target/release/ghost-popup"
      "$repo_root/crates/ghost-popup/target/release/ghost-popup"
      "${GHOST_HOME:-$HOME/Projects/ziro-ghost}/target/release/ghost-popup"
    )
    local c
    for c in "${candidates[@]}"; do
      if [[ -x "$c" ]]; then
        bin_path="$c"
        break
      fi
    done
    if [[ -z "$bin_path" ]]; then
      bin_path="$(whence -p ghost-popup 2>/dev/null || true)"
    fi
  fi

  if [[ -n "$bin_path" && -x "$bin_path" ]]; then
    local bsize
    bsize=$(ls -lh "$bin_path" 2>/dev/null | awk '{print $5}')
    print -r -- "✅ OK ghost_popup: ${bsize} at $bin_path"
    (( ++passed ))
  else
    print -r -- "❌ ERROR ghost_popup: binary not found or not executable"
    (( ++errors ))
  fi

  # 5. ziro_defer_available: ziro-defer function availability
  if (( $+functions[ziro-defer] )); then
    print -r -- "✅ OK ziro-defer: available (stage-5 integration active)"
    (( ++passed ))
  else
    print -r -- "ℹ️  INFO ziro-defer: unavailable (standalone mode — precmd fallback active)"
    (( ++info_count ))
  fi

  # 6. sources_registered: 4 sources (history, typo, project, zoxide)
  local -a req_sources=(history typo project zoxide)
  local missing_sources=()
  local s
  for s in "${req_sources[@]}"; do
    if (( ! ${+_GHOST_SOURCE_CACHE[$s]} )) && (( ! ${+_GHOST_SOURCES[$s]} )); then
      missing_sources+=("$s")
    fi
  done
  if (( ${#missing_sources} == 0 )); then
    print -r -- "✅ OK sources: 4 registered (history, typo, project, zoxide)"
    (( ++passed ))
  else
    print -r -- "❌ ERROR sources: missing registered sources: ${missing_sources[*]}"
    (( ++errors ))
  fi

  # 7. gateway_processors: 4 processors in _GHOST_PROCESSORS
  local -a req_proc=(validate authorize audit protect)
  local missing_proc=()
  local p
  for p in "${req_proc[@]}"; do
    if (( ! ${+_GHOST_PROCESSORS[$p]} )); then
      missing_proc+=("$p")
    fi
  done
  if (( ${#missing_proc} == 0 )); then
    print -r -- "✅ OK gateway: 4 processors"
    (( ++passed ))
  else
    print -r -- "❌ ERROR gateway: missing processors: ${missing_proc[*]}"
    (( ++errors ))
  fi

  # 8. metrics_buffer_health: buffer <= 100, drops counted
  local buf_size=${#_GHOST_METRICS_BUFFER}
  local drop_cnt=${_GHOST_METRICS_DROP_COUNT:-0}
  if (( buf_size <= _GHOST_METRICS_MAX_BUFFER )); then
    print -r -- "✅ OK metrics_buffer: ${buf_size}/${_GHOST_METRICS_MAX_BUFFER} buffer size, ${drop_cnt} dropped"
    (( ++passed ))
  else
    print -r -- "❌ ERROR metrics_buffer: buffer overflowed (${buf_size} > ${_GHOST_METRICS_MAX_BUFFER})"
    (( ++errors ))
  fi

  print -r -- "---"
  local status_str="HEALTHY"
  if (( errors > 0 )); then
    status_str="UNHEALTHY"
  fi
  print -r -- "${passed}/$(( passed + errors )) passed, ${info_count} info, ${errors} errors — ${status_str}"

  if (( errors > 0 )); then
    return 1
  fi
  return 0
}
