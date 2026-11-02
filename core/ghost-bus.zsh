# ziro-ghost v2.0.0 — Zsh Intent Bus (EVOID IOP)
# Layer: 1 (Zsh Core Engine)
# Connects in-process Zsh modules with out-of-process Rust sidecar via stdio NDJSON.

zmodload zsh/datetime 2>/dev/null || true

typeset -g _GHOST_BUS_AVAILABLE=0
typeset -g _GHOST_BUS_STARTED=0
typeset -g _GHOST_BUS_PID=0
typeset -gi _GHOST_BUS_FAILURES=0
typeset -g _GHOST_BUS_LAST_RESPONSE=""
typeset -gA _GHOST_HANDLERS=()
typeset -gi _ghost_intent_seq=0

_ghost_bus_binary_path() {
  emulate -L zsh
  local bin=""
  if [[ -n "${GHOST_HOME:-}" && -x "$GHOST_HOME/target/release/ghost-popup" ]]; then
    bin="$GHOST_HOME/target/release/ghost-popup"
  elif [[ -n "${GHOST_HOME:-}" && -x "$GHOST_HOME/bin/ghost-popup" ]]; then
    bin="$GHOST_HOME/bin/ghost-popup"
  elif (( $+commands[ghost-popup] )); then
    bin="$commands[ghost-popup]"
  fi
  print -r -- "$bin"
}

_ghost_bus_init() {
  emulate -L zsh

  # Idempotent: already running and healthy
  if (( _GHOST_BUS_STARTED && _GHOST_BUS_PID > 0 )); then
    if kill -0 "$_GHOST_BUS_PID" 2>/dev/null; then
      _GHOST_BUS_AVAILABLE=1
      return 0
    fi
    # Process died unexpectedly
    _ghost_bus_shutdown
  fi

  local bin_path
  bin_path="$(_ghost_bus_binary_path)"
  if [[ -z "$bin_path" || ! -x "$bin_path" ]]; then
    _GHOST_BUS_AVAILABLE=0
    return 1
  fi

  # Start coprocess (Zsh native)
  coproc "$bin_path" 2>/dev/null
  _GHOST_BUS_PID=$!

  if [[ -z "$_GHOST_BUS_PID" || "$_GHOST_BUS_PID" -le 0 ]]; then
    _GHOST_BUS_AVAILABLE=0
    return 1
  fi

  # Check if coproc stayed alive
  if ! kill -0 "$_GHOST_BUS_PID" 2>/dev/null; then
    _GHOST_BUS_AVAILABLE=0
    _GHOST_BUS_PID=0
    return 1
  fi

  _GHOST_BUS_STARTED=1
  _GHOST_BUS_AVAILABLE=1
  _GHOST_BUS_FAILURES=0

  # Register exit cleanup hook
  autoload -Uz add-zsh-hook 2>/dev/null || true
  if (( $+functions[add-zsh-hook] )); then
    add-zsh-hook zshexit _ghost_bus_shutdown 2>/dev/null || true
  else
    trap '_ghost_bus_shutdown' EXIT INT TERM HUP
  fi

  return 0
}

