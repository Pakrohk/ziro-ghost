#!/usr/bin/env zsh
# ziro-ghost — IOP Module Registry & Custom Source API
# Layer: Core · Spec: 009 v0.2.0 (R14, R17)
# Modules declare intent and capabilities, decoupled from implementation.

typeset -gA _ghost_sources_intent
typeset -gA _ghost_sources_handler
typeset -gA _ghost_sources_weight
typeset -gA _ghost_sources_kind
typeset -gA _ghost_sources_enabled
typeset -gA _ghost_sources_fallback
typeset -ga _ghost_custom_sources_registry=()

# Contract-based safety & statistics (v0.8.0)
typeset -gA _ghost_source_contract=()
typeset -gA _ghost_source_stats=()

typeset -gA _ghost_uis_intent
typeset -gA _ghost_uis_handler

typeset -gA _ghost_matchers_intent
typeset -gA _ghost_matchers_handler

typeset -gA _ghost_comparators_intent
typeset -gA _ghost_comparators_handler

# Built-in internal sources protected against collision
typeset -ga _ghost_builtin_sources=(history project subcommand completions typo zoxide)

# Validate contract bounds for custom source (positive integers within limits)
ghost_validate_source_contract() {
  emulate -L zsh
  local name="$1" max_sugg="$2" timeout_ms="$3"
  [[ "$max_sugg" =~ '^[1-9][0-9]*$' ]] || return 1
  [[ "$timeout_ms" =~ '^[1-9][0-9]*$' ]] || return 1
  (( max_sugg < 1 || max_sugg > 1000 || timeout_ms < 1 || timeout_ms > 10000 )) && return 1
  return 0
}

# Register a suggestion source
#
# Arguments:
#   name: Unique source identifier (string)
# Flags:
#   --intent          Short description of source purpose (default: "")
#   --handler         Name of shell function to query for suggestions
#   --weight          Base scoring weight (integer, default: 10)
#   --kind            Default semantic kind for suggestions (default: "cmd")
#   --enabled         "true" or "false" (default: "true")
#   --fallback-only   Flag indicating this source only runs when primary sources return 0 items
#   --max-suggestions Contract: upper limit on suggestions returned (default: 50)
#   --timeout-ms      Contract: maximum execution time in ms (default: 100)
ghost_register_source() {
  emulate -L zsh
  local name="$1"
  shift

  local intent=""
  local handler=""
  local weight=10
  local kind="cmd"
  local enabled="true"
  local fallback_only="0"
  local max_sugg=""
  local timeout_ms=""

  while (( $# )); do
    case "$1" in
      --intent)          intent="$2"; shift 2 ;;
      --handler)         handler="$2"; shift 2 ;;
      --weight)          weight="$2"; shift 2 ;;
      --kind)            kind="$2"; shift 2 ;;
      --enabled)         enabled="$2"; shift 2 ;;
      --fallback-only)   fallback_only="1"; shift ;;
      --max-suggestions) max_sugg="$2"; shift 2 ;;
      --timeout-ms)      timeout_ms="$2"; shift 2 ;;
      *)                 shift ;;
    esac
  done

  if [[ -n "${_ghost_sources_handler[$name]:-}" ]]; then
    # Warn on duplicate
    print -u2 "ghost: warning: source '$name' already registered, overwriting"
  fi

  _ghost_sources_intent[$name]="$intent"
  _ghost_sources_handler[$name]="$handler"
  _ghost_sources_weight[$name]="$weight"
  _ghost_sources_kind[$name]="$kind"
  _ghost_sources_enabled[$name]="$enabled"
  _ghost_sources_fallback[$name]="$fallback_only"

  if [[ -n "$max_sugg" || -n "$timeout_ms" ]]; then
    local ms="${max_sugg:-50}"
    local tm="${timeout_ms:-100}"
    if ghost_validate_source_contract "$name" "$ms" "$tm"; then
      _ghost_source_contract[$name]="${ms}:${tm}"
    else
      print -u2 "ghost: warning: invalid contract for '$name', using defaults 50/100ms"
      _ghost_source_contract[$name]="50:100"
    fi
  fi
}

