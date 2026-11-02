#!/usr/bin/env zsh
# ziro-ghost v2.0.0 — M9 Declarative Manifest & Health Command Tests
# Tests 10 behaviors:
# 1. test_manifest_valid_toml — python tomllib parses ziro-plugin.toml
# 2. test_manifest_has_required_sections — [plugin], [entry], [intents], [health]
# 3. test_manifest_health_command — health.command == 'ghost health --json'
# 4. test_ghost_health_json_schema — ghost health --json parses with status/message/checks
# 5. test_ghost_health_ok_when_clean — after normal setup, status = ok
# 6. test_ghost_health_warn_on_bad_perms — chmod 644 cache file, health shows warn
# 7. test_ghost_health_error_on_missing_cache — missing cache dir shows error
# 8. test_ghost_health_fast_under_500ms — execution completes under 500ms
# 9. test_ziro_health_ghost_works — ziro-shell runs ghost health
# 10. test_ziro_stats_ghost_shows_metrics — ziro-shell stats reads ghost metrics

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

print -r -- "=== Running M9 Declarative Manifest & Health Tests ==="

MANIFEST="$REPO_ROOT/ziro-plugin.toml"

# Test 1: test_manifest_valid_toml
local toml_ok=0
if python3 -c '
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    tomllib.load(f)
' "$MANIFEST" 2>/dev/null; then
  toml_ok=1
fi
assert_eq "1" "$toml_ok" "test_manifest_valid_toml (tomllib parse succeeds)"

# Test 2: test_manifest_has_required_sections
local sections_ok=0
if python3 -c '
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    d = tomllib.load(f)
req = ["plugin", "entry", "intents", "health", "sources", "cache", "metrics", "binaries", "mcp"]
assert all(k in d for k in req)
' "$MANIFEST" 2>/dev/null; then
  sections_ok=1
fi
assert_eq "1" "$sections_ok" "test_manifest_has_required_sections (all 9 sections present)"

# Test 3: test_manifest_health_command
local cmd_val
cmd_val=$(python3 -c '
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    d = tomllib.load(f)
print(d.get("health", {}).get("command", ""))
' "$MANIFEST" 2>/dev/null)
assert_eq "ghost health --json" "$cmd_val" "test_manifest_health_command (health.command == 'ghost health --json')"

# Source ghost plugin in isolated environment for health tests
source "$REPO_ROOT/ghost.plugin.zsh"

# Test 4: test_ghost_health_json_schema
local raw_json
raw_json=$(_ghost_health_json)
local schema_ok=0
if python3 -c '
import sys, json
d = json.loads(sys.argv[1])
assert "status" in d and "message" in d and "checks" in d
assert isinstance(d["checks"], list)
assert len(d["checks"]) == 8
assert all("name" in c and "status" in c and "message" in c for c in d["checks"])
' "$raw_json" 2>/dev/null; then
  schema_ok=1
fi
assert_eq "1" "$schema_ok" "test_ghost_health_json_schema (valid JSON with 8 checks and standard schema)"

# Test 5: test_ghost_health_ok_when_clean
local status_val
status_val=$(python3 -c 'import sys, json; print(json.loads(sys.argv[1])["status"])' "$raw_json")
assert_eq "ok" "$status_val" "test_ghost_health_ok_when_clean (overall status = ok)"

# Test 6: test_ghost_health_warn_on_bad_perms
local test_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ziro/ghost"
local bad_file="$test_cache_dir/temp-cache"
print "sample" > "$bad_file"
chmod 644 "$bad_file"
local warn_json
warn_json=$(_ghost_health_json)
rm -f "$bad_file"
local warn_status
warn_status=$(python3 -c 'import sys, json; print(json.loads(sys.argv[1])["status"])' "$warn_json")
assert_eq "warn" "$warn_status" "test_ghost_health_warn_on_bad_perms (warn on 644 cache file)"

# Test 7: test_ghost_health_error_on_missing_cache
local orig_cache="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CACHE_HOME="/tmp/ghost_nonexistent_cache_$$"
local err_json
err_json=$(_ghost_health_json)
local err_status
err_status=$(python3 -c 'import sys, json; print(json.loads(sys.argv[1])["status"])' "$err_json")
assert_eq "error" "$err_status" "test_ghost_health_error_on_missing_cache (error when cache dir missing)"
export XDG_CACHE_HOME="$orig_cache"

# Test 8: test_ghost_health_fast_under_500ms
local t0=$EPOCHREALTIME
_ghost_health_json >/dev/null
local t1=$EPOCHREALTIME
local dur_ms=$(( (t1 - t0) * 1000.0 ))
assert_lt "$dur_ms" "500" "test_ghost_health_fast_under_500ms (duration < 500ms)"

# Test 9: test_ziro_health_ghost_works
local ziro_health_out
ziro_health_out=$(zsh -f -c 'source ~/.zshrc 2>/dev/null; ziro health ghost' 2>&1)
local has_healthy=0
if [[ "$ziro_health_out" == *"HEALTHY"* ]] && [[ "$ziro_health_out" == *"ghost"* ]]; then
  has_healthy=1
fi
assert_eq "1" "$has_healthy" "test_ziro_health_ghost_works (ziro health ghost returns HEALTHY)"

# Test 10: test_ziro_stats_ghost_shows_metrics
local ziro_stats_out
ziro_stats_out=$(zsh -f -c 'source ~/.zshrc 2>/dev/null; ziro stats --tool ghost' 2>&1)
local stats_ok=0
if [[ "$ziro_stats_out" == *"ghost"* ]] && [[ "$ziro_stats_out" == *"Total intents"* ]]; then
  stats_ok=1
fi
assert_eq "1" "$stats_ok" "test_ziro_stats_ghost_shows_metrics (ziro stats reads ghost metrics)"

print -r -- "=== Results: $TESTS_PASSED passed, $TESTS_FAILED failed ==="
if (( TESTS_FAILED > 0 )); then
  exit 1
fi
exit 0
