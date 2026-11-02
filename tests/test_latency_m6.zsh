#!/usr/bin/env zsh
# ziro-ghost v2.0.0 — M6 Strict Latency & Zero-Fork Test Suite
# Tests: <1.0ms sync suggest, <1.5ms all caches, zero forks, empty cache speed, budget guard, gateway check

set -e

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

source "$REPO_ROOT/ghost.plugin.zsh"

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

print -r -- "=== Running M6 Latency & Zero-Fork Tests ==="

_ghost_source_refresh_all

# Test 1: test_sync_suggest_under_1ms (20 runs median < 1.0ms)
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
assert_lt "$median" "1.0" "test_sync_suggest_under_1ms (median)"

# Test 2: test_sync_suggest_with_all_caches_under_1_5ms
# Populate all caches with dummy lines
_GHOST_SOURCE_CACHE[project]="git status"$'\n'"git log"$'\n'"git diff"
typeset -ga _GHOST_SOURCE_LINES_project=('git status' 'git log' 'git diff')
_GHOST_SOURCE_CACHE[zoxide]="/home/ali/Projects/ziro-ghost"$'\n'"/home/ali/Projects/ziro-shell"
typeset -ga _GHOST_SOURCE_LINES_zoxide=('/home/ali/Projects/ziro-ghost' '/home/ali/Projects/ziro-shell')
local -a times_all=()
for i in {1..20}; do
  BUFFER="git "
  local t0=$EPOCHREALTIME
  _ghost_suggest
  local t1=$EPOCHREALTIME
  times_all+=($(( (t1 - t0) * 1000.0 )))
done
times_all=(${(on)times_all})
local median_all="${times_all[10]}"
assert_lt "$median_all" "1.5" "test_sync_suggest_with_all_caches_under_1_5ms"

# Test 3: test_zero_forks_in_suggest (0 processes spawned in /proc/stat)
typeset -g _proc_count=0
_read_proc_stat_processes() {
  local line
  if [[ -r /proc/stat ]]; then
    while IFS= read -r line; do
      if [[ "$line" == "processes "* ]]; then
        _proc_count="${line#processes }"
        return 0
      fi
    done < /proc/stat
  fi
  _proc_count=0
}
_read_proc_stat_processes
local p_start=$_proc_count
BUFFER="git "
_ghost_suggest
_read_proc_stat_processes
local p_end=$_proc_count
local delta=$(( p_end - p_start ))
assert_eq "0" "$delta" "test_zero_forks_in_suggest (delta processes = 0)"

# Test 4: test_empty_cache_still_fast
# Clear caches temporarily
local old_hist="${_GHOST_SOURCE_CACHE[history]:-}"
_GHOST_SOURCE_CACHE[history]=""
typeset -ga _GHOST_SOURCE_LINES_history=()
BUFFER="nonexistentcommand "
local t0=$EPOCHREALTIME
_ghost_suggest
local t1=$EPOCHREALTIME
local empty_ms=$(( (t1 - t0) * 1000.0 ))
assert_lt "$empty_ms" "0.5" "test_empty_cache_still_fast"
assert_eq "" "$POSTDISPLAY" "test_empty_cache_returns_nothing"
# Restore history
_GHOST_SOURCE_CACHE[history]="$old_hist"
_ghost_source_refresh history

# Test 5: test_budget_guard
_ghost_source_dispatch_sync "git " 1
assert_lt "$_GHOST_SUGGEST_ELAPSED" "1.5" "test_budget_guard (_GHOST_SUGGEST_ELAPSED recorded < 1.5ms)"

# Test 6: test_gateway_validate_rejects_bad_intent
# Empty BUFFER clears POSTDISPLAY immediately
BUFFER=""
_ghost_suggest
assert_eq "" "$POSTDISPLAY" "test_gateway_validate_rejects_empty_buffer"

print -r -- "=== Results: $TESTS_PASSED passed, $TESTS_FAILED failed ==="
if (( TESTS_FAILED > 0 )); then
  exit 1
fi
exit 0
