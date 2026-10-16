#!/usr/bin/env zsh
# Test: Configuration engine
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"

# 1. Config get default when key missing
val="$(_ghost_config_get "non.existent.key" "my_default")"
[[ "$val" == "my_default" ]] || { echo "FAIL: expected my_default; got '$val'"; exit 1; }

# 2. Parse mock TOML file
tmp_toml="$(mktemp)"
cat << 'EOF' > "$tmp_toml"
[ui]
nerd_font = true
color_scheme = "dracula"

[sources]
history.weight = 55

[ui.kinds.git]
color = "cyan"
EOF

_ghost_config_load_toml "$tmp_toml"
rm -f "$tmp_toml"

val_scheme="$(_ghost_config_get "ui.color_scheme" "default")"
[[ "$val_scheme" == "dracula" ]] || { echo "FAIL: expected dracula; got '$val_scheme'"; exit 1; }

val_weight="$(_ghost_config_get "sources.history.weight" "10")"
[[ "$val_weight" == "55" ]] || { echo "FAIL: expected 55; got '$val_weight'"; exit 1; }

# 3. Kind override from config
[[ "${_ghost_kinds_color[git]}" == "cyan" ]] || { echo "FAIL: git kind color should be cyan"; exit 1; }

echo "ALL test_config PASSED"
