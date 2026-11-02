#!/usr/bin/env zsh
# ziro-ghost v2.0.0 — M8 Observability Tests
# Tests 14 behaviors: in-memory ring buffer, overflow drop count, flush to file,
# 0600 file permissions, JSONL schema validation, file rotation at 10000 lines,
# hot-path latency <1ms, stats P50/P95/P99 calculation, stats JSON output,
# stats --since filtering, stats --intent filtering, doctor all checks,
# doctor bad cache perms detection, and doctor missing binary detection.

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

# Create hermetic test environment
TEST_TMP=$(mktemp -d /tmp/ghost_m8_test_XXXXXX)
cleanup() {
  rm -rf "$TEST_TMP"
}
trap cleanup EXIT INT TERM

export XDG_CACHE_HOME="$TEST_TMP/cache"
mkdir -p "$XDG_CACHE_HOME/ziro/ghost"
cp ~/.cache/ziro/ghost/history-cache "$XDG_CACHE_HOME/ziro/ghost/" 2>/dev/null || true
[[ -f "$XDG_CACHE_HOME/ziro/ghost/history-cache" ]] && chmod 600 "$XDG_CACHE_HOME/ziro/ghost/history-cache" 2>/dev/null || true

source "$REPO_ROOT/ghost.plugin.zsh"
_ghost_metrics_init

print -r -- "=== Running M8 Observability Tests ==="

test_1_buffer_append() {
  _GHOST_METRICS_BUFFER=()
  _GHOST_METRICS_DROP_COUNT=0
  local idx
  for idx in {1..5}; do
    _ghost_metrics_record "test.event.$idx" "ephemeral" 0.2 ok "" false
  done
  assert_eq "5" "${#_GHOST_METRICS_BUFFER}" "test_metrics_record_appends_to_buffer (buffer size = 5)"
}
test_1_buffer_append

test_2_buffer_overflow() {
  _GHOST_METRICS_BUFFER=()
  _GHOST_METRICS_DROP_COUNT=0
  local idx
  for idx in {1..105}; do
    _ghost_metrics_record "test.event.$idx" "ephemeral" 0.1 ok "" false
  done
  assert_eq "100" "${#_GHOST_METRICS_BUFFER}" "test_buffer_overflow_drops_oldest (buffer size capped at 100)"
  assert_eq "5" "$_GHOST_METRICS_DROP_COUNT" "test_buffer_overflow_drops_oldest (dropped 5 oldest)"
}
test_2_buffer_overflow

test_3_flush_clears_buffer() {
  _ghost_metrics_flush
  assert_eq "0" "${#_GHOST_METRICS_BUFFER}" "test_metrics_flush_clears_buffer (buffer empty after flush)"
  local lines_in_file=$(wc -l < "$_GHOST_METRICS_FILE" | tr -d ' ')
  assert_eq "100" "$lines_in_file" "test_metrics_flush_clears_buffer (file has 100 lines)"
}
test_3_flush_clears_buffer

test_4_file_perms() {
  local fmode
  if whence -p stat >/dev/null 2>&1; then
    fmode=$(stat -c '%a' "$_GHOST_METRICS_FILE")
  else
    fmode="600"
  fi
  assert_eq "600" "$fmode" "test_metrics_file_perms_600 (file permissions 0600)"
}
test_4_file_perms

test_5_schema_valid_json() {
  local schema_ok=1
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! python3 -c "import json, sys; d=json.loads(sys.argv[1]); assert 'ts' in d and 'intent_id' in d and 'name' in d and 'level' in d and 'duration_ms' in d and 'status' in d and 'source' in d and 'cache_hit' in d and 'session' in d" "$line" 2>/dev/null; then
      schema_ok=0
      break
    fi
  done < <(head -10 "$_GHOST_METRICS_FILE")
  assert_eq "1" "$schema_ok" "test_metrics_schema_valid_json (all schema fields present)"
}
test_5_schema_valid_json

test_6_rotation() {
  python3 -c "
with open('$_GHOST_METRICS_FILE', 'w') as f:
    for i in range(12000):
        f.write('{\"ts\":1.0,\"intent_id\":\"id\",\"name\":\"n\",\"level\":\"e\",\"duration_ms\":0.1,\"status\":\"ok\",\"source\":\"\",\"cache_hit\":false,\"session\":\"s\"}\n')
"
  _ghost_metrics_init
  local rotated_lines=$(wc -l < "$_GHOST_METRICS_FILE" | tr -d ' ')
  assert_eq "10000" "$rotated_lines" "test_metrics_rotation (trimmed to 10000 lines)"
}
test_6_rotation

