# ziro-ghost v2.0.0 — Multi-Tier Intent Cache Service (EVOID IOP)
# Layer: 1 (Zsh Core Engine) · Spec: 010 (M4)
# Subscribes to ghost.cache.* intents. Manages pluggable cache types with atomic writes and strict 0600 permissions.

zmodload zsh/datetime 2>/dev/null || true

typeset -gA _GHOST_CACHE_PLUGINS=()
typeset -g _GHOST_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
typeset -gA _GHOST_CACHE_INFLIGHT=()
typeset -gA _GHOST_CACHE_TTL=()
typeset -gA _GHOST_CACHE_MAX=()

# Per-plugin configuration defaults (Spec M4)
typeset -gi _GHOST_CACHE_PLUGIN_PROJECT_TTL=3600
typeset -gi _GHOST_CACHE_PLUGIN_PROJECT_MAX=51200

typeset -gi _GHOST_CACHE_PLUGIN_EVAL_TTL=86400
typeset -gi _GHOST_CACHE_PLUGIN_EVAL_MAX=102400

typeset -gi _GHOST_CACHE_PLUGIN_COMPLETIONS_TTL=3600
typeset -gi _GHOST_CACHE_PLUGIN_COMPLETIONS_MAX=51200

typeset -gi _GHOST_CACHE_PLUGIN_ZOXIDE_TTL=600
typeset -gi _GHOST_CACHE_PLUGIN_ZOXIDE_MAX=20480

typeset -gi _GHOST_CACHE_PLUGIN_STATS_TTL=60
typeset -gi _GHOST_CACHE_PLUGIN_STATS_MAX=10240

_ghost_cache_path() {
  emulate -L zsh
  local name="$1"
  print -r -- "${_GHOST_CACHE_ROOT}/${name}-cache"
}

_ghost_cache_register() {
  emulate -L zsh
  local name="$1"
  local handler_fn="${2:-_ghost_cache_default_handler}"
  _GHOST_CACHE_PLUGINS[$name]="$handler_fn"
}

_ghost_cache_default_handler() {
  emulate -L zsh
  # Default fallback handler
  return 0
}

_ghost_cache_init() {
  emulate -L zsh

  # Ensure root directory exists with 0700 permissions
  [[ -d "$_GHOST_CACHE_ROOT" ]] || mkdir -p "$_GHOST_CACHE_ROOT" 2>/dev/null || true
  chmod 700 "$_GHOST_CACHE_ROOT" 2>/dev/null || true

  # Register 5 cache plugin metadata
  _GHOST_CACHE_TTL[project]=$_GHOST_CACHE_PLUGIN_PROJECT_TTL
  _GHOST_CACHE_MAX[project]=$_GHOST_CACHE_PLUGIN_PROJECT_MAX
  _ghost_cache_register "project" _ghost_cache_default_handler

  _GHOST_CACHE_TTL[eval]=$_GHOST_CACHE_PLUGIN_EVAL_TTL
  _GHOST_CACHE_MAX[eval]=$_GHOST_CACHE_PLUGIN_EVAL_MAX
  _ghost_cache_register "eval" _ghost_cache_default_handler

  _GHOST_CACHE_TTL[completions]=$_GHOST_CACHE_PLUGIN_COMPLETIONS_TTL
  _GHOST_CACHE_MAX[completions]=$_GHOST_CACHE_PLUGIN_COMPLETIONS_MAX
  _ghost_cache_register "completions" _ghost_cache_default_handler

  _GHOST_CACHE_TTL[zoxide]=$_GHOST_CACHE_PLUGIN_ZOXIDE_TTL
  _GHOST_CACHE_MAX[zoxide]=$_GHOST_CACHE_PLUGIN_ZOXIDE_MAX
  _ghost_cache_register "zoxide" _ghost_cache_default_handler

  _GHOST_CACHE_TTL[stats]=$_GHOST_CACHE_PLUGIN_STATS_TTL
  _GHOST_CACHE_MAX[stats]=$_GHOST_CACHE_PLUGIN_STATS_MAX
  _ghost_cache_register "stats" _ghost_cache_default_handler

  # Subscribe cache intent handlers to Intent Bus
  if (( ${+functions[_ghost_intent_subscribe]} )); then
    _ghost_intent_subscribe "ghost.cache.get" _ghost_cache_dispatch_get
    _ghost_intent_subscribe "ghost.cache.put" _ghost_cache_dispatch_put
    _ghost_intent_subscribe "ghost.cache.invalidate" _ghost_cache_dispatch_invalidate
    _ghost_intent_subscribe "ghost.cache.clear" _ghost_cache_dispatch_clear
  fi

  return 0
}

