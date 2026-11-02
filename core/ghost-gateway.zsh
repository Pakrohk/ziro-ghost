# ziro-ghost v2.0.0 — Intent Gateway & Pipeline Composer (EVOID IOP)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M5)
# Processes intents through composable pipelines (validate, authorize, audit, protect)
# before dispatching to the Intent Bus.

zmodload zsh/datetime 2>/dev/null || true

typeset -gA _GHOST_PROCESSORS=()
typeset -gA _GHOST_PIPELINES=(
  [ephemeral]='validate'
  [standard]='validate authorize'
  [critical]='validate authorize audit protect'
)
typeset -g _GHOST_AUDIT_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost/metrics.jsonl"

typeset -g _GHOST_INTENT_INTERNAL=0
typeset -g _GHOST_GATEWAY_ERROR=""

_ghost_processor_register() {
  emulate -L zsh
  local name="$1"
  local fn="$2"
  _GHOST_PROCESSORS[$name]="$fn"
}

_ghost_resolve_pipeline() {
  emulate -L zsh
  local level="${1:-ephemeral}"
  print -r -- "${_GHOST_PIPELINES[$level]:-validate}"
}

_ghost_run_processor() {
  emulate -L zsh
  local processor_name="$1"
  local intent_json="$2"
  local fn="${_GHOST_PROCESSORS[$processor_name]:-}"

  if [[ -z "$fn" || ! $+functions[$fn] ]]; then
    _GHOST_GATEWAY_ERROR='{"status":"error","error":"unknown processor"}'
    (( _GHOST_INTENT_INTERNAL )) || print -r -- "$_GHOST_GATEWAY_ERROR"
    return 1
  fi

  "$fn" "$intent_json"
}

_ghost_intent_process() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown" name="" level="ephemeral"

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi
  if [[ "$intent_json" =~ '"name"[[:space:]]*:[[:space:]]*"([^"]*)"' ]]; then
    name="${match[1]}"
  fi
  if [[ "$intent_json" =~ '"level"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    level="${match[1]}"
  fi

  local pipeline_str="${_GHOST_PIPELINES[$level]:-validate}"
  local -a pipeline=(${(s: :)pipeline_str})

  local processor
  for processor in "${pipeline[@]}"; do
    if ! _ghost_run_processor "$processor" "$intent_json"; then
      return 1
    fi
  done

  (( _GHOST_INTENT_INTERNAL )) || print -r -- "{\"id\":\"${id}\",\"status\":\"ok\"}"
  return 0
}

# ─── Processors Implementation ───

_ghost_processor_validate() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown" name="" level=""

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi

  if [[ "$intent_json" =~ '"name"[[:space:]]*:[[:space:]]*"([^"]*)"' ]]; then
    name="${match[1]}"
  fi

  if [[ -z "$name" ]]; then
    _GHOST_GATEWAY_ERROR="{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"invalid intent: empty name\"}"
    (( _GHOST_INTENT_INTERNAL )) || print -r -- "$_GHOST_GATEWAY_ERROR"
    return 1
  fi

  if [[ "$intent_json" =~ '"level"[[:space:]]*:[[:space:]]*"([^"]*)"' ]]; then
    level="${match[1]}"
  fi

  case "$level" in
    ephemeral|standard|critical)
      ;;
    *)
      _GHOST_GATEWAY_ERROR="{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"invalid intent: invalid level '${level}'\"}"
      (( _GHOST_INTENT_INTERNAL )) || print -r -- "$_GHOST_GATEWAY_ERROR"
      return 1
      ;;
  esac

  # Validate metadata is JSON object
  if [[ ! "$intent_json" =~ '"metadata"[[:space:]]*:[[:space:]]*\{' ]]; then
    _GHOST_GATEWAY_ERROR="{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"invalid intent: metadata must be a JSON object\"}"
    (( _GHOST_INTENT_INTERNAL )) || print -r -- "$_GHOST_GATEWAY_ERROR"
    return 1
  fi

  (( _GHOST_INTENT_INTERNAL )) || print -r -- "{\"id\":\"${id}\",\"status\":\"ok\"}"
  return 0
}

