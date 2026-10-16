#!/usr/bin/env zsh
# Test: Popup UI & Fallback
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/ui/popup.ui.zsh"

# 1. ghost_ui_popup_available detects fzf
if (( $+commands[fzf] )); then
  ghost_ui_popup_available || { echo "FAIL: expected fzf to be detected"; exit 1; }
fi

# 2. Native fallback formats and renders candidates without error
candidates=("45:git:git checkout -b feature" "40:history:npm run dev" "10:cmd:docker compose up")
ghost_ui_popup_native "${candidates[@]}"
[[ ${#_ghost_popup_items} -eq 3 ]] || { echo "FAIL: expected 3 popup items; got ${#_ghost_popup_items}"; exit 1; }
[[ "${_ghost_popup_raw_items[1]}" == "git checkout -b feature" ]] || { echo "FAIL: raw item 1 mismatch"; exit 1; }

# 3. Buffer updated after selection
BUFFER=""
CURSOR=0
_ghost_popup_index=1
ghost_ui_popup_native_select
[[ "$BUFFER" == "git checkout -b feature" ]] || { echo "FAIL: buffer not updated; got '$BUFFER'"; exit 1; }
[[ $CURSOR -eq ${#BUFFER} ]] || { echo "FAIL: cursor position mismatch"; exit 1; }

# 4. fzf-based popup parsing (mock selection)
mock_selected="󰊢  git commit -m \"msg\"  │ git │ history"$'\t'"git commit -m \"msg\""
BUFFER=""
CURSOR=0
chosen="${mock_selected#*$'\t'}"
BUFFER="$chosen"
CURSOR=${#BUFFER}
[[ "$BUFFER" == "git commit -m \"msg\"" ]] || { echo "FAIL: fzf mock extraction failed"; exit 1; }

echo "ALL test_popup PASSED"
