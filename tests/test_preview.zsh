#!/usr/bin/env zsh
# Test: Preview Pane Renderer
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"
source "$ROOT_DIR/ui/preview.ui.zsh"

# 1. Preview render with valid candidate
local cmd="git status"
_ghost_preview_source_map[$cmd]="git"
_ghost_preview_frecency_map[$cmd]="85"

out="$(_ghost_preview_render "40:git:git status")"
[[ "$out" == *"Suggestion"* ]] || { echo "FAIL: missing suggestion header in preview"; exit 1; }
[[ "$out" == *"git status"* ]] || { echo "FAIL: missing candidate text in preview"; exit 1; }
[[ "$out" == *"Source:   git"* ]] || { echo "FAIL: source mismatch in preview; got '$out'"; exit 1; }
[[ "$out" == *"Frecency: 85"* ]] || { echo "FAIL: frecency mismatch in preview; got '$out'"; exit 1; }

# 2. Preview respects [ui.preview] enabled = false
_ghost_config_cache[ui.preview.enabled]="false"
disabled_out="$(_ghost_preview_render "40:git:git status")"
[[ -z "$disabled_out" ]] || {
  echo "FAIL: expected empty output when preview disabled; got '$disabled_out'"
  exit 1
}

echo "ALL test_preview PASSED"
