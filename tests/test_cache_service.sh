#!/usr/bin/env zsh
# ziro-ghost v2.0.0 — M4 Cache Service Hermetic Test Suite
# Tests 10 cache behaviors: init, put, get, perms, atomic writes, miss, invalidate, clear, TTL, max_size

set -e

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

# Use isolated temp directory for cache to guarantee hermetic test
export XDG_CACHE_HOME="$(mktemp -d /tmp/ghost-cache-test-XXXXXX)"
trap 'rm -rf "$XDG_CACHE_HOME"' EXIT INT TERM

source "$REPO_ROOT/core/ghost-bus.zsh"
source "$REPO_ROOT/core/ghost-cache.zsh"

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

print -r -- "=== Running M4 Cache Service Tests ==="

# Test 1: test_init_creates_700_dir
_ghost_cache_init
dir_perms="$(stat -c '%a' "$_GHOST_CACHE_ROOT")"
assert_eq "700" "$dir_perms" "test_init_creates_700_dir"

# Test 2: test_put_get_roundtrip
_ghost_intent_publish "ghost.cache.put" "ephemeral" '{"name":"project","content":"branch=main"}'
_ghost_intent_publish "ghost.cache.get" "ephemeral" '{"name":"project"}'
assert_match '"content":"branch=main"' "$_GHOST_BUS_LAST_RESPONSE" "test_put_get_roundtrip"

# Test 3: test_put_sets_600_perms
file_path="$(_ghost_cache_path "project")"
file_perms="$(stat -c '%a' "$file_path")"
assert_eq "600" "$file_perms" "test_put_sets_600_perms"

# Test 4: test_put_atomic_no_partial
# Verify no leftover .tmp files exist in cache root
tmp_count="$(find "$_GHOST_CACHE_ROOT" -name '*.tmp*' | wc -l)"
assert_eq "0" "$tmp_count" "test_put_atomic_no_partial"

# Test 5: test_get_missing_returns_miss
_ghost_intent_publish "ghost.cache.get" "ephemeral" '{"name":"eval"}'
assert_match '"miss":true' "$_GHOST_BUS_LAST_RESPONSE" "test_get_missing_returns_miss"

# Test 6: test_invalidate_removes_file
_ghost_intent_publish "ghost.cache.invalidate" "ephemeral" '{"name":"project"}'
file_exists=$([[ -f "$file_path" ]] && echo "yes" || echo "no")
assert_eq "no" "$file_exists" "test_invalidate_removes_file"

# Test 7: test_clear_all_removes_all
_ghost_intent_publish "ghost.cache.put" "ephemeral" '{"name":"eval","content":"e1"}'
_ghost_intent_publish "ghost.cache.put" "ephemeral" '{"name":"zoxide","content":"z1"}'
_ghost_intent_publish "ghost.cache.clear" "ephemeral" '{"type":"all"}'
eval_exists=$([[ -f "$(_ghost_cache_path "eval")" ]] && echo "yes" || echo "no")
zoxide_exists=$([[ -f "$(_ghost_cache_path "zoxide")" ]] && echo "yes" || echo "no")
assert_eq "no" "$eval_exists" "test_clear_all_removes_all (eval)"
assert_eq "no" "$zoxide_exists" "test_clear_all_removes_all (zoxide)"

# Test 8: test_ttl_expiration
_ghost_intent_publish "ghost.cache.put" "ephemeral" '{"name":"stats","content":"count=100"}'
stats_path="$(_ghost_cache_path "stats")"
# Touch file with mtime 120 seconds ago (stats TTL is 60s)
touch -d '120 seconds ago' "$stats_path"
_ghost_intent_publish "ghost.cache.get" "ephemeral" '{"name":"stats"}'
assert_match '"miss":true' "$_GHOST_BUS_LAST_RESPONSE" "test_ttl_expiration"

# Test 9: test_max_size_rejects
# zoxide max size is 20480 bytes (~20KB). Try putting 25000 bytes.
large_content="$(head -c 25000 < /dev/zero | tr '\0' 'A')"
ret=0
_ghost_intent_publish "ghost.cache.put" "ephemeral" "{\"name\":\"zoxide\",\"content\":\"${large_content}\"}" || ret=$?
assert_eq "1" "$ret" "test_max_size_rejects (return code)"
assert_match '"status":"error"' "$_GHOST_BUS_LAST_RESPONSE" "test_max_size_rejects (error payload)"

# Test 10: test_unknown_plugin_get
ret=0
_ghost_intent_publish "ghost.cache.get" "ephemeral" '{"name":"nonexistent_plugin"}' || ret=$?
assert_eq "1" "$ret" "test_unknown_plugin_get (return code)"
assert_match '"status":"error"' "$_GHOST_BUS_LAST_RESPONSE" "test_unknown_plugin_get (error payload)"

print -r -- "=== Results: $TESTS_PASSED passed, $TESTS_FAILED failed ==="
if (( TESTS_FAILED > 0 )); then
  exit 1
fi
exit 0
