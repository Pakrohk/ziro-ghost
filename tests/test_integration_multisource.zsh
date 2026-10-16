#!/usr/bin/env zsh
# Test: Multi-source integration & ranking
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/ghost.plugin.zsh"

# 1. Multiple sources registered
sources=($(ghost_list_sources))
[[ "${sources[(r)history]}" == "history" ]] || { echo "FAIL: history source missing"; exit 1; }
[[ "${sources[(r)project]}" == "project" ]] || { echo "FAIL: project source missing"; exit 1; }
[[ "${sources[(r)subcommand]}" == "subcommand" ]] || { echo "FAIL: subcommand source missing"; exit 1; }
[[ "${sources[(r)completions]}" == "completions" ]] || { echo "FAIL: completions source missing"; exit 1; }

# 2. Weights applied to ranking
# history: 40, project: 30, subcommand: 10
items=(
  "10:cmd:git log"
  "30:project:pytest"
  "40:history:git status"
)
ghost_rank_candidates "${items[@]}" >/dev/null
[[ ${#_ghost_ranked} -eq 3 ]] || { echo "FAIL: expected 3 ranked candidates"; exit 1; }

# Top item should be git status (weight 40 + history bias 1 + length bonus 5 = 46 > project weight 30)
top="${_ghost_ranked[1]}"
[[ "$top" == *":git status" ]] || { echo "FAIL: expected git status at top; got '$top'"; exit 1; }

# 3. Project source still works alongside subcommand source
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
touch "$tmp_dir/package.json"

pushd "$tmp_dir" >/dev/null
ghost_project_query "pnpm" >/dev/null
popd >/dev/null

[[ ${#_ghost_results} -gt 0 ]] || { echo "FAIL: expected project commands for package.json"; exit 1; }
sample="${_ghost_results[1]}"
[[ "$sample" == "30:project:pnpm"* ]] || { echo "FAIL: expected '30:project:pnpm ...'; got '$sample'"; exit 1; }

# Subcommand source query for pnpm
ghost_subcommand_query "pnpm" >/dev/null
[[ ${#_ghost_results} -gt 0 ]] || { echo "FAIL: expected subcommand query for pnpm"; exit 1; }
sample_sub="${_ghost_results[1]}"
[[ "$sample_sub" == "10:cmd:pnpm "* ]] || { echo "FAIL: expected '10:cmd:pnpm ...'; got '$sample_sub'"; exit 1; }

echo "ALL test_integration_multisource PASSED"
