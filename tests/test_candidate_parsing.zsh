#!/usr/bin/env zsh
# Test: Centralized candidate parsing helper (_ghost_parse_candidate)
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
source "$ROOT_DIR/core/ghost-core.zsh"

# Case 1: Standard candidate
_ghost_parse_candidate "5:typo:ls"
[[ "$_ghost_candidate_weight" == "5" ]] || { echo "FAIL: weight mismatch; got $_ghost_candidate_weight"; exit 1; }
[[ "$_ghost_candidate_kind" == "typo" ]] || { echo "FAIL: kind mismatch; got $_ghost_candidate_kind"; exit 1; }
[[ "$_ghost_candidate_text" == "ls" ]] || { echo "FAIL: text mismatch; got $_ghost_candidate_text"; exit 1; }

# Case 2: Candidate with spaces
_ghost_parse_candidate "40:history:git push origin main"
[[ "$_ghost_candidate_weight" == "40" ]] || { echo "FAIL: weight mismatch"; exit 1; }
[[ "$_ghost_candidate_kind" == "history" ]] || { echo "FAIL: kind mismatch"; exit 1; }
[[ "$_ghost_candidate_text" == "git push origin main" ]] || { echo "FAIL: text mismatch"; exit 1; }

# Case 3: Text containing colons
_ghost_parse_candidate "10:cmd:http://example.com:8080/path"
[[ "$_ghost_candidate_weight" == "10" ]] || { echo "FAIL: weight mismatch"; exit 1; }
[[ "$_ghost_candidate_kind" == "cmd" ]] || { echo "FAIL: kind mismatch"; exit 1; }
[[ "$_ghost_candidate_text" == "http://example.com:8080/path" ]] || { echo "FAIL: colon in text truncated; got $_ghost_candidate_text"; exit 1; }

# Case 4: Bare text without weight:kind prefix
_ghost_parse_candidate "echo hello"
[[ "$_ghost_candidate_weight" == "10" ]] || { echo "FAIL: bare weight default"; exit 1; }
[[ "$_ghost_candidate_kind" == "cmd" ]] || { echo "FAIL: bare kind default"; exit 1; }
[[ "$_ghost_candidate_text" == "echo hello" ]] || { echo "FAIL: bare text mismatch"; exit 1; }

# Case 5: Empty candidate
_ghost_parse_candidate ""
[[ -z "$_ghost_candidate_weight" ]] || { echo "FAIL: empty weight"; exit 1; }
[[ -z "$_ghost_candidate_kind" ]] || { echo "FAIL: empty kind"; exit 1; }
[[ -z "$_ghost_candidate_text" ]] || { echo "FAIL: empty text"; exit 1; }

echo "ALL test_candidate_parsing PASSED"
