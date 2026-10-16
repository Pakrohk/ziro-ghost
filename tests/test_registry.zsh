#!/usr/bin/env zsh
# Test: IOP Registry
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-registry.zsh"

# 1. Register a mock source
ghost_register_source test_src \
  --intent "test source intent" \
  --handler mock_handler \
  --weight 25 \
  --kind git \
  --enabled true

sources=($(ghost_list_sources))
[[ "${sources[(r)test_src]}" == "test_src" ]] || { echo "FAIL: test_src not in list"; exit 1; }

meta="$(ghost_get_source test_src)"
[[ "$meta" == *"weight=25"* ]] || { echo "FAIL: meta weight mismatch"; exit 1; }
[[ "$meta" == *"kind=git"* ]] || { echo "FAIL: meta kind mismatch"; exit 1; }

# 2. Duplicate registration warns
err_out="$(ghost_register_source test_src --intent "dup" --handler mock2 2>&1)"
[[ "$err_out" == *"warning"* ]] || { echo "FAIL: expected duplicate warning"; exit 1; }

echo "ALL test_registry PASSED"