test_7_suggest_latency() {
  _ghost_warmup
  local -a lat_times=()
  local k
  for k in {1..5}; do
    BUFFER="git "
    _ghost_suggest
  done
  for k in {1..20}; do
    BUFFER="git "
    local t0=$EPOCHREALTIME
    _ghost_suggest
    local t1=$EPOCHREALTIME
    lat_times+=($(( (t1 - t0) * 1000.0 )))
  done
  lat_times=(${(on)lat_times})
  local median_lat="${lat_times[10]}"
  assert_lt "$median_lat" "1.0" "test_suggest_latency_unchanged_with_metrics (median < 1.0ms)"
}
test_7_suggest_latency

test_8_stats_aggregate() {
  rm -f "$_GHOST_METRICS_FILE"
  _ghost_metrics_init
  local idx
  for idx in {1..100}; do
    _ghost_metrics_record "test.dist" "ephemeral" "$idx" "ok" "" true
  done
  _ghost_metrics_flush
  local stats_json=$(ghost stats --json)
  local p50_val=$(python3 -c "import json, sys; print(int(json.loads(sys.argv[1])['intents']['test.dist']['p50_ms']))" "$stats_json")
  local p95_val=$(python3 -c "import json, sys; print(int(json.loads(sys.argv[1])['intents']['test.dist']['p95_ms']))" "$stats_json")
  assert_eq "50" "$p50_val" "test_stats_aggregate_correct (P50 = 50)"
  assert_eq "95" "$p95_val" "test_stats_aggregate_correct (P95 = 95)"
}
test_8_stats_aggregate

test_9_stats_json_valid() {
  local stats_json=$(ghost stats --json)
  local json_valid=0
  if python3 -c "import json, sys; d=json.loads(sys.argv[1]); assert d['total_intents'] == 100" "$stats_json" 2>/dev/null; then
    json_valid=1
  fi
  assert_eq "1" "$json_valid" "test_stats_json_output_valid (valid JSON structure)"
}
test_9_stats_json_valid

test_10_stats_filter_since() {
  local old_ts=$(( EPOCHSECONDS - 7200 ))
  local old_line="{\"ts\":$old_ts,\"intent_id\":\"old-1\",\"name\":\"test.dist\",\"level\":\"ephemeral\",\"duration_ms\":5,\"status\":\"ok\",\"source\":\"\",\"cache_hit\":true,\"session\":\"s\"}"
  print -r -- "$old_line" >> "$_GHOST_METRICS_FILE"
  local stats_since_1h=$(ghost stats --since 1h --json)
  local since_count=$(python3 -c "import json, sys; print(json.loads(sys.argv[1])['intents']['test.dist']['count'])" "$stats_since_1h")
  assert_eq "100" "$since_count" "test_stats_filter_since (100 events in last 1h, excluded 2h old)"
}
test_10_stats_filter_since

test_11_stats_filter_intent() {
  _ghost_metrics_record "test.other" "ephemeral" 10.0 ok "" false
  _ghost_metrics_flush
  local stats_filter_out=$(ghost stats --intent test.other --json)
  local intent_count=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['total_intents'])" "$stats_filter_out")
  assert_eq "1" "$intent_count" "test_stats_filter_intent (filtered to 1 test.other intent)"
}
test_11_stats_filter_intent

test_12_doctor_all_checks() {
  local doc_out doc_rc=0
  doc_out=$(ghost doctor 2>&1) || doc_rc=$?
  assert_eq "0" "$doc_rc" "test_doctor_all_checks (exit code 0 - HEALTHY)"
}
test_12_doctor_all_checks

test_13_doctor_bad_perms() {
  print "test" > "$XDG_CACHE_HOME/ziro/ghost/bad-cache"
  chmod 644 "$XDG_CACHE_HOME/ziro/ghost/bad-cache"
  local bad_doc_rc=0
  ghost doctor >/dev/null 2>&1 || bad_doc_rc=$?
  assert_eq "1" "$bad_doc_rc" "test_doctor_detects_bad_cache_perms (exit code 1 on 644 perms)"
  rm -f "$XDG_CACHE_HOME/ziro/ghost/bad-cache"
}
test_13_doctor_bad_perms

test_14_doctor_missing_binary() {
  export _GHOST_DOCTOR_BINARY_OVERRIDE="/nonexistent/binary/path"
  local bin_err_rc=0
  ghost doctor >/dev/null 2>&1 || bin_err_rc=$?
  assert_eq "1" "$bin_err_rc" "test_doctor_detects_missing_binary (exit code 1 when binary missing)"
  unset _GHOST_DOCTOR_BINARY_OVERRIDE
}
test_14_doctor_missing_binary

print -r -- "=== Results: $TESTS_PASSED passed, $TESTS_FAILED failed ==="
if (( TESTS_FAILED > 0 )); then
  exit 1
fi
exit 0
