#!/usr/bin/env zsh
# Test: Pure Zsh Loading Indicator
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-config.zsh"
source "$ROOT_DIR/ui/loading.ui.zsh"

# 1. loading start/stop toggles active state
_ghost_loading_stop
[[ "$_ghost_loading_state" == "idle" ]] || { echo "FAIL: initial state not idle"; exit 1; }
_ghost_loading_start "test_op"
[[ "$_ghost_loading_state" == "computing" ]] || { echo "FAIL: start did not set computing state"; exit 1; }
[[ "$_ghost_loading_label" == "test_op" ]] || { echo "FAIL: start did not set label"; exit 1; }
_ghost_loading_stop
[[ "$_ghost_loading_state" == "idle" ]] || { echo "FAIL: stop did not reset state to idle"; exit 1; }
[[ -z "$_ghost_loading_indicator" ]] || { echo "FAIL: indicator not empty after stop"; exit 1; }

# 2. No indicator under threshold (default 200ms)
_ghost_loading_start "fast_op"
_ghost_loading_refresh
[[ -z "$_ghost_loading_indicator" ]] || { echo "FAIL: indicator appeared under threshold"; exit 1; }
_ghost_loading_stop

# 3. Indicator appears after threshold
_ghost_config_cache[ui.loading.threshold_ms]="20"
_ghost_loading_start "slow_op"
sleep 0.03
_ghost_loading_refresh
[[ -n "$_ghost_loading_indicator" ]] || { echo "FAIL: indicator did not appear after threshold"; exit 1; }
_ghost_loading_stop

# 4. style=minimal → ⏳
_ghost_config_cache[ui.loading.style]="minimal"
_ghost_config_cache[ui.loading.threshold_ms]="1"
_ghost_loading_start "minimal_op"
sleep 0.005
_ghost_loading_refresh
[[ "$_ghost_loading_indicator" == "⏳"* ]] || {
  echo "FAIL: expected minimal style ⏳; got '$_ghost_loading_indicator'"
  exit 1
}
_ghost_loading_stop

# 5. style=spinner → cycles chars
_ghost_config_cache[ui.loading.style]="spinner"
_ghost_loading_start "spinner_op"
sleep 0.005
_ghost_loading_refresh
char1="$_ghost_loading_indicator"
[[ -n "$char1" ]] || { echo "FAIL: spinner frame 1 empty"; exit 1; }
_ghost_loading_refresh
char2="$_ghost_loading_indicator"
[[ -n "$char2" ]] || { echo "FAIL: spinner frame 2 empty"; exit 1; }
_ghost_loading_stop

# 6. style=text → includes label
_ghost_config_cache[ui.loading.style]="text"
_ghost_loading_start "custom_worker"
sleep 0.005
_ghost_loading_refresh
[[ "$_ghost_loading_indicator" == *"[custom_worker...]"* ]] || {
  echo "FAIL: expected text style with label; got '$_ghost_loading_indicator'"
  exit 1
}
_ghost_loading_stop

# 7. disabled via config → no indicator
_ghost_config_cache[ui.loading.enabled]="false"
_ghost_loading_start "disabled_op"
sleep 0.005
_ghost_loading_refresh
[[ -z "$_ghost_loading_indicator" ]] || {
  echo "FAIL: indicator appeared when ui.loading.enabled=false"
  exit 1
}
_ghost_loading_stop
_ghost_config_cache[ui.loading.enabled]="true"

# 8. RPROMPT wrapper output
_ghost_config_cache[ui.loading.style]="minimal"
_ghost_loading_start "rprompt_test"
sleep 0.005
wrap_out="$(_ghost_loading_rprompt_wrap)"
[[ "$wrap_out" == "⏳"* ]] || {
  echo "FAIL: rprompt wrap output mismatch; got '$wrap_out'"
  exit 1
}
_ghost_loading_stop
wrap_idle="$(_ghost_loading_rprompt_wrap)"
[[ -z "$wrap_idle" ]] || {
  echo "FAIL: rprompt wrap should be empty when idle; got '$wrap_idle'"
  exit 1
}

echo "ALL test_loading_indicator PASSED"
