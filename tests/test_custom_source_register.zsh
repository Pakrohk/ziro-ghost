#!/usr/bin/env zsh
# Test: Custom source registration & loader
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"
source "$ROOT_DIR/core/ghost-config.zsh"

tmp_dir="$(mktemp -d)"
tmp_file="$tmp_dir/source.zsh"
trap 'rm -rf "$tmp_dir"' EXIT

cat << 'EOF' > "$tmp_file"
_ghost_file_source_handler() {
  emulate -L zsh
  _ghost_results=("file-result-1")
  return 0
}
EOF

# 1. ghost_load_custom_sources registers function handler
_dummy_handler() { return 0; }
_ghost_config_custom_sources=(
  "my_func|_dummy_handler|22|cmd|1|0|custom"
)
ghost_load_custom_sources
sources=($(ghost_list_sources))
[[ "${sources[(r)my_func]}" == "my_func" ]] || { echo "FAIL: my_func not registered"; exit 1; }
meta="$(ghost_get_source my_func)"
[[ "$meta" == *"weight=22"* ]] || { echo "FAIL: weight mismatch in meta; got '$meta'"; exit 1; }

# 2. ghost_load_custom_sources sources file handler
_ghost_config_custom_sources=(
  "file_src|$tmp_file|18|cmd|1|0|custom"
)
ghost_load_custom_sources
sources=($(ghost_list_sources))
[[ "${sources[(r)file_src]}" == "file_src" ]] || { echo "FAIL: file_src not registered"; exit 1; }
meta_file="$(ghost_get_source file_src)"
[[ "$meta_file" == *"handler=_ghost_file_source_handler"* ]] || {
  echo "FAIL: file handler function not detected; got '$meta_file'"
  exit 1
}

# 3. duplicate name with internal source → warning + skip
_ghost_config_custom_sources=(
  "history|_dummy_handler|99|cmd|1|0|custom"
)
warn_out="$(ghost_load_custom_sources 2>&1)"
[[ "$warn_out" == *"warning"* && "$warn_out" == *"conflicts"* ]] || {
  echo "FAIL: expected collision warning for history; got '$warn_out'"
  exit 1
}
meta_hist="$(ghost_get_source history 2>/dev/null || true)"
[[ "$meta_hist" != *"weight=99"* ]] || { echo "FAIL: internal history source was overwritten!"; exit 1; }

# 4. enabled=false source not registered
_ghost_config_custom_sources=(
  "disabled_src|_dummy_handler|20|cmd|0|0|custom"
)
ghost_load_custom_sources
sources=($(ghost_list_sources))
[[ -z "${sources[(r)disabled_src]:-}" ]] || { echo "FAIL: disabled source was registered"; exit 1; }

# 5. fallback_only flag propagated
_ghost_config_custom_sources=(
  "fallback_src|_dummy_handler|5|typo|1|1|custom"
)
ghost_load_custom_sources
meta_fb="$(ghost_get_source fallback_src)"
[[ "$meta_fb" == *"fallback_only=1"* ]] || { echo "FAIL: fallback_only flag not set; got '$meta_fb'"; exit 1; }

echo "ALL test_custom_source_register PASSED"
