#!/usr/bin/env zsh
# Test: IOP Public Registry API & Management
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
GHOST_HOME="$ROOT_DIR"
source "$ROOT_DIR/core/ghost-kinds.zsh"
source "$ROOT_DIR/core/ghost-registry.zsh"

_dummy() { return 0; }

# 1. ghost_register_source with dup warns
ghost_register_source api_test --handler _dummy --weight 10 --intent "first"
tmp_err="$(mktemp)"
ghost_register_source api_test --handler _dummy --weight 20 --intent "second" 2> "$tmp_err"
warn_msg="$(<"$tmp_err")"
rm -f "$tmp_err"
[[ "$warn_msg" == *"warning"* && "$warn_msg" == *"already registered"* ]] || {
  echo "FAIL: expected duplicate warning; got '$warn_msg'"
  exit 1
}

# 2. ghost_source_info returns metadata
info_out="$(ghost_source_info api_test)"
[[ "$info_out" == *"Source: api_test"* ]] || { echo "FAIL: missing source name in info"; exit 1; }
[[ "$info_out" == *"Weight:        20"* ]] || { echo "FAIL: weight mismatch in info; got '$info_out'"; exit 1; }

# 3. ghost_unregister_source removes source
ghost_unregister_source api_test
sources=($(ghost_list_sources))
[[ -z "${sources[(r)api_test]:-}" ]] || { echo "FAIL: api_test was not removed from sources list"; exit 1; }

# 4. ghost_custom_sources_list only returns custom
_ghost_custom_sources_registry=()
ghost_register_source builtin_mock --handler _dummy --weight 10 --intent "standard"
ghost_register_source custom_mock --handler _dummy --weight 10 --intent "custom"

customs=($(ghost_custom_sources_list))
[[ "${customs[(r)custom_mock]}" == "custom_mock" ]] || { echo "FAIL: custom_mock not in custom sources list"; exit 1; }
[[ -z "${customs[(r)builtin_mock]:-}" ]] || { echo "FAIL: builtin_mock should not be in custom sources list"; exit 1; }

echo "ALL test_public_api PASSED"
