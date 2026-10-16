#!/usr/bin/env zsh
# Test: Project suggestion source & IOP integration
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/core/ghost-core.zsh"
source "$ROOT_DIR/sources/project.source.zsh"

tmp_dir="$(mktemp -d)"
cache_dir="$(mktemp -d)"
_ghost_project_cache_dir="$cache_dir"
trap 'rm -rf "$tmp_dir" "$cache_dir"' EXIT

touch "$tmp_dir/pyproject.toml"

# 1. Project source registered in IOP registry
sources=($(ghost_list_sources))
[[ "${sources[(r)project]}" == "project" ]] || { echo "FAIL: project source not in registry"; exit 1; }

meta="$(ghost_get_source project)"
[[ "$meta" == *"kind=project"* ]] || { echo "FAIL: kind mismatch in meta"; exit 1; }
[[ "$meta" == *"weight=30"* ]] || { echo "FAIL: weight mismatch in meta"; exit 1; }

# 2. ghost_project_query returns matching commands
pushd "$tmp_dir" >/dev/null
ghost_project_query "" >/dev/null
popd >/dev/null

[[ ${#_ghost_results} -gt 0 ]] || { echo "FAIL: expected project commands for pyproject.toml"; exit 1; }
# Output format: 30:project:cmd
sample="${_ghost_results[1]}"
[[ "$sample" == "30:project:"* ]] || { echo "FAIL: invalid result format; got '$sample'"; exit 1; }

# 3. Query filters by prefix
pushd "$tmp_dir" >/dev/null
ghost_project_query "py" >/dev/null
popd >/dev/null

[[ ${#_ghost_results} -gt 0 ]] || { echo "FAIL: expected matching prefix 'py'"; exit 1; }
for res in "${_ghost_results[@]}"; do
  cmd="${res#*:project:}"
  [[ "$cmd" == py* ]] || { echo "FAIL: result '$cmd' does not match prefix 'py'"; exit 1; }
done

echo "ALL test_project_source PASSED"
