#!/usr/bin/env zsh
# ziro-ghost v2.0.0 — M5 Intent Gateway & Dependency Graph Hermetic Test Suite
# Tests 14 behaviors: pipeline resolution, 4 processors, gateway bypass, Kahn topo sort, and cycle detection

set -e

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

# Use isolated temp directory for test cache and metrics
export XDG_CACHE_HOME="$(mktemp -d /tmp/ghost-m5-test-XXXXXX)"
trap 'rm -rf "$XDG_CACHE_HOME"' EXIT INT TERM

source "$REPO_ROOT/core/ghost-bus.zsh"
source "$REPO_ROOT/core/ghost-gateway.zsh"
source "$REPO_ROOT/core/ghost-dependency.zsh"

TESTS_PASSED=0
TESTS_FAILED=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local desc="$3"
  if [[ "$expected" == "$actual" ]]; then
    print -r -- "  PASS: $desc"
    (( ++TESTS_PASSED ))
  else
    print -r -- "  FAIL: $desc (expected '$expected', got '$actual')" >&2
    (( ++TESTS_FAILED ))
  fi
}

assert_match() {
  local pattern="$1"
  local actual="$2"
  local desc="$3"
  if [[ "$actual" =~ $pattern ]]; then
    print -r -- "  PASS: $desc"
    (( ++TESTS_PASSED ))
  else
    print -r -- "  FAIL: $desc (pattern '$pattern' did not match '$actual')" >&2
    (( ++TESTS_FAILED ))
  fi
}

print -r -- "=== Running M5 Gateway & Dependency Tests ==="

_ghost_gateway_init

# Test 1: test_pipeline_resolution_ephemeral
res_ephemeral="$(_ghost_resolve_pipeline "ephemeral")"
assert_eq "validate" "$res_ephemeral" "test_pipeline_resolution_ephemeral"

# Test 2: test_pipeline_resolution_standard
res_standard="$(_ghost_resolve_pipeline "standard")"
assert_eq "validate authorize" "$res_standard" "test_pipeline_resolution_standard"

# Test 3: test_pipeline_resolution_critical
res_critical="$(_ghost_resolve_pipeline "critical")"
assert_eq "validate authorize audit protect" "$res_critical" "test_pipeline_resolution_critical"

# Test 4: test_validate_rejects_empty_name
ret=0
out="$(_ghost_processor_validate '{"id":"1","name":"","level":"ephemeral","metadata":{}}' 2>&1)" || ret=$?
assert_eq "1" "$ret" "test_validate_rejects_empty_name (return code)"
assert_match '"status":"error"' "$out" "test_validate_rejects_empty_name (error message)"

# Test 5: test_validate_rejects_invalid_level
ret=0
out="$(_ghost_processor_validate '{"id":"1","name":"test","level":"garbage","metadata":{}}' 2>&1)" || ret=$?
assert_eq "1" "$ret" "test_validate_rejects_invalid_level (return code)"
assert_match 'invalid level' "$out" "test_validate_rejects_invalid_level (error message)"

# Test 6: test_authorize_allows_normal_intents
ret=0
out="$(_ghost_processor_authorize '{"id":"1","name":"ghost.suggest.query","level":"standard","metadata":{}}' 2>&1)" || ret=$?
assert_eq "0" "$ret" "test_authorize_allows_normal_intents (return code)"
assert_match '"status":"ok"' "$out" "test_authorize_allows_normal_intents"

# Test 7: test_audit_writes_to_metrics
rm -f "$_GHOST_AUDIT_LOG"
_ghost_processor_audit '{"id":"audit-1","name":"test.audit","level":"standard","metadata":{}}' >/dev/null
audit_lines=0
[[ -f "$_GHOST_AUDIT_LOG" ]] && audit_lines=$(wc -l < "$_GHOST_AUDIT_LOG")
assert_eq "1" "$audit_lines" "test_audit_writes_to_metrics"

# Test 8: test_audit_skipped_for_ephemeral
_ghost_processor_audit '{"id":"audit-2","name":"test.audit","level":"ephemeral","metadata":{}}' >/dev/null
after_lines=$(wc -l < "$_GHOST_AUDIT_LOG")
assert_eq "1" "$after_lines" "test_audit_skipped_for_ephemeral"

# Test 9: test_protect_blocks_aws_key
ret=0
out="$(_ghost_processor_protect '{"id":"p1","name":"critical.task","level":"critical","metadata":{"key":"AKIAIOSFODNN7EXAMPLE"}}' 2>&1)" || ret=$?
assert_eq "1" "$ret" "test_protect_blocks_aws_key (return code)"
assert_match '"status":"error"' "$out" "test_protect_blocks_aws_key (error payload)"

# Test 10: test_gateway_bypass_env
# With bypass enabled, gateway validate is skipped, so empty name does not get blocked by gateway
export ZIRO_GHOST_GATEWAY_BYPASS=1
_GHOST_BUS_LAST_RESPONSE=""
ret=0
_ghost_intent_publish "" "ephemeral" "{}" 2>/dev/null || ret=$?
no_validate_err=$([[ "$_GHOST_BUS_LAST_RESPONSE" != *"invalid intent"* ]] && echo "yes" || echo "no")
assert_eq "yes" "$no_validate_err" "test_gateway_bypass_env"
unset ZIRO_GHOST_GATEWAY_BYPASS

# Test 11: test_dep_topo_sort_linear
_ghost_dep_reset
_ghost_dep_add A
_ghost_dep_add B A
_ghost_dep_add C B
order="$(_ghost_dep_topo_sort)"
assert_eq "A B C" "$order" "test_dep_topo_sort_linear"

# Test 12: test_dep_topo_sort_parallel
_ghost_dep_reset
_ghost_dep_add A
_ghost_dep_add B
order="$(_ghost_dep_topo_sort)"
has_a=$([[ "$order" == *"A"* ]] && echo "yes" || echo "no")
has_b=$([[ "$order" == *"B"* ]] && echo "yes" || echo "no")
assert_eq "yes" "$has_a" "test_dep_topo_sort_parallel (has A)"
assert_eq "yes" "$has_b" "test_dep_topo_sort_parallel (has B)"

# Test 13: test_dep_cycle_detection
_ghost_dep_reset
_ghost_dep_add X Y
_ghost_dep_add Y X
cycle_out="$(_ghost_dep_topo_sort 2>/dev/null || true)"
assert_eq "CYCLE" "$cycle_out" "test_dep_cycle_detection (CYCLE output)"
cycle_nodes="$(_ghost_dep_find_cycle 2>/dev/null || true)"
assert_eq "X Y" "$cycle_nodes" "test_dep_cycle_detection (cycle nodes)"

# Test 14: test_dep_cycle_self
_ghost_dep_reset
_ghost_dep_add Z Z
self_cycle="$(_ghost_dep_topo_sort 2>/dev/null || true)"
assert_eq "CYCLE" "$self_cycle" "test_dep_cycle_self (CYCLE output)"
self_nodes="$(_ghost_dep_find_cycle 2>/dev/null || true)"
assert_eq "Z" "$self_nodes" "test_dep_cycle_self (cycle nodes)"

print -r -- "=== Results: $TESTS_PASSED passed, $TESTS_FAILED failed ==="
if (( TESTS_FAILED > 0 )); then
  exit 1
fi
exit 0
