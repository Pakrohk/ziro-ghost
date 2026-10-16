#!/usr/bin/env zsh
# Test: Standalone plugin loading
set -euo pipefail

ROOT_DIR="${0:A:h:h}"

# 1. Source plugin standalone in clean environment
zsh -f -c "
  source '$ROOT_DIR/ghost.plugin.zsh'
  [[ -n \"\$GHOST_HOME\" ]] || { echo 'FAIL: GHOST_HOME not set'; exit 1; }
  _ghost_lazy_init 2>/dev/null || true
  (( \${+functions[_ghost_boot]} )) || { echo 'FAIL: _ghost_boot missing'; exit 1; }
  (( \${+functions[ghost_kind_get]} )) || { echo 'FAIL: ghost_kind_get missing'; exit 1; }
  echo 'PASS: standalone load'
"

echo "ALL test_plugin_load PASSED"
