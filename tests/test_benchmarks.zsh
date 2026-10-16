#!/usr/bin/env zsh
# Test: Automated Performance & Spec 011 Hot-Path Benchmarks
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
zmodload zsh/datetime 2>/dev/null || true

# 1. Hot-path plugin load time budget (< 50ms, target min-of-11)
best_load=9999.0
for i in {1..7}; do
  t0=$EPOCHREALTIME
  zsh -f -c "source '$ROOT_DIR/ghost.plugin.zsh'" >/dev/null 2>&1
  t1=$EPOCHREALTIME
  elapsed=$(( (t1 - t0) * 1000.0 ))
  (( elapsed < best_load )) && best_load=$elapsed
done

echo "Benchmark: plugin load = ${best_load}ms (ceiling: 50ms)"
(( best_load < 50.0 )) || {
  echo "FAIL: plugin load exceeded 50ms budget; got ${best_load}ms"
  exit 1
}

# 2. History query time (< 10ms)
source "$ROOT_DIR/ghost.plugin.zsh"
print -s "git status"
print -s "git commit -m 'test'"
print -s "git checkout -b feature"

best_query=9999.0
for i in {1..5}; do
  t0=$EPOCHREALTIME
  _ghost_history_query "git" >/dev/null 2>&1
  t1=$EPOCHREALTIME
  elapsed=$(( (t1 - t0) * 1000.0 ))
  (( elapsed < best_query )) && best_query=$elapsed
done

echo "Benchmark: history query = ${best_query}ms (ceiling: 10ms)"
(( best_query < 10.0 )) || {
  echo "FAIL: history query exceeded 10ms budget; got ${best_query}ms"
  exit 1
}

# 3. Spec 011 Hot-path purity check: zero external forks in hot-path functions
hot_path_files=(
  "$ROOT_DIR/core/ghost-core.zsh"
  "$ROOT_DIR/ui/inline.ui.zsh"
  "$ROOT_DIR/sources/history.source.zsh"
)

for file in "${hot_path_files[@]}"; do
  # Check for raw grep/sed/awk/cat calls
  if grep -E '(\bcat\b|\bgrep\b|\bsed\b|\bawk\b|\bcut\b|\btr\b)' "$file" | grep -v '^[[:space:]]*#' >/dev/null 2>&1; then
    echo "FAIL: external fork pattern detected in hot path: $file"
    exit 1
  fi
done

echo "ALL test_benchmarks PASSED"