_ghost_cache_parse_metadata_field() {
  emulate -L zsh
  local json="$1"
  local key="$2"
  local val=""

  # Strip everything before "metadata": to avoid matching top-level keys
  local meta="${json#*\"metadata\":}"
  [[ "$meta" == "$json" ]] && meta=""

  # Match "key":"value" or "key": "value"
  if [[ "$meta" =~ "\"${key}\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\"" ]]; then
    val="${match[1]}"
    val="${val//\\\"/\"}"
    val="${val//\\\\/\\}"
    val="${val//\\n/$'\n'}"
  fi
  print -r -- "$val"
}

_ghost_cache_dispatch_get() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown" name=""

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi

  name="$(_ghost_cache_parse_metadata_field "$intent_json" "name")"

  if [[ -z "$name" || -z "${_GHOST_CACHE_PLUGINS[$name]:-}" ]]; then
    print -r -- "{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"unknown or unregistered cache plugin: ${name}\"}"
    return 1
  fi

  local cache_path="$(_ghost_cache_path "$name")"

  if [[ ! -f "$cache_path" ]]; then
    print -r -- "{\"id\":\"${id}\",\"status\":\"ok\",\"value\":{\"miss\":true}}"
    return 0
  fi

  # Validate permissions (must be 600)
  local perms=""
  perms="$(stat -c '%a' "$cache_path" 2>/dev/null || stat -f '%A' "$cache_path" 2>/dev/null)"
  if [[ "$perms" != "600" && "$perms" != "0600" ]]; then
    rm -f "$cache_path" 2>/dev/null
    print -r -- "{\"id\":\"${id}\",\"status\":\"ok\",\"value\":{\"miss\":true,\"reason\":\"insecure_perms\"}}"
    return 0
  fi

  # Check TTL
  local ttl="${_GHOST_CACHE_TTL[$name]:-86400}"
  local mtime=0 now age=0
  mtime="$(stat -c '%Y' "$cache_path" 2>/dev/null || stat -f '%m' "$cache_path" 2>/dev/null || echo 0)"
  now="${EPOCHSECONDS:-$(date +%s)}"
  age=$(( now - mtime ))

  if (( age > ttl )); then
    rm -f "$cache_path" 2>/dev/null
    print -r -- "{\"id\":\"${id}\",\"status\":\"ok\",\"value\":{\"miss\":true,\"expired\":true}}"
    return 0
  fi

  local content=""
  content="$(<"$cache_path")"

  # Escape JSON
  local escaped="${content//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  escaped="${escaped//$'\n'/\\n}"
  escaped="${escaped//$'\r'/}"

  print -r -- "{\"id\":\"${id}\",\"status\":\"ok\",\"value\":{\"content\":\"${escaped}\",\"age\":${age}}}"
  return 0
}

