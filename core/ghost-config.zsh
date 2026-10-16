#!/usr/bin/env zsh
# ziro-ghost — Configuration Engine
# Layer: Core · Spec: 009 v0.2.0 (ZR-004) · Version: 0.3.0
# Reads TOML config (cold-path) with zstyle & compiled defaults fallback.

typeset -gA _ghost_config_cache

# Internal: parse simple KEY = VALUE from TOML-like files
_ghost_config_load_toml() {
  emulate -L zsh
  local conf_file="$1"
  [[ -r "$conf_file" ]] || return 1

  local line key val section=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip comments and empty lines
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Section header
    if [[ "$line" =~ '^\[([a-zA-Z0-9_\.]+)\]$' ]]; then
      section="${match[1]}"
      continue
    fi

    # Key = Value
    if [[ "$line" =~ '^([a-zA-Z0-9_\.]+)[[:space:]]*=[[:space:]]*(.+)$' ]]; then
      key="${match[1]}"
      val="${match[2]}"

      # Strip quotes
      val="${val#[\"\']}"
      val="${val%[\"\']}"

      local full_key="$key"
      [[ -n "$section" ]] && full_key="${section}.${key}"
      _ghost_config_cache[$full_key]="$val"

      # Also support kind override: e.g. ui.kinds.git.color = "green"
      if [[ "$full_key" =~ '^ui\.kinds\.([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)$' ]]; then
        local k_name="${match[1]}"
        local k_prop="${match[2]}"
        case "$k_prop" in
          icon)  _ghost_kinds_icon[$k_name]="$val" ;;
          color) _ghost_kinds_color[$k_name]="$val" ;;
          label) _ghost_kinds_label[$k_name]="$val" ;;
        esac
      fi
    fi
  done < "$conf_file"
  return 0
}

# Internal: check zstyle overrides (hybrid model per ADR-006)
_ghost_config_load_zstyle() {
  emulate -L zsh
  local key="$1"
  local style_key="${key//\./-}"
  local val
  if zstyle -s ":ghost:${style_key}" value val 2>/dev/null; then
    REPLY="$val"
    return 0
  fi
  return 1
}

# Query configuration value with fallback
_ghost_config_get() {
  emulate -L zsh
  local key="$1"
  local default_val="$2"

  # 1. Memory / TOML cache
  if [[ -n "${_ghost_config_cache[$key]:-}" ]]; then
    print -r -- "${_ghost_config_cache[$key]}"
    return 0
  fi

  # 2. zstyle override
  if _ghost_config_load_zstyle "$key"; then
    print -r -- "$REPLY"
    return 0
  fi

  # 3. Compiled default
  print -r -- "$default_val"
  return 0
}

# Initialize configuration
_ghost_config_init() {
  emulate -L zsh
  local xdg_conf="${XDG_CONFIG_HOME:-$HOME/.config}/ziro/ghost.conf"
  local ziro_conf="${ZIRO_CONFIG:-$HOME/.config/ziro}/ghost.conf"

  if [[ -r "$xdg_conf" ]]; then
    _ghost_config_load_toml "$xdg_conf"
  elif [[ -r "$ziro_conf" ]]; then
    _ghost_config_load_toml "$ziro_conf"
  fi
}

_ghost_config_init
