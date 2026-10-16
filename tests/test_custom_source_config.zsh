#!/usr/bin/env zsh
# Test: Custom source TOML config parsing
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"

tmp_conf="$(mktemp)"
trap 'rm -f "$tmp_conf"' EXIT

# 1. config with no [[sources]] → empty list
cat << 'EOF' > "$tmp_conf"
[ui]
nerd_font = true
EOF

_ghost_config_custom_sources=()
_ghost_config_load_toml "$tmp_conf"
[[ ${#_ghost_config_custom_sources} -eq 0 ]] || { echo "FAIL: expected 0 custom sources; got ${#_ghost_config_custom_sources}"; exit 1; }

# 2. config with 1 source → parsed correctly
cat << 'EOF' > "$tmp_conf"
[[sources]]
name = "work"
handler = "_my_work_query"
weight = 25
kind = "cmd"
enabled = true
EOF

_ghost_config_custom_sources=()
_ghost_config_load_toml "$tmp_conf"
[[ ${#_ghost_config_custom_sources} -eq 1 ]] || { echo "FAIL: expected 1 source parsed; got ${#_ghost_config_custom_sources}"; exit 1; }
[[ "${_ghost_config_custom_sources[1]}" == "work|_my_work_query|25|cmd|1|0|custom" ]] || {
  echo "FAIL: parsed format mismatch; got '${_ghost_config_custom_sources[1]}'"
  exit 1
}

# 3. config with 2 sources → both parsed
cat << 'EOF' > "$tmp_conf"
[[sources]]
name = "work"
handler = "_my_work_query"
weight = 25

[[sources]]
name = "tools"
handler = "_my_tools"
weight = 15
kind = "alias"
fallback_only = true
intent = "team tools"
EOF

_ghost_config_custom_sources=()
_ghost_config_load_toml "$tmp_conf"
[[ ${#_ghost_config_custom_sources} -eq 2 ]] || { echo "FAIL: expected 2 sources parsed; got ${#_ghost_config_custom_sources}"; exit 1; }

# 4. source disabled → recorded with enabled=0
cat << 'EOF' > "$tmp_conf"
[[sources]]
name = "disabled_src"
handler = "_disabled_handler"
enabled = false
EOF

_ghost_config_custom_sources=()
_ghost_config_load_toml "$tmp_conf"
[[ "${_ghost_config_custom_sources[1]}" == *"|0|"* ]] || { echo "FAIL: disabled source should have 0 flag; got '${_ghost_config_custom_sources[1]}'"; exit 1; }

# 5. handler as path → resolved with $HOME expansion
cat << 'EOF' > "$tmp_conf"
[[sources]]
name = "path_src"
handler = "~/custom/source.zsh"
EOF

_ghost_config_custom_sources=()
_ghost_config_load_toml "$tmp_conf"
[[ "${_ghost_config_custom_sources[1]}" == *"$HOME/custom/source.zsh"* ]] || {
  echo "FAIL: ~ was not expanded to $HOME; got '${_ghost_config_custom_sources[1]}'"
  exit 1
}

echo "ALL test_custom_source_config PASSED"
