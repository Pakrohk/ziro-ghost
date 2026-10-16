#!/usr/bin/env zsh
# Test: Kind system
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-kinds.zsh"

# 1. Verify default kinds registered
kinds=(git cmd path dir file alias var func history project typo snippet)
for k in "${kinds[@]}"; do
  [[ -n "${_ghost_kinds_icon[$k]:-}" ]] || { echo "FAIL: missing kind icon for $k"; exit 1; }
  [[ -n "${_ghost_kinds_ascii[$k]:-}" ]] || { echo "FAIL: missing kind ascii for $k"; exit 1; }
done

# 2. ghost_kind_get returns icon, color, label
read -r icon color label <<< "$(ghost_kind_get git)"
[[ "$label" == "git" ]] || { echo "FAIL: label is '$label'"; exit 1; }
[[ "$color" == "green" ]] || { echo "FAIL: color is '$color'"; exit 1; }

# 3. Nerd font vs ASCII fallback
ZIRO_NERD_FONT=0
res_ascii="$(ghost_kind_render git)"
[[ "$res_ascii" == *"*"* ]] || { echo "FAIL: ASCII fallback expected '*'; got '$res_ascii'"; exit 1; }

ZIRO_NERD_FONT=1
res_nerd="$(ghost_kind_render git)"
[[ "$res_nerd" == *"󰊢"* ]] || { echo "FAIL: Nerd font expected '󰊢'; got '$res_nerd'"; exit 1; }

# 4. NO_COLOR env disables color
NO_COLOR=1 ZIRO_NERD_FONT=0 res_nocolor="$(ghost_kind_render git)"
[[ "$res_nocolor" == "*" ]] || { echo "FAIL: NO_COLOR expected plain '*'; got '$res_nocolor'"; exit 1; }

# 5. User override kind
ghost_kind_register custom_kind --icon "C" --ascii-icon "c" --color blue --label "custom"
read -r c_icon c_color c_label <<< "$(ghost_kind_get custom_kind)"
[[ "$c_label" == "custom" ]] || { echo "FAIL: custom label failed"; exit 1; }

echo "ALL test_kinds PASSED"