# Unregister a source from registry
ghost_unregister_source() {
  emulate -L zsh
  local name="$1"
  [[ -z "$name" ]] && return 1
  unset "_ghost_sources_handler[$name]"
  unset "_ghost_sources_intent[$name]"
  unset "_ghost_sources_weight[$name]"
  unset "_ghost_sources_kind[$name]"
  unset "_ghost_sources_enabled[$name]"
  unset "_ghost_sources_fallback[$name]"
  unset "_ghost_source_contract[$name]"
  ghost_source_stats_reset "$name"
  _ghost_custom_sources_registry=(${_ghost_custom_sources_registry:#$name})
  return 0
}

# Retrieve execution metrics & accountability statistics for a source
ghost_source_stats() {
  emulate -L zsh
  local name="$1"
  if [[ -z "${_ghost_sources_handler[$name]:-}" && -z "${_ghost_source_contract[$name]:-}" ]]; then
    print -u2 "ghost: source '$name' not found"
    return 1
  fi

  local calls="${_ghost_source_stats[$name.calls]:-0}"
  local total_ms="${_ghost_source_stats[$name.total_ms]:-0}"
  local last_ms="${_ghost_source_stats[$name.last_ms]:-0}"
  local max_ms="${_ghost_source_stats[$name.max_ms]:-0}"
  local timeout_violations="${_ghost_source_stats[$name.timeout_violations]:-0}"
  local truncations="${_ghost_source_stats[$name.truncations]:-0}"
  local enabled="${_ghost_sources_enabled[$name]:-true}"
  local fallback_only="${_ghost_sources_fallback[$name]:-0}"

  local -F avg_ms=0.0
  if (( calls > 0 )); then
    avg_ms=$(( total_ms / calls ))
  fi

  print -r -- "Source: $name"
  print -r -- "  calls:              $calls"
  printf      "  avg_ms:             %.1f\n" "$avg_ms"
  print -r -- "  max_ms:             $max_ms"
  print -r -- "  last_ms:            $last_ms"
  print -r -- "  timeout_violations: $timeout_violations"
  print -r -- "  truncations:        $truncations"
  print -r -- "  enabled:            $enabled"
  print -r -- "  fallback_only:      $fallback_only"
}

# Retrieve execution metrics for all sources
ghost_all_source_stats() {
  emulate -L zsh
  local src
  for src in ${(k)_ghost_sources_handler}; do
    ghost_source_stats "$src"
  done
}

# Reset stats counters for a source or all sources
ghost_source_stats_reset() {
  emulate -L zsh
  local name="$1"
  if [[ -n "$name" ]]; then
    unset "_ghost_source_stats[$name.calls]"
    unset "_ghost_source_stats[$name.total_ms]"
    unset "_ghost_source_stats[$name.max_ms]"
    unset "_ghost_source_stats[$name.last_ms]"
    unset "_ghost_source_stats[$name.timeout_violations]"
    unset "_ghost_source_stats[$name.truncations]"
  else
    _ghost_source_stats=()
  fi
}

# Retrieve formatted metadata for a source
ghost_source_info() {
  emulate -L zsh
  local name="$1"
  if [[ -z "${_ghost_sources_handler[$name]:-}" ]]; then
    print -u2 "ghost: source '$name' not found"
    return 1
  fi
  print -r -- "Source: $name"
  print -r -- "  Handler:       ${_ghost_sources_handler[$name]}"
  print -r -- "  Weight:        ${_ghost_sources_weight[$name]}"
  print -r -- "  Kind:          ${_ghost_sources_kind[$name]}"
  print -r -- "  Enabled:       ${_ghost_sources_enabled[$name]}"
  print -r -- "  Fallback-only: ${_ghost_sources_fallback[$name]:-0}"
  print -r -- "  Intent:        ${_ghost_sources_intent[$name]:-none}"
  if [[ -n "${_ghost_source_contract[$name]:-}" ]]; then
    print -r -- "  Contract:      ${_ghost_source_contract[$name]}"
  fi
}

# List registered custom source names
ghost_custom_sources_list() {
  emulate -L zsh
  local -a custom_list=()
  local src
  for src in "${_ghost_custom_sources_registry[@]}"; do
    [[ -n "${_ghost_sources_handler[$src]:-}" ]] && custom_list+=("$src")
  done
  for src in ${(k)_ghost_sources_handler}; do
    if [[ "${_ghost_sources_intent[$src]:-}" == "custom" ]]; then
      custom_list+=("$src")
    fi
  done
  print -r -- "${(u)custom_list}"
}

# Load user custom sources parsed from configuration
ghost_load_custom_sources() {
  emulate -L zsh
  (( ${#_ghost_config_custom_sources} == 0 )) && return 0

  local entry s_name s_handler s_weight s_kind s_enabled s_fallback s_intent s_max_sugg s_timeout
  for entry in "${_ghost_config_custom_sources[@]}"; do
    local -a parts=("${(s:|:)entry}")
    s_name="${parts[1]:-}"
    s_handler="${parts[2]:-}"
    s_weight="${parts[3]:-20}"
    s_kind="${parts[4]:-cmd}"
    s_enabled="${parts[5]:-1}"
    s_fallback="${parts[6]:-0}"
    s_intent="${parts[7]:-custom}"
    s_max_sugg="${parts[8]:-}"
    s_timeout="${parts[9]:-}"

    [[ -z "$s_name" || -z "$s_handler" ]] && continue
    # Skip disabled sources
    [[ "$s_enabled" == "0" || "$s_enabled" == "false" ]] && continue

    # Conflict check: built-in source protection
    if (( ${_ghost_builtin_sources[(Ie)$s_name]} )); then
      print -u2 "ghost: warning: custom source '$s_name' conflicts with built-in source, skipping"
      continue
    fi

    # Contract validation: require max_suggestions & timeout_ms with fallback defaults
    if [[ -z "$s_max_sugg" || -z "$s_timeout" ]]; then
      print -u2 "ghost: warning: custom source '$s_name' missing contract (max_suggestions/timeout_ms), using defaults 50/100ms"
      s_max_sugg="50"
      s_timeout="100"
    elif ! ghost_validate_source_contract "$s_name" "$s_max_sugg" "$s_timeout"; then
      print -u2 "ghost: warning: custom source '$s_name' has invalid contract ($s_max_sugg, $s_timeout), using defaults 50/100ms"
      s_max_sugg="50"
      s_timeout="100"
    fi

    local fn=""
    # Check if handler is a file path
    if [[ "$s_handler" == /* || "$s_handler" == .* || "$s_handler" == */* ]]; then
      if [[ ! -f "$s_handler" ]]; then
        print -u2 "ghost: warning: custom source file '$s_handler' not found, skipping"
        continue
      fi
      local -a funcs_before=(${(k)functions})
      source "$s_handler" 2>/dev/null || {
        print -u2 "ghost: warning: error sourcing custom file '$s_handler', skipping"
        continue
      }
      local -a funcs_after=(${(k)functions})
      local -a new_funcs=(${funcs_after:|funcs_before})

      if (( ${+functions[$s_handler]} )); then
        fn="$s_handler"
      elif (( ${+functions[_ghost_${s_name}_handler]} )); then
        fn="_ghost_${s_name}_handler"
      elif (( ${+functions[_ghost_${s_name}_query]} )); then
        fn="_ghost_${s_name}_query"
      elif (( ${+functions[_ghost_${s_name}_commands]} )); then
        fn="_ghost_${s_name}_commands"
      elif (( ${#new_funcs} > 0 )); then
        fn="${new_funcs[1]}"
      elif (( ${+functions[$s_name]} )); then
        fn="$s_name"
      else
        print -u2 "ghost: warning: no callable handler function found for custom source '$s_name'"
        continue
      fi
    else
      fn="$s_handler"
      if ! (( ${+functions[$fn]} )); then
        print -u2 "ghost: warning: custom source handler '$fn' is not a defined function"
      fi
    fi

    # Register into registry
    local -a reg_args=(
      "$s_name"
      --intent "$s_intent"
      --handler "$fn"
      --weight "$s_weight"
      --kind "$s_kind"
      --enabled "true"
      --max-suggestions "$s_max_sugg"
      --timeout-ms "$s_timeout"
    )
    (( s_fallback == 1 )) && reg_args+=(--fallback-only)

    ghost_register_source "${reg_args[@]}"
    _ghost_custom_sources_registry+=("$s_name")
  done
}

# Reload all custom sources at runtime
ghost_reload_custom_sources() {
  emulate -L zsh
  local src
  for src in "${_ghost_custom_sources_registry[@]}"; do
    ghost_unregister_source "$src"
  done
  _ghost_custom_sources_registry=()

  if (( ${+functions[_ghost_config_load_custom_sources]} )); then
    _ghost_config_load_custom_sources
  fi
  ghost_load_custom_sources
}

# Register a UI renderer (inline, popup, etc.)
ghost_register_ui() {
  emulate -L zsh
  local name="$1"
  shift

  local intent=""
  local handler=""

  while (( $# )); do
    case "$1" in
      --intent)  intent="$2"; shift 2 ;;
      --handler) handler="$2"; shift 2 ;;
      *)         shift ;;
    esac
  done

  _ghost_uis_intent[$name]="$intent"
  _ghost_uis_handler[$name]="$handler"
}

# Register a matching strategy (prefix, fuzzy, etc.)
ghost_register_matcher() {
  emulate -L zsh
  local name="$1"
  shift

  local intent=""
  local handler=""

  while (( $# )); do
    case "$1" in
      --intent)  intent="$2"; shift 2 ;;
      --handler) handler="$2"; shift 2 ;;
      *)         shift ;;
    esac
  done

  _ghost_matchers_intent[$name]="$intent"
  _ghost_matchers_handler[$name]="$handler"
}

# Register a ranking comparator
ghost_register_comparator() {
  emulate -L zsh
  local name="$1"
  shift

  local intent=""
  local handler=""

  while (( $# )); do
    case "$1" in
      --intent)  intent="$2"; shift 2 ;;
      --handler) handler="$2"; shift 2 ;;
      *)         shift ;;
    esac
  done

  _ghost_comparators_intent[$name]="$intent"
  _ghost_comparators_handler[$name]="$handler"
}

# List all registered source names
ghost_list_sources() {
  emulate -L zsh
  print -r -- "${(k)_ghost_sources_handler}"
}

# Get detailed metadata for a registered source
ghost_get_source() {
  emulate -L zsh
  local name="$1"
  if [[ -z "${_ghost_sources_handler[$name]:-}" ]]; then
    return 1
  fi
  print -r -- "name=$name" \
    "handler=${_ghost_sources_handler[$name]}" \
    "weight=${_ghost_sources_weight[$name]}" \
    "kind=${_ghost_sources_kind[$name]}" \
    "enabled=${_ghost_sources_enabled[$name]}" \
    "fallback_only=${_ghost_sources_fallback[$name]:-0}"
}
