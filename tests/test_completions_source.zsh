#!/usr/bin/env zsh
# Test: Completions bridge source
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/sources/completions.source.zsh"

# 1. completions source registered in IOP
sources=($(ghost_list_sources))
[[ "${sources[(r)completions]}" == "completions" ]] || { echo "FAIL: completions source not registered in IOP"; exit 1; }

meta="$(ghost_get_source completions)"
[[ "$meta" == *"weight=10"* ]] || { echo "FAIL: weight mismatch; got '$meta'"; exit 1; }
[[ "$meta" == *"kind=cmd"* ]] || { echo "FAIL: kind mismatch; got '$meta'"; exit 1; }

# 2. Handles missing compinit gracefully (returns 1 or empty)
if ! (( $+functions[compdef] )); then
  if ghost_completions_query "git checkout" >/dev/null 2>&1; then
    # if it doesn't fail, results must be empty
    [[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: expected empty when compinit missing"; exit 1; }
  fi
fi

# 3. Captures from compadd wrapper when completion func exists
autoload -Uz compinit 2>/dev/null && compinit -u 2>/dev/null || true
_mock_cli() {
  compadd -- optionA optionB optionC
}

if (( $+functions[compdef] )); then
  ghost_completions_query "mock_cli opt" >/dev/null || true
  [[ ${#_ghost_results} -ge 2 ]] || { echo "FAIL: expected captured completions; got ${_ghost_results[*]}"; exit 1; }
  sample="${_ghost_results[1]}"
  [[ "$sample" == "10:cmd:mock_cli option"* ]] || { echo "FAIL: unexpected completion format; got '$sample'"; exit 1; }
fi

# 4. No crash if command has no completion function
ghost_completions_query "non_existent_command_123456 foo" >/dev/null || true
[[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: expected empty for non-existent command"; exit 1; }

echo "ALL test_completions_source PASSED"
