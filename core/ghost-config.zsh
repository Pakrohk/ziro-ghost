#!/usr/bin/env zsh
# ziro-ghost — Configuration Engine
# Layer: Core · Spec: 009 v0.2.0 (ZR-004, R17, FR-009) · Version: 0.8.0
# Reads TOML config (cold-path) with zstyle & compiled defaults fallback.

typeset -gA _ghost_config_cache
typeset -ga _ghost_config_custom_sources=()

# Internal: parse simple KEY = VALUE and [[sources]] from TOML-like files
_ghost_config_load_toml() {
  emulate -L zsh
  local conf_file="$1"
  [[ -r "$conf_file" ]] || return 1

  local line key val section="" in_sources=0
  local s_name="" s_handler="" s_weight="20" s_kind="cmd" s_enabled="1" s_fallback="0" s_intent="custom"
  local s_max_suggestions="" s_timeout_ms=""

  _commit_custom_source() {
    if (( in_sources )) && [[ -n "$s_name" && -n "$s_handler" ]]; then
      local entry="${s_name}|${s_handler}|${s_weight}|${s_kind}|${s_enabled}|${s_fallback}|${s_intent}"
      if [[ -n "$s_max_suggestions" || -n "$s_timeout_ms" ]]; then
        entry+="|${s_max_suggestions}|${s_timeout_ms}"
      fi
      _ghost_config_custom_sources+=("$entry")
    fi
    s_name="" s_handler="" s_weight="20" s_kind="cmd" s_enabled="1" s_fallback="0" s_intent="custom"
    s_max_suggestions="" s_timeout_ms=""
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip comments and empty lines
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Array of tables: [[sources]]
    if [[ "$line" == "[[sources]]" ]]; then
      _commit_custom_source
      in_sources=1
      section="sources"
      continue
    fi

    # Standard Section header: [section]
    if [[ "$line" =~ '^\[([a-zA-Z0-9_\.]+)\]$' ]]; then
      _commit_custom_source
      in_sources=0
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

      if (( in_sources )); then
        case "$key" in
          name)            s_name="$val" ;;
          handler)
            val="${val/#\~/$HOME}"
            s_handler="$val"
            ;;
          weight)          s_weight="$val" ;;
          kind)            s_kind="$val" ;;
          enabled)
            [[ "$val" == "true" || "$val" == "1" ]] && s_enabled="1" || s_enabled="0"
            ;;
          fallback_only)
            [[ "$val" == "true" || "$val" == "1" ]] && s_fallback="1" || s_fallback="0"
            ;;
          intent)          s_intent="$val" ;;
          max_suggestions) s_max_suggestions="$val" ;;
          timeout_ms)      s_timeout_ms="$val" ;;
        esac
      else
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
    fi
  done < "$conf_file"
  _commit_custom_source
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

# Load custom sources array from active config
_ghost_config_load_custom_sources() {
  emulate -L zsh
  local conf_file="${GHOST_TEST_CONFIG:-${GHOST_CONFIG:-}}"
  if [[ -z "$conf_file" ]]; then
    local xdg_conf="${XDG_CONFIG_HOME:-$HOME/.config}/ziro/ghost.conf"
    local ziro_conf="${ZIRO_CONFIG:-$HOME/.config/ziro}/ghost.conf"
    if [[ -r "$xdg_conf" ]]; then
      conf_file="$xdg_conf"
    elif [[ -r "$ziro_conf" ]]; then
      conf_file="$ziro_conf"
    fi
  fi

  if [[ -n "$conf_file" && -r "$conf_file" ]]; then
    _ghost_config_load_toml "$conf_file"
  fi
}

# Initialize configuration
_ghost_config_init() {
  emulate -L zsh

  # Compiled defaults (Spec 009 R18 & Safety guards)
  _ghost_config_cache[correction.enabled]="true"
  _ghost_config_cache[correction.mode]="suggest"
  _ghost_config_cache[correction.max_edit_distance]="2"
  _ghost_config_cache[correction.keyboard_distance]="true"
  _ghost_config_cache[correction.confidence_threshold]="0.7"
  _ghost_config_cache[safety.handler_timeout_ms]="50"

  # UI Preview & Docs Defaults (v0.8.0 Spec 009 FR-009)
  _ghost_config_cache[ui.preview.enabled]="true"
  _ghost_config_cache[ui.preview.layout]="vertical"
  _ghost_config_cache[ui.preview.show_kind]="true"
  _ghost_config_cache[ui.preview.show_source]="true"
  _ghost_config_cache[ui.preview.show_frecency]="true"
  _ghost_config_cache[ui.preview.show_directory]="false"

  _ghost_config_cache[ui.docs.enabled]="true"
  _ghost_config_cache[ui.docs.source]="auto"
  _ghost_config_cache[ui.docs.cache_ttl]="86400"
  _ghost_config_cache[ui.docs.max_lines]="15"

  _ghost_config_custom_sources=()

  local target_conf="${GHOST_TEST_CONFIG:-${GHOST_CONFIG:-}}"
  if [[ -n "$target_conf" && -r "$target_conf" ]]; then
    _ghost_config_load_toml "$target_conf"
    return 0
  fi

  local xdg_conf="${XDG_CONFIG_HOME:-$HOME/.config}/ziro/ghost.conf"
  local ziro_conf="${ZIRO_CONFIG:-$HOME/.config/ziro}/ghost.conf"

  if [[ -r "$xdg_conf" ]]; then
    _ghost_config_load_toml "$xdg_conf"
  elif [[ -r "$ziro_conf" ]]; then
    _ghost_config_load_toml "$ziro_conf"
  fi
}

_ghost_config_init
