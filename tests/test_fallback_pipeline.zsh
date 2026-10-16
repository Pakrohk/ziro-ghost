#!/usr/bin/env zsh
# Test: Fallback pipeline execution order
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/ghost.plugin.zsh"

# 1. Normal sources run first: when user types "git st", primary sources (subcommand) return results
BUFFER="git st"
_ghost_compute
[[ -n "$_GHOST_CURRENT_SUGGESTION" ]] || { echo "FAIL: expected suggestion for git st"; exit 1; }
[[ "$_GHOST_CURRENT_KIND" != "typo" ]] || { echo "FAIL: normal query should not be typo kind"; exit 1; }

# 2. Fallback sources skipped when primary returns results
# Verify that typo source wasn't used for a valid query
[[ "$_GHOST_CURRENT_SUGGESTION" == "git st"* ]] || { echo "FAIL: unexpected suggestion '$_GHOST_CURRENT_SUGGESTION'"; exit 1; }

# 3. Fallback sources run when primary is empty
# For an unknown typo command like "sdu", primary sources return nothing, so typo runs
BUFFER="sdu"
_ghost_compute
[[ -n "$_GHOST_CURRENT_SUGGESTION" ]] || { echo "FAIL: expected suggestion for sdu"; exit 1; }
[[ "$_GHOST_CURRENT_KIND" == "typo" ]] || { echo "FAIL: expected kind 'typo'; got '$_GHOST_CURRENT_KIND'"; exit 1; }
[[ "$_GHOST_CURRENT_SUGGESTION" == "sudo" ]] || { echo "FAIL: expected sudo suggestion; got '$_GHOST_CURRENT_SUGGESTION'"; exit 1; }

# 4. Merged results in popup include typo kind
BUFFER="sdu"
_ghost_popup_opened_items=()
ghost_ui_popup_open() {
  _ghost_popup_opened_items=("$@")
}
_ghost_popup
[[ ${#_ghost_popup_opened_items} -gt 0 ]] || { echo "FAIL: popup should receive typo candidates"; exit 1; }
[[ "${_ghost_popup_opened_items[1]}" == *":typo:sudo" ]] || { echo "FAIL: expected typo:sudo in popup items; got '${_ghost_popup_opened_items[1]}'"; exit 1; }

echo "ALL test_fallback_pipeline PASSED"
