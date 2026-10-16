#!/usr/bin/env zsh
# Test: Ghost text color resolution, themes, overrides, and region_highlight offsets
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-config.zsh"
source "$ROOT_DIR/core/ghost-core.zsh"
source "$ROOT_DIR/ui/inline.ui.zsh"

# 1. Color resolution: truecolor mode
_GHOST_COLOR_MODE="truecolor"
_ghost_config_cache[ui.inline.color]=""
color=$(_ghost_ghost_color)
[[ "$color" == "fg=#6c6c6c" ]] || { echo "FAIL: truecolor expected fg=#6c6c6c; got '$color'"; exit 1; }

# 2. Color resolution: 256 mode
_GHOST_COLOR_MODE="256"
color=$(_ghost_ghost_color)
[[ "$color" == "fg=240" ]] || { echo "FAIL: 256 expected fg=240; got '$color'"; exit 1; }

# 3. Color resolution: ansi8 mode
_GHOST_COLOR_MODE="ansi8"
color=$(_ghost_ghost_color)
[[ "$color" == "fg=brightblack" || "$color" == "fg=8" ]] || { echo "FAIL: ansi8 expected fg=brightblack or fg=8; got '$color'"; exit 1; }

# 4. User config override
_GHOST_COLOR_MODE="truecolor"
_ghost_config_cache[ui.inline.color]="fg=244"
color=$(_ghost_ghost_color)
[[ "$color" == "fg=244" ]] || { echo "FAIL: config override expected fg=244; got '$color'"; exit 1; }
_ghost_config_cache[ui.inline.color]=""

# 5. Theme preset loading
mkdir -p "$ROOT_DIR/themes"
cat << 'EOF' > "$ROOT_DIR/themes/custom_test_theme.toml"
[palette]
ghost_text = "fg=#555555"
EOF

_ghost_config_cache[theme.preset]="custom_test_theme"
color=$(_ghost_ghost_color)
[[ "$color" == "fg=#555555" ]] || { echo "FAIL: theme preset expected fg=#555555; got '$color'"; exit 1; }
rm -rf "$ROOT_DIR/themes"
_ghost_config_cache[theme.preset]=""

# 6. region_highlight offset: starts at ${#BUFFER}
BUFFER="echo "
_GHOST_COLOR_MODE="truecolor"
region_highlight=()
ghost_ui_inline_render "echo hello world" "cmd"
[[ "$POSTDISPLAY" == "hello world" ]] || { echo "FAIL: POSTDISPLAY expected 'hello world'; got '$POSTDISPLAY'"; exit 1; }
expected_highlight="5 16 fg=#6c6c6c"
[[ "${region_highlight[*]}" == *"$expected_highlight"* ]] || { echo "FAIL: region_highlight offset expected '$expected_highlight'; got '${region_highlight[*]}'"; exit 1; }

# 7. Cleanup
ghost_ui_inline_clear
[[ -z "$POSTDISPLAY" ]] || { echo "FAIL: clear did not reset POSTDISPLAY"; exit 1; }
[[ ${#region_highlight} -eq 0 ]] || { echo "FAIL: clear did not reset region_highlight; got '${region_highlight[*]}'"; exit 1; }

echo "ALL test_ghost_text_color PASSED"
