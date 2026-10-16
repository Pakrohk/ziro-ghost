#!/usr/bin/env zsh
# Test: Subcommand source
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/sources/subcommand.source.zsh"

# 1. subcommand source registered
sources=($(ghost_list_sources))
[[ "${sources[(r)subcommand]}" == "subcommand" ]] || { echo "FAIL: subcommand source not registered"; exit 1; }

meta="$(ghost_get_source subcommand)"
[[ "$meta" == *"weight=10"* ]] || { echo "FAIL: weight mismatch; got '$meta'"; exit 1; }
[[ "$meta" == *"kind=cmd"* ]] || { echo "FAIL: kind mismatch; got '$meta'"; exit 1; }

# 2. git returns subcommands from static table
ghost_subcommand_query "git" >/dev/null
[[ ${#_ghost_results} -ge 5 ]] || { echo "FAIL: expected git subcommands; got ${#_ghost_results}"; exit 1; }
sample="${_ghost_results[1]}"
[[ "$sample" == "10:cmd:git "* ]] || { echo "FAIL: expected '10:cmd:git ...'; got '$sample'"; exit 1; }

# Test with subcommand prefix
ghost_subcommand_query "git st" >/dev/null
[[ ${#_ghost_results} -ge 1 ]] || { echo "FAIL: expected git st matches; got ${#_ghost_results}"; exit 1; }
for item in "${_ghost_results[@]}"; do
  [[ "$item" == "10:cmd:git st"* ]] || { echo "FAIL: item '$item' does not match prefix 'st'"; exit 1; }
done

# 3. docker returns subcommands from static table
ghost_subcommand_query "docker" >/dev/null
[[ ${#_ghost_results} -ge 5 ]] || { echo "FAIL: expected docker subcommands; got ${#_ghost_results}"; exit 1; }

# 4. unknown command returns no results (not error)
ghost_subcommand_query "unknown_cmd_xyz_999" >/dev/null 2>&1 || true
[[ ${#_ghost_results} -eq 0 ]] || { echo "FAIL: expected 0 results for unknown command"; exit 1; }

# 5. Combined static + dynamic works (no duplicates)
_mock_dynamic_tool() {
  compadd -- build test extra1
}
_ghost_subcommand_table[mock_dynamic_tool]="build test"

ghost_subcommand_query "mock_dynamic_tool" >/dev/null || true
# Check that there are no duplicates
typeset -a unique_items=(${(u)_ghost_results})
[[ ${#unique_items} -eq ${#_ghost_results} ]] || { echo "FAIL: duplicate subcommands found"; exit 1; }

echo "ALL test_subcommand_source PASSED"
