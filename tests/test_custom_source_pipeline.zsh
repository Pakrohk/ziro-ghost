#!/usr/bin/env zsh
# Test: Custom source pipeline integration & safety guards
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/ghost.plugin.zsh"

# 1. custom source participates in primary pass
_custom_primary_handler() {
  emulate -L zsh
  local q="$1"
  _ghost_results=()
  [[ "$q" == "mywork"* ]] && _ghost_results+=("mywork task1" "mywork task2")
  return 0
}

ghost_register_source custom_primary \
  --handler _custom_primary_handler \
  --weight 60 \
  --kind cmd \
  --intent "custom primary"

BUFFER="mywork"
_ghost_compute
[[ -n "$_GHOST_CURRENT_SUGGESTION" ]] || { echo "FAIL: custom source did not provide suggestion"; exit 1; }
[[ "$_GHOST_CURRENT_SUGGESTION" == "mywork task"* ]] || {
  echo "FAIL: expected mywork task suggestion; got '$_GHOST_CURRENT_SUGGESTION'"
  exit 1
}

# 2. custom source with fallback_only runs only if primary empty
_custom_fallback_handler() {
  emulate -L zsh
  local q="$1"
  _ghost_results=()
  [[ "$q" == "fallback_trigger"* ]] && _ghost_results+=("5:typo:recovered_command")
  return 0
}

ghost_register_source custom_fb \
  --handler _custom_fallback_handler \
  --weight 5 \
  --kind typo \
  --intent "custom fallback" \
  --fallback-only

# Primary pass matches "mywork", so custom_fb does NOT fire
BUFFER="mywork"
_ghost_compute
[[ "$_GHOST_CURRENT_SUGGESTION" != "recovered_command" ]] || {
  echo "FAIL: fallback source should not run when primary matches"
  exit 1
}

# When query has no primary match, custom_fb fires
BUFFER="fallback_trigger"
_ghost_compute
[[ "$_GHOST_CURRENT_SUGGESTION" == "recovered_command" ]] || {
  echo "FAIL: fallback source did not fire on empty primary; got '$_GHOST_CURRENT_SUGGESTION'"
  exit 1
}

# 3. custom handler crash → pipeline continues without throwing
_crashing_handler() {
  return 127
}

ghost_register_source crash_src \
  --handler _crashing_handler \
  --weight 30 \
  --kind cmd

BUFFER="mywork"
_ghost_compute
[[ -n "$_GHOST_CURRENT_SUGGESTION" ]] || { echo "FAIL: crashing handler broke pipeline"; exit 1; }

# 4. handler timeout → skipped
_slow_handler() {
  emulate -L zsh
  _ghost_results=("slow_result")
  sleep 0.08
  return 0
}

ghost_register_source slow_src \
  --handler _slow_handler \
  --weight 80 \
  --kind cmd

# Timeout is 50ms, handler sleeps 80ms → results should be discarded
_ghost_config_cache[safety.handler_timeout_ms]="50"
BUFFER="slow_trigger"
_ghost_compute
[[ "$_GHOST_CURRENT_SUGGESTION" != "slow_result" ]] || {
  echo "FAIL: slow handler should have timed out and been discarded"
  exit 1
}

echo "ALL test_custom_source_pipeline PASSED"
