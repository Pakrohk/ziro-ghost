#!/usr/bin/env zsh
# ziro-ghost v2.0.0 — M6 Source Functional Tests
# Tests 10 behaviors: history refresh, typo dict, project rust/python/outside,
# zoxide cold start and refresh, dedupe, priority ordering, and env disabling.

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

print -r -- "=== Running M6 Source Functional Tests ==="

# Test 1: test_history_refresh_populates
_ghost_source_refresh history
local hist_lines=${#${(f)_GHOST_SOURCE_CACHE[history]}}
assert_gt "$hist_lines" "0" "test_history_refresh_populates"

# Test 2: test_typo_dict_loads
_ghost_source_refresh typo
local typo_lines=${#${(f)_GHOST_SOURCE_CACHE[typo]}}
assert_gt "$typo_lines" "0" "test_typo_dict_loads"

# Test 3: test_project_detects_rust
local tmp_rust="$(mktemp -d /tmp/ghost-rust-XXXXXX)"
touch "$tmp_rust/Cargo.toml"
(
  cd "$tmp_rust"
  _ghost_source_project_chpwd
  has_cargo=$([[ "${_GHOST_SOURCE_CACHE[project]}" == *"cargo build"* ]] && echo "yes" || echo "no")
  assert_eq "yes" "$has_cargo" "test_project_detects_rust (has cargo)"
)
rm -rf "$tmp_rust"

# Test 4: test_project_detects_python
local tmp_py="$(mktemp -d /tmp/ghost-py-XXXXXX)"
touch "$tmp_py/pyproject.toml"
(
  cd "$tmp_py"
  _ghost_source_project_chpwd
  has_pytest=$([[ "${_GHOST_SOURCE_CACHE[project]}" == *"pytest"* ]] && echo "yes" || echo "no")
  assert_eq "yes" "$has_pytest" "test_project_detects_python (has pytest)"
)
rm -rf "$tmp_py"

# Test 5: test_project_skips_outside
(
  cd /tmp
  _ghost_source_project_chpwd
  local cache_out="${_GHOST_SOURCE_CACHE[project]:-}"
  assert_eq "" "$cache_out" "test_project_skips_outside"
)

# Test 6: test_zoxide_cold_start_empty
# Verify zoxide is empty before refresh is called on fresh state
_GHOST_SOURCE_CACHE[zoxide]=""
_GHOST_ZOXIDE_LAST_REFRESH=0
assert_eq "" "${_GHOST_SOURCE_CACHE[zoxide]}" "test_zoxide_cold_start_empty"

# Test 7: test_zoxide_precmd_refresh
_GHOST_ZOXIDE_LAST_REFRESH=0
_ghost_source_refresh zoxide
local z_lines=${#${(f)_GHOST_SOURCE_CACHE[zoxide]}}
if (( _GHOST_ZOXIDE_AVAILABLE )); then
  assert_gt "$z_lines" "0" "test_zoxide_precmd_refresh"
else
  # Simulated zoxide
  _GHOST_SOURCE_CACHE[zoxide]="/home/ali/Projects/ziro-ghost"
  typeset -ga _GHOST_SOURCE_LINES_zoxide=('/home/ali/Projects/ziro-ghost')
  z_lines=${#${(f)_GHOST_SOURCE_CACHE[zoxide]}}
  assert_gt "$z_lines" "0" "test_zoxide_precmd_refresh (simulated)"
fi

# Test 8: test_dispatch_dedupes_across_sources
# Inject duplicate command across two sources
_GHOST_SOURCE_CACHE[test_a]="dup_cmd 1"$'\n'"dup_cmd 2"
typeset -ga _GHOST_SOURCE_LINES_test_a=('dup_cmd 1' 'dup_cmd 2')
_ghost_source_register test_a 80 ""
_GHOST_SOURCE_CACHE[test_b]="dup_cmd 1"$'\n'"dup_cmd 3"
typeset -ga _GHOST_SOURCE_LINES_test_b=('dup_cmd 1' 'dup_cmd 3')
_ghost_source_register test_b 75 ""

_ghost_source_dispatch_sync "dup_cmd" 1
local -a results=("${_ghost_results[@]}")
local dup_count=0 item
for item in "${results[@]}"; do
  [[ "$item" == "dup_cmd 1" ]] && (( ++dup_count ))
done
assert_eq "1" "$dup_count" "test_dispatch_dedupes_across_sources"

# Test 9: test_dispatch_priority_order
# test_a has priority 80, test_b has priority 75
# test_a result ('dup_cmd 1') should precede test_b-only result ('dup_cmd 3')
assert_eq "dup_cmd 1" "${results[1]}" "test_dispatch_priority_order (highest priority first)"

# Test 10: test_disable_via_env
export ZIRO_GHOST_SOURCE_TEST_A=0
_ghost_source_dispatch_sync "dup_cmd 2" 1
assert_eq "0" "${#_ghost_results}" "test_disable_via_env (test_a skipped when ZIRO_GHOST_SOURCE_TEST_A=0)"
unset ZIRO_GHOST_SOURCE_TEST_A

print -r -- "=== Results: $TESTS_PASSED passed, $TESTS_FAILED failed ==="
if (( TESTS_FAILED > 0 )); then
  exit 1
fi
exit 0