_ghost_cache_dispatch_put() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown" name="" content=""

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi

  name="$(_ghost_cache_parse_metadata_field "$intent_json" "name")"
  content="$(_ghost_cache_parse_metadata_field "$intent_json" "content")"

  if [[ -z "$name" || -z "${_GHOST_CACHE_PLUGINS[$name]:-}" ]]; then
    print -r -- "{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"unknown or unregistered cache plugin: ${name}\"}"
    return 1
  fi

  local max_bytes="${_GHOST_CACHE_MAX[$name]:-1048576}"
  local byte_len=${#content}
  if (( byte_len > max_bytes )); then
    print -r -- "{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"content size ${byte_len} exceeds max_bytes ${max_bytes}\"}"
    return 1
  fi

  local cache_path="$(_ghost_cache_path "$name")"
  local tmp_path="${cache_path}.tmp.$$"

  # Atomic write: write to temp file, chmod 600, then move
  if ! print -r -- "$content" > "$tmp_path" 2>/dev/null; then
    rm -f "$tmp_path" 2>/dev/null
    print -r -- "{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"write to tmp file failed\"}"
    return 1
  fi

  chmod 600 "$tmp_path" 2>/dev/null
  if ! mv -f "$tmp_path" "$cache_path" 2>/dev/null; then
    rm -f "$tmp_path" 2>/dev/null
    print -r -- "{\"id\":\"${id}\",\"status\":\"error\",\"error\":\"atomic rename failed\"}"
    return 1
  fi

  print -r -- "{\"id\":\"${id}\",\"status\":\"ok\",\"value\":{\"stored\":true,\"name\":\"${name}\",\"bytes\":${byte_len}}}"
  return 0
}

_ghost_cache_dispatch_invalidate() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown" name=""

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi

  name="$(_ghost_cache_parse_metadata_field "$intent_json" "name")"

  if [[ -n "$name" ]]; then
    local cache_path="$(_ghost_cache_path "$name")"
    rm -f "$cache_path" 2>/dev/null
  fi

  print -r -- "{\"id\":\"${id}\",\"status\":\"ok\",\"value\":{\"invalidated\":true,\"name\":\"${name}\"}}"
  return 0
}

