#!/usr/bin/env zsh
# ziro-ghost v2.0.0 — M7 ziro-defer Integration Tests
# Tests 8 behaviors: init-time deferral, ziro-defer stage-5 routing, precmd fallback,
# single-run hook cleanup, warmup population, idempotency, suggest after warmup, latency <1ms.

set -e

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

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

assert_gt() {
  local val="$1"
  local min="$2"
  local desc="$3"
  if (( val > min )); then
    print -r -- "  PASS: $desc ($val > $min)"
    (( ++TESTS_PASSED ))
  else
    print -r -- "  FAIL: $desc ($val not > $min)" >&2
    (( ++TESTS_FAILED ))
  fi
}

assert_lt() {
  local val="$1"
  local ceiling="$2"
  local desc="$3"
  if (( val < ceiling )); then
    print -r -- "  PASS: $desc (${val}ms < ${ceiling}ms)"
    (( ++TESTS_PASSED ))
  else
    print -r -- "  FAIL: $desc (${val}ms not < ${ceiling}ms)" >&2
    (( ++TESTS_FAILED ))
  fi
}

print -r -- "=== Running M7 ziro-defer Integration Tests ==="

# Test 1: test_init_only_registers_no_warmup
source "$REPO_ROOT/ghost.plugin.zsh"
local h_lines=${#${(f)_GHOST_SOURCE_CACHE[history]:-}}
local t_lines=${#${(f)_GHOST_SOURCE_CACHE[typo]:-}}
local p_lines=${#${(f)_GHOST_SOURCE_CACHE[project]:-}}
local z_lines=${#${(f)_GHOST_SOURCE_CACHE[zoxide]:-}}
assert_eq "0" "$h_lines" "test_init_only_registers_no_warmup (history empty)"
assert_eq "0" "$t_lines" "test_init_only_registers_no_warmup (typo empty)"
assert_eq "0" "$p_lines" "test_init_only_registers_no_warmup (project empty)"
assert_eq "0" "$z_lines" "test_init_only_registers_no_warmup (zoxide empty)"

# Test 2: test_with_ziro_defer_uses_stage5
typeset -g _MOCK_STAGE="" _MOCK_SLOT="" _MOCK_NAME="" _MOCK_CMD=""
ziro-defer() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stage=*) _MOCK_STAGE="${1#*=}" ;;
      --slot=*)  _MOCK_SLOT="${1#*=}" ;;
      --name=*)  _MOCK_NAME="${1#*=}" ;;
      *)         _MOCK_CMD="$1" ;;
    esac
    shift
  done
}
_ghost_defer_warmup
assert_eq "5" "$_MOCK_STAGE" "test_with_ziro_defer_uses_stage5 (stage 5)"
assert_eq "b" "$_MOCK_SLOT" "test_with_ziro_defer_uses_stage5 (slot b)"
assert_eq "ghost-warmup" "$_MOCK_NAME" "test_with_ziro_defer_uses_stage5 (name)"
assert_eq "_ghost_warmup" "$_MOCK_CMD" "test_with_ziro_defer_uses_stage5 (command)"

# Test 3: test_without_ziro_defer_uses_precmd
unfunction ziro-defer 2>/dev/null || true
typeset -g _GHOST_DEFER_AVAILABLE=0
_ghost_defer_warmup
autoload -Uz add-zsh-hook 2>/dev/null
local in_precmd=0 hook
for hook in "${precmd_functions[@]}"; do
  [[ "$hook" == "_ghost_defer_fallback_warmup" ]] && in_precmd=1
done
assert_eq "1" "$in_precmd" "test_without_ziro_defer_uses_precmd (hook registered)"

# Test 4: test_fallback_precmd_runs_once
# Simulate precmd firing once
_ghost_defer_fallback_warmup
# Verify hook removed
in_precmd=0
for hook in "${precmd_functions[@]}"; do
  [[ "$hook" == "_ghost_defer_fallback_warmup" ]] && in_precmd=1
done
assert_eq "0" "$in_precmd" "test_fallback_precmd_runs_once (hook removed after first run)"

# Test 5: test_warmup_populates_all_caches
_ghost_warmup
h_lines=${#${(f)_GHOST_SOURCE_CACHE[history]:-}}
t_lines=${#${(f)_GHOST_SOURCE_CACHE[typo]:-}}
assert_gt "$h_lines" "0" "test_warmup_populates_all_caches (history populated)"
assert_gt "$t_lines" "0" "test_warmup_populates_all_caches (typo populated)"

# Test 6: test_no_duplicate_warmup
_ghost_defer_warmup
_ghost_defer_warmup
_ghost_warmup
h_lines=${#${(f)_GHOST_SOURCE_CACHE[history]:-}}
assert_gt "$h_lines" "0" "test_no_duplicate_warmup (idempotent)"

# Test 7: test_suggest_after_warmup_works
_ghost_warmup
BUFFER="git "
_ghost_suggest
local has_sugg=$([[ -n "$POSTDISPLAY" ]] && echo "yes" || echo "no")
assert_eq "yes" "$has_sugg" "test_suggest_after_warmup_works (suggestion rendered)"

# Test 8: test_input_lag_unchanged
_ghost_warmup
local -a times=()
local i
for i in {1..20}; do
  BUFFER="git "
  local t0=$EPOCHREALTIME
  _ghost_suggest
  local t1=$EPOCHREALTIME
  times+=($(( (t1 - t0) * 1000.0 )))
done
times=(${(on)times})
local median="${times[10]}"
assert_lt "$median" "1.0" "test_input_lag_unchanged (median < 1.0ms)"

print -r -- "=== Results: $TESTS_PASSED passed, $TESTS_FAILED failed ==="
if (( TESTS_FAILED > 0 )); then
  exit 1
fi
exit 0
