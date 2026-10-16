#!/usr/bin/env zsh
# Test: Custom Source Contract-Based Safety Enforcement
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"
source "$ROOT_DIR/core/ghost-core.zsh"

# 1. Contract validation function
ghost_validate_source_contract "test" "10" "30" || { echo "FAIL: valid contract rejected"; exit 1; }
! ghost_validate_source_contract "test" "-5" "30" || { echo "FAIL: negative max_suggestions accepted"; exit 1; }
! ghost_validate_source_contract "test" "10" "-100" || { echo "FAIL: negative timeout_ms accepted"; exit 1; }
! ghost_validate_source_contract "test" "0" "30" || { echo "FAIL: zero max_suggestions accepted"; exit 1; }

# 2. Custom source without contract in config → warning + default 50:100
tmp_conf="$(mktemp)"
tmp_err="$(mktemp)"
trap 'rm -f "$tmp_conf" "$tmp_err"' EXIT

cat << 'EOF' > "$tmp_conf"
[[sources]]
name = "no_contract"
handler = "_dummy_handler"
weight = 20
kind = "cmd"
enabled = true
EOF

_ghost_config_custom_sources=()
_ghost_config_load_toml "$tmp_conf"
ghost_load_custom_sources 2> "$tmp_err"
warn_msg="$(<"$tmp_err")"
[[ "$warn_msg" == *"warning"* && "$warn_msg" == *"missing contract"* ]] || {
  echo "FAIL: expected missing contract warning; got '$warn_msg'"
  exit 1
}
[[ "${_ghost_source_contract[no_contract]:-}" == "50:100" ]] || {
  echo "FAIL: expected default contract 50:100; got '${_ghost_source_contract[no_contract]:-}'"
  exit 1
}

# 3. Custom source with contract in config → parsed correctly
cat << 'EOF' > "$tmp_conf"
[[sources]]
name = "with_contract"
handler = "_dummy_handler"
weight = 25
kind = "cmd"
enabled = true
max_suggestions = 10
timeout_ms = 35
EOF

_ghost_config_custom_sources=()
_ghost_config_load_toml "$tmp_conf"
ghost_load_custom_sources 2>/dev/null
[[ "${_ghost_source_contract[with_contract]:-}" == "10:35" ]] || {
  echo "FAIL: contract mismatch; expected 10:35, got '${_ghost_source_contract[with_contract]:-}'"
  exit 1
}

# 4. Handler returning > max_suggestions → truncated
_flood_handler() {
  emulate -L zsh
  _ghost_results=("item1" "item2" "item3" "item4" "item5" "item6")
  return 0
}

ghost_register_source flood_src \
  --handler _flood_handler \
  --max-suggestions 3 \
  --timeout-ms 100

_ghost_invoke_handler _flood_handler "query" flood_src
[[ ${#_ghost_results} -eq 3 ]] || {
  echo "FAIL: expected 3 truncated results; got ${#_ghost_results}"
  exit 1
}
[[ "${_ghost_source_stats[flood_src.truncations]:-0}" -eq 1 ]] || {
  echo "FAIL: truncations stat was not incremented"
  exit 1
}

# 5. Handler exceeding timeout_ms → discarded + timeout_violations++
_slow_contract_handler() {
  emulate -L zsh
  _ghost_results=("late_item")
  sleep 0.05
  return 0
}

ghost_register_source slow_contract_src \
  --handler _slow_contract_handler \
  --max-suggestions 10 \
  --timeout-ms 20

_ghost_invoke_handler _slow_contract_handler "query" slow_contract_src || true
[[ ${#_ghost_results} -eq 0 ]] || {
  echo "FAIL: slow handler results should have been discarded on timeout"
  exit 1
}
[[ "${_ghost_source_stats[slow_contract_src.timeout_violations]:-0}" -eq 1 ]] || {
  echo "FAIL: timeout_violations stat was not incremented"
  exit 1
}

# 6. Handler with valid contract within limits → no violations
_good_handler() {
  emulate -L zsh
  _ghost_results=("good1" "good2")
  return 0
}

ghost_register_source good_src \
  --handler _good_handler \
  --max-suggestions 5 \
  --timeout-ms 100

_ghost_invoke_handler _good_handler "query" good_src
[[ ${#_ghost_results} -eq 2 ]] || {
  echo "FAIL: valid handler results lost"
  exit 1
}
[[ "${_ghost_source_stats[good_src.timeout_violations]:-0}" -eq 0 ]] || {
  echo "FAIL: unexpected timeout violations on good handler"
  exit 1
}
[[ "${_ghost_source_stats[good_src.truncations]:-0}" -eq 0 ]] || {
  echo "FAIL: unexpected truncations on good handler"
  exit 1
}

echo "ALL test_contract_enforcement PASSED"
