#!/usr/bin/env zsh
# Test: Source Statistics & Accountability API
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"
source "$ROOT_DIR/core/ghost-core.zsh"

_stat_handler() {
  emulate -L zsh
  _ghost_results=("res1" "res2")
  return 0
}

ghost_register_source stat_test \
  --handler _stat_handler \
  --max-suggestions 10 \
  --timeout-ms 50

# 1. ghost_source_stats returns correct counts after calls
_ghost_invoke_handler _stat_handler "q1" stat_test
_ghost_invoke_handler _stat_handler "q2" stat_test

info="$(ghost_source_stats stat_test)"
[[ "$info" == *"calls:              2"* ]] || {
  echo "FAIL: expected calls: 2; got '$info'"
  exit 1
}
[[ "$info" == *"timeout_violations: 0"* ]] || {
  echo "FAIL: expected timeout_violations: 0; got '$info'"
  exit 1
}

# 2. ghost_source_stats after timeout shows violations
_slow_stat_handler() {
  sleep 0.04
  return 0
}

ghost_register_source slow_stat_test \
  --handler _slow_stat_handler \
  --max-suggestions 5 \
  --timeout-ms 10

_ghost_invoke_handler _slow_stat_handler "q" slow_stat_test || true
slow_info="$(ghost_source_stats slow_stat_test)"
[[ "$slow_info" == *"timeout_violations: 1"* ]] || {
  echo "FAIL: expected timeout_violations: 1; got '$slow_info'"
  exit 1
}

# 3. ghost_all_source_stats aggregates all registered sources
all_info="$(ghost_all_source_stats)"
[[ "$all_info" == *"Source: stat_test"* && "$all_info" == *"Source: slow_stat_test"* ]] || {
  echo "FAIL: expected both sources in all_source_stats; got '$all_info'"
  exit 1
}

# 4. ghost_source_stats_reset clears counters
ghost_source_stats_reset stat_test
reset_info="$(ghost_source_stats stat_test)"
[[ "$reset_info" == *"calls:              0"* ]] || {
  echo "FAIL: expected calls reset to 0; got '$reset_info'"
  exit 1
}

echo "ALL test_source_stats PASSED"
