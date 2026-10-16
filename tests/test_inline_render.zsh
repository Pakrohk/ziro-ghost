#!/usr/bin/env zsh
# Test: Inline UI POSTDISPLAY rendering parsing and suffix calculation
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-core.zsh"
source "$ROOT_DIR/ui/inline.ui.zsh"

# Case 1: Raw candidate formatted as weight:kind:text should only render text suffix
BUFFER="git pu"
ghost_ui_inline_render "40:history:git push origin main" "history"
[[ "$POSTDISPLAY" == "sh origin main" ]] || { echo "FAIL: expected exact suffix 'sh origin main'; got '$POSTDISPLAY'"; exit 1; }
[[ "$POSTDISPLAY" != *"40:"* ]] || { echo "FAIL: raw weight leaked into POSTDISPLAY: $POSTDISPLAY"; exit 1; }
expected_color="$(_ghost_ghost_color)"
[[ "${region_highlight[*]}" == *"6 20 ${expected_color}"* ]] || { echo "FAIL: region_highlight missing or incorrect: ${region_highlight[*]}"; exit 1; }

# Case 2: Bare text candidate
BUFFER="cd "
ghost_ui_inline_render "cd Projects" "path"
[[ "$POSTDISPLAY" == "Projects" ]] || { echo "FAIL: expected 'Projects'; got '$POSTDISPLAY'"; exit 1; }
[[ "${region_highlight[*]}" == *"3 11 ${expected_color}"* ]] || { echo "FAIL: region_highlight missing: ${region_highlight[*]}"; exit 1; }

# Case 3: Non-matching candidate clears POSTDISPLAY and highlight
BUFFER="z"
ghost_ui_inline_render "5:typo:ls" "typo"
[[ -z "$POSTDISPLAY" ]] || { echo "FAIL: non-matching candidate should clear POSTDISPLAY; got '$POSTDISPLAY'"; exit 1; }
[[ ${#region_highlight} -eq 0 ]] || { echo "FAIL: non-matching candidate should clear region_highlight; got ${region_highlight[*]}"; exit 1; }

# Case 4: Empty input clears POSTDISPLAY and highlight
BUFFER="anything"
ghost_ui_inline_render ""
[[ -z "$POSTDISPLAY" ]] || { echo "FAIL: empty input should clear POSTDISPLAY; got '$POSTDISPLAY'"; exit 1; }
[[ ${#region_highlight} -eq 0 ]] || { echo "FAIL: empty input should clear region_highlight; got ${region_highlight[*]}"; exit 1; }

echo "ALL test_inline_render PASSED"
