#!/usr/bin/env zsh
# ziro-ghost — metrics aggregation and stats CLI (M8)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M8)

_ghost_stats_cli() {
  emulate -L zsh
  local json_out=0
  local since_filter=""
  local intent_filter=""
  local limit=1000

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        json_out=1
        ;;
      --since)
        shift
        since_filter="${1:-}"
        ;;
      --since=*)
        since_filter="${1#--since=}"
        ;;
      --intent)
        shift
        intent_filter="${1:-}"
        ;;
      --intent=*)
        intent_filter="${1#--intent=}"
        ;;
      --limit)
        shift
        limit="${1:-1000}"
        ;;
      --limit=*)
        limit="${1#--limit=}"
        ;;
      -h|--help)
        print -r -- "Usage: ghost stats [--json] [--since <dur>] [--intent <name>] [--limit <N>]"
        return 0
        ;;
    esac
    shift
  done

  # Flush buffered metrics first so stats include recent events
  (( ${+functions[_ghost_metrics_flush]} )) && _ghost_metrics_flush

  local metrics_file="${_GHOST_METRICS_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost/metrics.jsonl}"
  if [[ ! -f "$metrics_file" ]] || [[ ! -s "$metrics_file" ]]; then
    if (( json_out )); then
      print -r -- "{\"total_intents\":0,\"p50_ms\":0.0,\"p95_ms\":0.0,\"p99_ms\":0.0,\"cache_hit_rate\":0.0,\"error_count\":0,\"dropped_count\":${_GHOST_METRICS_DROP_COUNT:-0},\"session\":\"${_GHOST_SESSION_ID:-}\",\"intents\":{}}"
    else
      print -r -- "No metrics recorded yet in $metrics_file"
    fi
    return 0
  fi

  # Parse duration cutoff for --since
  local cutoff=0
  if [[ -n "$since_filter" ]]; then
    local now="${EPOCHSECONDS:-$(date +%s)}"
    local secs=0
    if [[ "$since_filter" =~ '^([0-9]+)h$' ]]; then
      secs=$(( match[1] * 3600 ))
    elif [[ "$since_filter" =~ '^([0-9]+)m$' ]]; then
      secs=$(( match[1] * 60 ))
    elif [[ "$since_filter" =~ '^([0-9]+)s?$' ]]; then
      secs=$(( match[1] ))
    fi
    (( secs > 0 )) && cutoff=$(( now - secs ))
  fi

  # Read last N lines
  local -a lines=(${(f)"$(tail -n "$limit" "$metrics_file" 2>/dev/null)"})

  typeset -A intent_counts intent_errors intent_hits
  typeset -A intent_durs_str
  local -a all_durs=()
  local total_count=0 total_errors=0 total_hits=0

  local line
  for line in "${lines[@]}"; do
    [[ -z "$line" ]] && continue
    local l_ts=0 l_name="" l_dur=0 l_status="ok" l_hit=false

    if [[ "$line" =~ '"ts"[[:space:]]*:[[:space:]]*([0-9.]+)' ]]; then
      l_ts="${match[1]}"
    fi
    if (( cutoff > 0 )) && (( l_ts > 0 && l_ts < cutoff )); then
      continue
    fi

    if [[ "$line" =~ '"name"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
      l_name="${match[1]}"
    fi
    if [[ -n "$intent_filter" ]] && [[ "$l_name" != "$intent_filter" ]]; then
      continue
    fi

    if [[ "$line" =~ '"duration_ms"[[:space:]]*:[[:space:]]*([0-9.]+)' ]]; then
      l_dur="${match[1]}"
    fi
    if [[ "$line" =~ '"status"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
      l_status="${match[1]}"
    fi
    if [[ "$line" =~ '"cache_hit"[[:space:]]*:[[:space:]]*(true|false)' ]]; then
      l_hit="${match[1]}"
    fi

    (( ++total_count ))
    (( ++intent_counts[$l_name] ))
    all_durs+=($l_dur)

    if [[ -n "${intent_durs_str[$l_name]}" ]]; then
      intent_durs_str[$l_name]+=" $l_dur"
    else
      intent_durs_str[$l_name]="$l_dur"
    fi

    if [[ "$l_status" != "ok" ]]; then
      (( ++total_errors ))
      (( ++intent_errors[$l_name] ))
    fi

    if [[ "$l_hit" == "true" ]]; then
      (( ++total_hits ))
      (( ++intent_hits[$l_name] ))
    fi
  done

  # Compute global percentiles
  all_durs=(${(on)all_durs})
  local global_p50=0 global_p95=0 global_p99=0
  if (( total_count > 0 )); then
    local i50=$(( (total_count * 50 + 99) / 100 ))
    local i95=$(( (total_count * 95 + 99) / 100 ))
    local i99=$(( (total_count * 99 + 99) / 100 ))
    (( i50 < 1 )) && i50=1; (( i50 > total_count )) && i50=$total_count
    (( i95 < 1 )) && i95=1; (( i95 > total_count )) && i95=$total_count
    (( i99 < 1 )) && i99=1; (( i99 > total_count )) && i99=$total_count
    global_p50="${all_durs[$i50]}"
    global_p95="${all_durs[$i95]}"
    global_p99="${all_durs[$i99]}"
    [[ "$global_p50" == *\. ]] && global_p50="${global_p50}0"
    [[ "$global_p95" == *\. ]] && global_p95="${global_p95}0"
    [[ "$global_p99" == *\. ]] && global_p99="${global_p99}0"
  fi

  local global_hit_rate=0.0
  if (( total_count > 0 )); then
    local raw_rate=$(( (total_hits * 100.0) / total_count ))
    global_hit_rate=$(printf "%.1f" "$raw_rate" 2>/dev/null || echo "$raw_rate")
    [[ "$global_hit_rate" == *\. ]] && global_hit_rate="${global_hit_rate}0"
  fi

  if (( json_out )); then
    local json_intents="{"
    local first_intent=1 iname
    for iname in ${(k)intent_counts}; do
      local icnt="${intent_counts[$iname]}"
      local ierr="${intent_errors[$iname]:-0}"
      local ihit="${intent_hits[$iname]:-0}"
      local -a idurs=(${=intent_durs_str[$iname]})
      idurs=(${(on)idurs})
      local ip50=0 ip95=0 ip99=0
      if (( icnt > 0 )); then
        local idx50=$(( (icnt * 50 + 99) / 100 ))
        local idx95=$(( (icnt * 95 + 99) / 100 ))
        local idx99=$(( (icnt * 99 + 99) / 100 ))
        (( idx50 < 1 )) && idx50=1; (( idx50 > icnt )) && idx50=$icnt
        (( idx95 < 1 )) && idx95=1; (( idx95 > icnt )) && idx95=$icnt
        (( idx99 < 1 )) && idx99=1; (( idx99 > icnt )) && idx99=$icnt
        ip50="${idurs[$idx50]}"
        ip95="${idurs[$idx95]}"
        ip99="${idurs[$idx99]}"
        [[ "$ip50" == *\. ]] && ip50="${ip50}0"
        [[ "$ip95" == *\. ]] && ip95="${ip95}0"
        [[ "$ip99" == *\. ]] && ip99="${ip99}0"
      fi
      local entry="\"${iname}\":{\"count\":${icnt},\"p50_ms\":${ip50},\"p95_ms\":${ip95},\"p99_ms\":${ip99},\"errors\":${ierr},\"cache_hits\":${ihit}}"
      if (( first_intent )); then
        json_intents+="$entry"
        first_intent=0
      else
        json_intents+=",$entry"
      fi
    done
    json_intents+="}"

    print -r -- "{\"total_intents\":${total_count},\"p50_ms\":${global_p50},\"p95_ms\":${global_p95},\"p99_ms\":${global_p99},\"cache_hit_rate\":${global_hit_rate},\"error_count\":${total_errors},\"dropped_count\":${_GHOST_METRICS_DROP_COUNT:-0},\"session\":\"${_GHOST_SESSION_ID:-}\",\"intents\":${json_intents}}"
    return 0
  fi

  # Table output
  printf "%-26s %-8s %-8s %-8s %-8s\n" "Intent" "Count" "P50(ms)" "P95(ms)" "Errors"
  printf "%-26s %-8s %-8s %-8s %-8s\n" "--------------------------" "--------" "--------" "--------" "--------"
  local iname
  for iname in ${(ok)intent_counts}; do
    local icnt="${intent_counts[$iname]}"
    local ierr="${intent_errors[$iname]:-0}"
    local -a idurs=(${=intent_durs_str[$iname]})
    idurs=(${(on)idurs})
    local ip50=0 ip95=0
    if (( icnt > 0 )); then
      local idx50=$(( (icnt * 50 + 99) / 100 ))
      local idx95=$(( (icnt * 95 + 99) / 100 ))
      (( idx50 < 1 )) && idx50=1; (( idx50 > icnt )) && idx50=$icnt
      (( idx95 < 1 )) && idx95=1; (( idx95 > icnt )) && idx95=$icnt
      ip50="${idurs[$idx50]}"
      ip95="${idurs[$idx95]}"
    fi
    printf "%-26s %-8d %-8.2f %-8.2f %-8d\n" "$iname" "$icnt" "$ip50" "$ip95" "$ierr"
  done
  print -r -- "---"
  print -r -- "Session: ${_GHOST_SESSION_ID:-$$}  |  Dropped: ${_GHOST_METRICS_DROP_COUNT:-0}  |  File: $metrics_file"
}

# Roll-up refresh into stats-cache
_ghost_source_stats_refresh() {
  emulate -L zsh
  (( $+functions[_ghost_metrics_flush] )) && _ghost_metrics_flush

  local metrics_file="${_GHOST_METRICS_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost/metrics.jsonl}"
  [[ -f "$metrics_file" ]] || return 0

  local -a lines=(${(f)"$(tail -n 500 "$metrics_file" 2>/dev/null)"})
  local total=${#lines}
  typeset -A sessions
  typeset -A intent_counts
  local line
  for line in "${lines[@]}"; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ '"name"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
      (( ++intent_counts[${match[1]}] ))
    fi
    if [[ "$line" =~ '"session"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
      sessions[${match[1]}]=1
    fi
  done

  local session_count=${#sessions}
  local now="${EPOCHSECONDS:-$(date +%s)}"

  local json_intents="{"
  local first=1 iname
  for iname in ${(k)intent_counts}; do
    local cnt="${intent_counts[$iname]}"
    if (( first )); then
      json_intents+="\"$iname\":$cnt"
      first=0
    else
      json_intents+=",\"$iname\":$cnt"
    fi
  done
  json_intents+="}"

  local payload="{\"computed_at\":$now,\"total_intents\":$total,\"session_count\":$session_count,\"per_intent\":$json_intents}"

  if (( ${+functions[_ghost_cache_put]} )); then
    _ghost_cache_put "stats" "$payload"
  else
    local cdir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
    [[ -d "$cdir" ]] || mkdir -p "$cdir" 2>/dev/null || true
    print -r -- "$payload" > "$cdir/stats-cache"
    chmod 600 "$cdir/stats-cache" 2>/dev/null || true
  fi
  _GHOST_SOURCE_CACHE[stats]="$payload"
}
