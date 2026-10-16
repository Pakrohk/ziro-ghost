#!/usr/bin/env zsh
# Test: Tab & Shift-Tab navigation in popup
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/ui/popup.ui.zsh"
source "$ROOT_DIR/core/ghost-core.zsh"

# 1. Setup mock popup candidates
candidates=("40:git:item1" "30:history:item2" "20:cmd:item3")
ghost_ui_popup_native "${candidates[@]}"

_ghost_popup_index=1
[[ $_ghost_popup_index -eq 1 ]] || { echo "FAIL: initial index should be 1"; exit 1; }

# 2. Tab advances selection
ghost_ui_popup_native_step down
[[ $_ghost_popup_index -eq 2 ]] || { echo "FAIL: Tab expected index 2; got $_ghost_popup_index"; exit 1; }

ghost_ui_popup_native_step down
[[ $_ghost_popup_index -eq 3 ]] || { echo "FAIL: Tab expected index 3; got $_ghost_popup_index"; exit 1; }

# Wrap around to 1
ghost_ui_popup_native_step down
[[ $_ghost_popup_index -eq 1 ]] || { echo "FAIL: Tab wrap expected index 1; got $_ghost_popup_index"; exit 1; }

# 3. Shift-Tab (up) retreats selection
ghost_ui_popup_native_step up
[[ $_ghost_popup_index -eq 3 ]] || { echo "FAIL: S-Tab wrap expected index 3; got $_ghost_popup_index"; exit 1; }

ghost_ui_popup_native_step up
[[ $_ghost_popup_index -eq 2 ]] || { echo "FAIL: S-Tab expected index 2; got $_ghost_popup_index"; exit 1; }

# 4. Keybinding registration verification
GHOST_TEST_BOOT=1 _ghost_boot
[[ "$(bindkey '^G')" == *"ghost-popup"* ]] || { echo "FAIL: Ctrl-G not bound to ghost-popup"; exit 1; }
[[ "$(bindkey '\e[C')" == *"ghost-accept-full"* ]] || { echo "FAIL: Right arrow not bound"; exit 1; }
[[ "$(bindkey '^F')" == *"ghost-accept-word"* ]] || { echo "FAIL: Ctrl-F not bound"; exit 1; }

echo "ALL test_tab_navigation PASSED"
