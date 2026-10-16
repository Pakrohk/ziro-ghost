#!/usr/bin/env zsh
# Test: Project markers detection via Python helper
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
HELPER="$ROOT_DIR/lib/project_markers.py"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# 1. detect_project identifies python project via pyproject.toml
touch "$tmp_dir/pyproject.toml"
res_py="$(python3 "$HELPER" "$tmp_dir")"
[[ "$res_py" == *"\"python\""* ]] || { echo "FAIL: python type not detected; got '$res_py'"; exit 1; }
[[ "$res_py" == *"\"pytest\""* ]] || { echo "FAIL: pytest command not in recipes"; exit 1; }
rm -f "$tmp_dir/pyproject.toml"

# 2. detect_project identifies node project via package.json
touch "$tmp_dir/package.json"
res_node="$(python3 "$HELPER" "$tmp_dir")"
[[ "$res_node" == *"\"node\""* ]] || { echo "FAIL: node type not detected; got '$res_node'"; exit 1; }
[[ "$res_node" == *"\"pnpm dev\""* ]] || { echo "FAIL: pnpm dev command missing"; exit 1; }
rm -f "$tmp_dir/package.json"

# 3. detect_project identifies rust project via Cargo.toml
touch "$tmp_dir/Cargo.toml"
res_rust="$(python3 "$HELPER" "$tmp_dir")"
[[ "$res_rust" == *"\"rust\""* ]] || { echo "FAIL: rust type not detected; got '$res_rust'"; exit 1; }
[[ "$res_rust" == *"\"cargo build\""* ]] || { echo "FAIL: cargo build missing"; exit 1; }
rm -f "$tmp_dir/Cargo.toml"

# 4. detect_project combines multiple markers (e.g. .git + pyproject.toml)
mkdir -p "$tmp_dir/.git"
touch "$tmp_dir/pyproject.toml"
res_multi="$(python3 "$HELPER" "$tmp_dir")"
[[ "$res_multi" == *"\"git\""* && "$res_multi" == *"\"python\""* ]] || { echo "FAIL: multiple markers not combined; got '$res_multi'"; exit 1; }
[[ "$res_multi" == *"\"git status\""* && "$res_multi" == *"\"uv sync\""* ]] || { echo "FAIL: multi commands missing"; exit 1; }
rm -rf "$tmp_dir/.git" "$tmp_dir/pyproject.toml"

# 5. empty directory → empty types
res_empty="$(python3 "$HELPER" "$tmp_dir")"
[[ "$res_empty" == *"\"types\": []"* ]] || { echo "FAIL: expected empty types for empty dir; got '$res_empty'"; exit 1; }

echo "ALL test_project_markers PASSED"
