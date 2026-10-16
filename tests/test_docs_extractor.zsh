#!/usr/bin/env zsh
# Test: Python Docs Extractor (tldr/man/--help + cache + TTL)
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
EXTRACTOR="$ROOT_DIR/lib/docs_extractor.py"

# Use isolated temp cache directory
tmp_cache_dir="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp_cache_dir"
trap 'rm -rf "$tmp_cache_dir"' EXIT

cache_docs_dir="$tmp_cache_dir/ziro/ghost/docs"

# 1. First call: cold extract and cache written
out1="$(python3 "$EXTRACTOR" --ttl 86400 ls)"
[[ -n "$out1" ]] || { echo "FAIL: expected non-empty output for ls"; exit 1; }
[[ -d "$cache_docs_dir" ]] || { echo "FAIL: cache directory not created"; exit 1; }
cache_file="$cache_docs_dir/ls.txt"
[[ -f "$cache_file" ]] || { echo "FAIL: expected cache file $cache_file"; exit 1; }
cached_content="$(<"$cache_file")"
[[ "$cached_content" == "$out1" ]] || { echo "FAIL: cached content does not match first output"; exit 1; }

# 2. Second call: cache hit
# Overwrite cache with a sentinel marker to verify it reads from cache
echo "SENTINEL_CACHE_HIT" > "$cache_file"
out2="$(python3 "$EXTRACTOR" --ttl 86400 ls)"
[[ "$out2" == *"SENTINEL_CACHE_HIT"* ]] || {
  echo "FAIL: expected cache hit returning sentinel; got '$out2'"
  exit 1
}

# 3. TTL expiry triggers re-extract
# Pass --ttl 1 and backdate the cache file mtime by 5 seconds
touch -d "10 seconds ago" "$cache_file" 2>/dev/null || touch -t 202001010000 "$cache_file"
out3="$(python3 "$EXTRACTOR" --ttl 1 ls)"
[[ "$out3" != *"SENTINEL_CACHE_HIT"* ]] || {
  echo "FAIL: expired cache was still returned; got '$out3'"
  exit 1
}
[[ "$out3" == *"ls"* || "$out3" == *"directory"* || "$out3" == *"OPTION"* ]] || {
  echo "FAIL: re-extracted docs missing expected text; got '$out3'"
  exit 1
}

# 4. Non-existent command returns graceful message
out_missing="$(python3 "$EXTRACTOR" nonexistent_test_binary_xyz_123)"
[[ "$out_missing" == *"No documentation found for"* ]] || {
  echo "FAIL: expected graceful missing message; got '$out_missing'"
  exit 1
}

echo "ALL test_docs_extractor PASSED"