_ghost_processor_authorize() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown" name=""

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi
  if [[ "$intent_json" =~ '"name"[[:space:]]*:[[:space:]]*"([^"]*)"' ]]; then
    name="${match[1]}"
  fi

  # Block writes to system paths outside ~/.cache/ziro
  if [[ "$name" == "ghost.system.write" || "$name" == "ghost.system.delete" ]]; then
    if [[ "$intent_json" =~ '"path"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
      local target_path="${match[1]}"
      if [[ "$target_path" =~ '^(/etc/|/usr/|/var/|/bin/|/sbin/|/boot/|/sys/|/proc/)' ]]; then
        _GHOST_GATEWAY_ERROR="{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"unauthorized: write to system path '${target_path}' blocked\"}"
        (( _GHOST_INTENT_INTERNAL )) || print -r -- "$_GHOST_GATEWAY_ERROR"
        return 1
      fi
    fi
  fi

  (( _GHOST_INTENT_INTERNAL )) || print -r -- "{\"id\":\"${id}\",\"status\":\"ok\"}"
  return 0
}

_ghost_processor_audit() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown" name="" level="ephemeral"

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi
  if [[ "$intent_json" =~ '"name"[[:space:]]*:[[:space:]]*"([^"]*)"' ]]; then
    name="${match[1]}"
  fi
  if [[ "$intent_json" =~ '"level"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    level="${match[1]}"
  fi

  # Only audit standard and critical intents (skip ephemeral for hot-path speed)
  if [[ "$level" != "ephemeral" ]]; then
    local audit_dir="${_GHOST_AUDIT_LOG:h}"
    [[ -d "$audit_dir" ]] || mkdir -p "$audit_dir" 2>/dev/null || true
    chmod 700 "$audit_dir" 2>/dev/null || true

    local now="${EPOCHSECONDS:-$(date +%s)}"
    local log_line="{\"ts\":${now},\"id\":\"${id}\",\"name\":\"${name}\",\"level\":\"${level}\",\"phase\":\"audit\"}"
    print -r -- "$log_line" >> "$_GHOST_AUDIT_LOG" 2>/dev/null || true
  fi

  (( _GHOST_INTENT_INTERNAL )) || print -r -- "{\"id\":\"${id}\",\"status\":\"ok\"}"
  return 0
}

_ghost_processor_protect() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown"

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi

  # Extract metadata portion to scan for leaked secrets
  local meta="${intent_json#*\"metadata\":}"
  [[ "$meta" == "$intent_json" ]] && meta=""

  # Regex patterns for common sensitive credentials
  if [[ "$meta" =~ '(AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{36}|BEGIN[[:space:]]+(RSA|OPENSSH|DSA|EC)?[[:space:]]*PRIVATE[[:space:]]+KEY)' ]]; then
    _GHOST_GATEWAY_ERROR="{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"protected: metadata contains sensitive credential pattern\"}"
    (( _GHOST_INTENT_INTERNAL )) || print -r -- "$_GHOST_GATEWAY_ERROR"
    return 1
  fi

  (( _GHOST_INTENT_INTERNAL )) || print -r -- "{\"id\":\"${id}\",\"status\":\"ok\"}"
  return 0
}

_ghost_gateway_init() {
  emulate -L zsh
  local audit_dir="${_GHOST_AUDIT_LOG:h}"
  [[ -d "$audit_dir" ]] || mkdir -p "$audit_dir" 2>/dev/null || true
  chmod 700 "$audit_dir" 2>/dev/null || true

  _ghost_processor_register "validate" _ghost_processor_validate
  _ghost_processor_register "authorize" _ghost_processor_authorize
  _ghost_processor_register "audit" _ghost_processor_audit
  _ghost_processor_register "protect" _ghost_processor_protect

  return 0
}
