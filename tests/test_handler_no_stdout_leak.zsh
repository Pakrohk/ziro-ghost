#!/usr/bin/env zsh
# Test: Contract enforcement prevents stdout leaks from source handlers
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/core/ghost-core.zsh"

# Mock noisy handler that prints directly to stdout
_mock_noisy_handler() {
  emulate -L zsh
  echo "GARBAGE_STDOUT_LINE_1"
  print -r -- "5:typo:leak"
  _ghost_results=("5:cmd:clean_result")
  return 0
}

# Mock failing handler
_mock_failing_handler() {
  emulate -L zsh
  echo "ERROR_LOG_TO_STDOUT"
  return 1
}

typeset -ga _ghost_results=()
typeset -ga _ghost_result_kinds=()

# 1. Noisy handler must not produce any stdout when invoked through _ghost_invoke_handler
local out_file
out_file="$(mktemp)"
_ghost_invoke_handler _mock_noisy_handler "test" "noisy_src" > "$out_file"
local out
out="$(<"$out_file")"
rm -f "$out_file"

[[ -z "$out" ]] || { echo "FAIL: stdout leaked from handler; got '$out'"; exit 1; }
[[ ${#_ghost_results} -eq 1 ]] || { echo "FAIL: results not preserved; count=${#_ghost_results}"; exit 1; }
[[ "${_ghost_results[1]}" == "5:cmd:clean_result" ]] || { echo "FAIL: clean result expected"; exit 1; }

# 2. Failing handler must not produce any stdout and return code 1
local rc=0
out_file="$(mktemp)"
_ghost_invoke_handler _mock_failing_handler "test" "failing_src" > "$out_file" || rc=$?
out="$(<"$out_file")"
rm -f "$out_file"

[[ -z "$out" ]] || { echo "FAIL: stdout leaked from failing handler; got '$out'"; exit 1; }
[[ $rc -ne 0 ]] || { echo "FAIL: failing handler should return non-zero"; exit 1; }

echo "ALL test_handler_no_stdout_leak PASSED"
