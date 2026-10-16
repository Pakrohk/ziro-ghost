#!/usr/bin/env zsh
# ziro-ghost — IOP Module Registry
# Layer: Core · Spec: 009 v0.2.0 (R14, R17) · Version: 0.2.0
# Modules declare intent and capabilities, decoupled from implementation.

typeset -gA _ghost_sources_intent
typeset -gA _ghost_sources_handler
typeset -gA _ghost_sources_weight
typeset -gA _ghost_sources_kind
typeset -gA _ghost_sources_enabled

typeset -gA _ghost_uis_intent
typeset -gA _ghost_uis_handler

typeset -gA _ghost_matchers_intent
typeset -gA _ghost_matchers_handler

typeset -gA _ghost_comparators_intent
typeset -gA _ghost_comparators_handler

# Register a suggestion source
ghost_register_source() {
  local name="$1"
  shift

  local intent=""
  local handler=""
  local weight=10
  local kind="cmd"
  local enabled="true"

  while (( $# )); do
    case "$1" in
      --intent)  intent="$2"; shift 2 ;;
      --handler) handler="$2"; shift 2 ;;
      --weight)  weight="$2"; shift 2 ;;
      --kind)    kind="$2"; shift 2 ;;
      --enabled) enabled="$2"; shift 2 ;;
      *)         shift ;;
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
}

# Register a UI renderer (inline, popup, etc.)
ghost_register_ui() {
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
  print -r -- "${(k)_ghost_sources_handler}"
}

# Get detailed metadata for a registered source
ghost_get_source() {
  local name="$1"
  if [[ -z "${_ghost_sources_handler[$name]:-}" ]]; then
    return 1
  fi
  print -r -- "name=$name" \
    "handler=${_ghost_sources_handler[$name]}" \
    "weight=${_ghost_sources_weight[$name]}" \
    "kind=${_ghost_sources_kind[$name]}" \
    "enabled=${_ghost_sources_enabled[$name]}"
}