_ghost_intent_publish_raw() {
  emulate -L zsh
  local name="$1"
  local level="${2:-ephemeral}"
  local meta="$3"
  [[ -z "$meta" ]] && meta="{}"

  # Dispatch in-process cache and local handlers
  if [[ "$name" == ghost.cache.* && -n "${_GHOST_HANDLERS[$name]:-}" ]]; then
    local handler="${_GHOST_HANDLERS[$name]}"
    if (( $+functions[$handler] )); then
      (( ++_ghost_intent_seq ))
      local id="intent-${_ghost_intent_seq}-${EPOCHSECONDS:-0}"
      local ndjson="{\"id\":\"${id}\",\"name\":\"${name}\",\"level\":\"${level}\",\"metadata\":${meta}}"
      local resp=""
      resp="$("$handler" "$ndjson")"
      local ret=$?
      _GHOST_BUS_LAST_RESPONSE="$resp"
      if [[ "$resp" == *'"status":"error"'* ]]; then
        return 1
      fi
      return $ret
    fi
  fi

  # If bus not available, fail early for fallback
  if (( ! _GHOST_BUS_AVAILABLE )); then
    return 1
  fi

  (( ++_ghost_intent_seq ))
  local id="intent-${_ghost_intent_seq}-${EPOCHSECONDS:-0}"
  local ndjson="{\"id\":\"${id}\",\"name\":\"${name}\",\"level\":\"${level}\",\"metadata\":${meta}}"

  # Send NDJSON line to coproc
  if ! print -p -- "$ndjson" 2>/dev/null; then
    (( ++_GHOST_BUS_FAILURES ))
    (( _GHOST_BUS_FAILURES >= 2 )) && _GHOST_BUS_AVAILABLE=0
    return 1
  fi

  # Read response with 0.1s timeout
  local resp=""
  if ! read -p -t 0.1 -r resp 2>/dev/null || [[ -z "$resp" ]]; then
    (( ++_GHOST_BUS_FAILURES ))
    (( _GHOST_BUS_FAILURES >= 2 )) && _GHOST_BUS_AVAILABLE=0
    return 1
  fi

  # Successful round-trip
  _GHOST_BUS_FAILURES=0
  _GHOST_BUS_LAST_RESPONSE="$resp"

  # If status error, return 1
  if [[ "$resp" == *'"status":"error"'* ]]; then
    return 1
  fi

  return 0
}

_ghost_intent_publish() {
  emulate -L zsh
  local name="$1"
  local level="${2:-ephemeral}"
  local meta="$3"
  [[ -z "$meta" ]] && meta="{}"

  local t0=${EPOCHREALTIME:-0}
  local ret=0

  # Gateway bypass check (for benchmarking or debugging)
  if (( ${+ZIRO_GHOST_GATEWAY_BYPASS} )) && [[ "$ZIRO_GHOST_GATEWAY_BYPASS" == "1" ]]; then
    _ghost_intent_publish_raw "$name" "$level" "$meta"
    ret=$?
  else
    # Route intent through gateway pipeline (zero-fork)
    if (( ${+functions[_ghost_intent_process]} )); then
      (( ++_ghost_intent_seq ))
      local id="intent-${_ghost_intent_seq}-${EPOCHSECONDS:-0}"
      local intent_json="{\"id\":\"${id}\",\"name\":\"${name}\",\"level\":\"${level}\",\"metadata\":${meta}}"
      typeset -g _GHOST_INTENT_INTERNAL=1
      if ! _ghost_intent_process "$intent_json"; then
        typeset -g _GHOST_INTENT_INTERNAL=0
        _GHOST_BUS_LAST_RESPONSE="$_GHOST_GATEWAY_ERROR"
        ret=1
      fi
      typeset -g _GHOST_INTENT_INTERNAL=0
    fi

    if (( ret == 0 )); then
      _ghost_intent_publish_raw "$name" "$level" "$meta"
      ret=$?
    fi
  fi

  local t1=${EPOCHREALTIME:-0}
  local dur=0
  (( t0 > 0 && t1 > 0 )) && dur=$(( (t1 - t0) * 1000.0 ))
  local m_stat="ok"
  (( ret != 0 )) && m_stat="error"
  if (( ${+functions[_ghost_metrics_record]} )); then
    _ghost_metrics_record "$name" "$level" "$dur" "$m_stat" "" false
  fi

  return $ret
}

_ghost_intent_subscribe() {
  emulate -L zsh
  local intent_name="$1"
  local handler_fn="$2"
  _GHOST_HANDLERS[$intent_name]="$handler_fn"
}

_ghost_intent_dispatch() {
  emulate -L zsh
  local payload="$1"
  local intent_name="$2"
  if [[ -n "$intent_name" && -n "${_GHOST_HANDLERS[$intent_name]:-}" ]]; then
    local handler="${_GHOST_HANDLERS[$intent_name]}"
    (( $+functions[$handler] )) && "$handler" "$payload"
  fi
}

_ghost_bus_shutdown() {
  emulate -L zsh
  if (( _GHOST_BUS_PID > 0 )); then
    print -p -- '{"id":"shutdown","name":"ghost.popup.exit","level":"ephemeral","metadata":{}}' 2>/dev/null
    kill "$_GHOST_BUS_PID" 2>/dev/null || true
    _GHOST_BUS_PID=0
  fi
  _GHOST_BUS_STARTED=0
  _GHOST_BUS_AVAILABLE=0
}
