# AGENTS.md — ziro-ghost Repository

## 1. Primary Invariants & Engineering Rules

### MCP-First Rule
ALWAYS prefer Serena semantic MCP tools (`read_file`, `search_for_pattern`, `get_symbols_overview`, `find_symbol`) over raw terminal grep/cat commands for codebase inspection and navigation.

### EVOID IOP Architecture
- **Topology**: Gateway (`ziro` CLI / ZLE) → Intent Bus (NDJSON stdio) → Modules subscribing by intent name.
- **Namespaces**:
  - `ghost.suggest.*`: Ghost Line inline suggestions.
  - `ghost.popup.*`: Rust interactive popup overlay.
  - `ghost.cache.*`: Multi-tier cache services.
  - `ghost.strategy.*`: Strategy and pipeline composition.
- **Rule**: NO module calls another directly — strictly communicate via Intent Bus.
- **Intent Envelope**: `{id, name, level, metadata}` where level is `ephemeral` (5s), `standard` (10s), or `critical` (30s).

### Size & Performance Discipline
- Target binary size: strictly **< 2.5MB** per platform.
- Rust release profile: `opt-level = "z"`, `lto = "fat"`, `strip = "symbols"`, `panic = "abort"`, `codegen-units = 1`.
- Keystroke latency: strictly **< 3.0ms** p95 hot-path.

## 2. Directory Structure
- `crates/ghost-protocol`: Strongly-typed Rust Serde definitions for Intent and IntentResult NDJSON envelopes.
- `crates/ghost-popup`: Focus Mode interactive TUI binary (`ghost-popup`).
- `core/`: Zsh core engine and Intent Bus coordinator (`ghost-bus.zsh`, `ghost-core.zsh`).
- `sources/`: Pluggable intent handlers for suggestion sources (`history`, `typo`, `project`, `zoxide`).
- `ui/`: Terminal rendering layers (`inline.ui.zsh`, `focus.ui.zsh`).
- `.specify/`: Specifications, SDD workflow, ADRs, and implementation plans.