_ghost_cache_dispatch_clear() {
  emulate -L zsh
  local intent_json="$1"
  local id="unknown" type=""

  if [[ "$intent_json" =~ '"id"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    id="${match[1]}"
  fi

  type="$(_ghost_cache_parse_metadata_field "$intent_json" "type")"

  local -a cleared=()
  if [[ -n "$type" && "$type" != "all" ]]; then
    local cache_path="$(_ghost_cache_path "$type")"
    rm -f "$cache_path" 2>/dev/null
    cleared+=("$type")
  else
    local plugin
    for plugin in "${(@k)_GHOST_CACHE_PLUGINS}"; do
      local p="$(_ghost_cache_path "$plugin")"
      rm -f "$p" 2>/dev/null
      cleared+=("$plugin")
    done
  fi

  local cleared_json="["
  local first=1 c
  for c in "${cleared[@]}"; do
    if (( first )); then
      cleared_json+="\"$c\""
      first=0
    else
      cleared_json+=",\"$c\""
    fi
  done
  cleared_json+="]"

  print -r -- "{\"id\":\"${id}\",\"status\":\"ok\",\"value\":{\"cleared\":${cleared_json}}}"
  return 0
}

# ─── Public CLI Helpers ───

ghost_cache_clear() {
  emulate -L zsh
  local target="${1:-all}"
  _ghost_cache_init 2>/dev/null

  if _ghost_intent_publish "ghost.cache.clear" "ephemeral" "{\"type\":\"${target}\"}"; then
    print -r -- "ghost cache: cleared ${target}"
    return 0
  fi
  print -r -- "ghost cache: clear failed" >&2
  return 1
}

_ghost_cache_cli() {
  emulate -L zsh
  _ghost_cache_init 2>/dev/null

  local subcmd="${1:-list}"
  shift 2>/dev/null || true

  case "$subcmd" in
    list)
      local json_mode=0
      [[ "${1:-}" == "--json" ]] && json_mode=1

      if (( json_mode )); then
        local entries="["
        local first=1 plugin cache_path perms size age
        local -a all_types=("${(@k)_GHOST_CACHE_PLUGINS}" "history")
        for plugin in "${(@u)all_types}"; do
          cache_path="$(_ghost_cache_path "$plugin")"
          if [[ -f "$cache_path" ]]; then
            perms="$(stat -c '%a' "$cache_path" 2>/dev/null || echo "???")"
            size="$(stat -c '%s' "$cache_path" 2>/dev/null || echo 0)"
            local mtime
            mtime="$(stat -c '%Y' "$cache_path" 2>/dev/null || echo 0)"
            age=$(( ${EPOCHSECONDS:-$(date +%s)} - mtime ))
          else
            perms="---"
            size=0
            age=-1
          fi
          local entry="{\"name\":\"${plugin}\",\"path\":\"${cache_path}\",\"perms\":\"${perms}\",\"size\":${size},\"age\":${age}}"
          if (( first )); then
            entries+="$entry"
            first=0
          else
            entries+=",$entry"
          fi
        done
        entries+="]"
        print -r -- "$entries"
        return 0
      fi

      printf "%-12s %-6s %-8s %-8s %s\n" "TYPE" "PERMS" "SIZE" "AGE" "PATH"
      printf "%-12s %-6s %-8s %-8s %s\n" "----" "-----" "----" "---" "----"

      local plugin cache_path perms size age_str
      local -a all_types=("${(@k)_GHOST_CACHE_PLUGINS}" "history")
      for plugin in "${(@u)all_types}"; do
        cache_path="$(_ghost_cache_path "$plugin")"
        if [[ -f "$cache_path" ]]; then
          perms="$(stat -c '%a' "$cache_path" 2>/dev/null || echo "???")"
          size="$(stat -c '%s' "$cache_path" 2>/dev/null || echo 0)"
          local mtime
          mtime="$(stat -c '%Y' "$cache_path" 2>/dev/null || echo 0)"
          local age=$(( ${EPOCHSECONDS:-$(date +%s)} - mtime ))
          if (( age < 60 )); then
            age_str="${age}s"
          elif (( age < 3600 )); then
            age_str="$(( age / 60 ))m"
          else
            age_str="$(( age / 3600 ))h"
          fi
          size="${size}B"
        else
          perms="none"
          size="-"
          age_str="-"
        fi
        printf "%-12s %-6s %-8s %-8s %s\n" "$plugin" "$perms" "$size" "$age_str" "$cache_path"
      done
      ;;

    stat)
      local name="${1:-}"
      local json_mode=0
      [[ "${2:-}" == "--json" ]] && json_mode=1

      if [[ -z "$name" ]]; then
        print -r -- "Usage: ghost cache stat <type> [--json]" >&2
        return 1
      fi

      local cache_path="$(_ghost_cache_path "$name")"
      local exists=0 perms="none" size=0 age=-1 ttl="${_GHOST_CACHE_TTL[$name]:-86400}" max_b="${_GHOST_CACHE_MAX[$name]:-0}"
      if [[ -f "$cache_path" ]]; then
        exists=1
        perms="$(stat -c '%a' "$cache_path" 2>/dev/null || echo "???")"
        size="$(stat -c '%s' "$cache_path" 2>/dev/null || echo 0)"
        local mtime
        mtime="$(stat -c '%Y' "$cache_path" 2>/dev/null || echo 0)"
        age=$(( ${EPOCHSECONDS:-$(date +%s)} - mtime ))
      fi

      if (( json_mode )); then
        print -r -- "{\"name\":\"${name}\",\"exists\":${exists},\"path\":\"${cache_path}\",\"perms\":\"${perms}\",\"size\":${size},\"age\":${age},\"ttl\":${ttl},\"max_bytes\":${max_b}}"
        return 0
      fi

      print -r -- "Cache Type : $name"
      print -r -- "File Path  : $cache_path"
      print -r -- "Exists     : $(( exists ? 1 : 0 ))"
      print -r -- "Permissions: $perms"
      print -r -- "Size       : ${size} bytes"
      print -r -- "Age        : ${age}s"
      print -r -- "TTL Limit  : ${ttl}s"
      print -r -- "Max Limit  : ${max_b} bytes"
      ;;

    clear)
      local target="${1:-all}"
      ghost_cache_clear "$target"
      ;;

    *)
      print -r -- "Usage: ghost cache {list|stat <type>|clear [<type>|all]}" >&2
      return 1
      ;;
  esac
}
