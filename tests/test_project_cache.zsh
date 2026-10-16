#!/usr/bin/env zsh
# Test: Project markers caching & mtime invalidation
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

touch "$tmp_dir/Cargo.toml"
dir_key="${tmp_dir//\//_}"
expected_cache_file="$cache_dir/$dir_key.json"

# 1. First query creates cache file
out1="$(_ghost_project_detect "$tmp_dir")"
[[ "$out1" == *"\"rust\""* ]] || { echo "FAIL: first query failed to detect rust"; exit 1; }
[[ -f "$expected_cache_file" ]] || { echo "FAIL: cache file not created at '$expected_cache_file'"; exit 1; }

# 2. Second query reads from cache (mock cache file content to prove no python call)
print -r -- '{"types":["cached_type"],"commands":["cached_cmd"]}' > "$expected_cache_file"
# Clear in-memory cache to force reading from disk cache
typeset -gA _ghost_project_mem_cache
_ghost_project_mem_cache=()

out2="$(_ghost_project_detect "$tmp_dir")"
[[ "$out2" == *"\"cached_type\""* ]] || { echo "FAIL: second query did not read from disk cache; got '$out2'"; exit 1; }

# 3. chpwd invalidates in-memory cache
_ghost_project_mem_cache["$tmp_dir"]="stale_mem_cache"
_ghost_project_commands_cache["$tmp_dir"]="stale_cmd"
_ghost_on_chpwd
[[ -z "${_ghost_project_mem_cache[$tmp_dir]:-}" ]] || { echo "FAIL: chpwd did not clear mem cache"; exit 1; }
[[ -z "${_ghost_project_commands_cache[$tmp_dir]:-}" ]] || { echo "FAIL: chpwd did not clear commands cache"; exit 1; }

# 4. Marker mtime change invalidates cache
sleep 1
touch "$tmp_dir/Cargo.toml"  # Touch Cargo.toml so it is newer than expected_cache_file
out3="$(_ghost_project_detect "$tmp_dir")"
[[ "$out3" == *"\"rust\""* ]] || { echo "FAIL: mtime update did not refresh cache from python; got '$out3'"; exit 1; }

echo "ALL test_project_cache PASSED"
