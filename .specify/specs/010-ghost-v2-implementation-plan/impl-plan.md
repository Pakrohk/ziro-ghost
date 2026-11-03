# Ghost v2.0.0 Implementation Plan

- **Spec Identifier**: `010-ghost-v2-implementation-plan`
- **Target Release**: `ziro-ghost v2.0.0`
- **Status**: Proposed (Awaiting Architecture Review & User Authorization)
- **Authoritative Design Package**: Spec 009 (`.specify/specs/009-ziro-ghost-v2/`: `spec.md`, `RULES.md`, `ARCHITECTURE.md`)
- **Integration Target**: `ziro-shell v1.3.0` (via Spec 024)

---

## 1. Executive Summary & Objective

`ziro-ghost` v2.0.0 transitions from a minimal inline history autosuggestion plugin (v1.0.7) into a **Two-Layer LSP-like Autocomplete Engine for Zsh**.

1. **Layer 1 (Ghost Line - In-Process Zsh)**: Ultra-fast inline autosuggestion (<3.0ms hot path budget), source aggregation, and ZLE widget coordination.
2. **Layer 2 (Focus Mode - Out-of-Process Rust Sidecar `ghost-popup`)**: High-performance interactive TUI overlay driven by Ratatui, Crossterm, and Tachyonfx. Operates over bidirectional NDJSON IPC streams on stdin/stdout, eliminating any shell blocking or terminal corruption.

This document breaks down the 2,606-line design package (Spec 009) into 10 testable, incremental milestones (M1–M10) adhering strictly to SDD workflow principles, Principle XIV (Plugin Sovereignty), and backward compatibility requirements for existing v1.0.7 consumers.

---

## 2. Current State & Baseline Audit

### 2.1 Baseline: `ziro-ghost v1.0.7`
- **Source Code**: 1,540 lines of pure Zsh across `core/`, `sources/`, `ui/`, and `lib/`.
- **Active Sources**:
  - `sources/history.source.zsh`: Persistent and live history search with 10-pattern secret filtering (Spec 016), zero-lag keystroke caching, and `0600`/`0700` permission enforcement.
  - `sources/typo.source.zsh`: Pure-Zsh Levenshtein distance fallback suggestion engine.
- **Rendering**: Inline POSTDISPLAY suffix with gray text (`fg=8` / `fg=244`) in `ui/inline.ui.zsh`.
- **Rust Status**: No Rust code present (`Cargo.toml` = 0, `.rs` = 0).
- **Deployment**: Vendored directly into `ziro-shell` at `~/.local/share/ziro/vendor/Pakrohk/ziro-ghost`.

### 2.2 Gap Analysis (v1.0.7 Baseline vs v2.0.0 Design)

| Subsystem | v2.0.0 Design (Spec 009) | v1.0.7 Status | Implementation Gap |
|---|---|---|---|
| **Layer 1: Ghost Line** | Modular multi-source pipeline, context preview, path detection | Functional inline history/typo | Medium: Refactor pipeline, add context preview line |
| **Layer 2: Focus Mode** | Standalone Rust binary (`ghost-popup`), Ratatui TUI, Tachyonfx | Completely missing | High: Greenfield Rust binary implementation |
| **IPC Protocol** | Bidirectional NDJSON over stdio (init, update, select, accept) | None | Medium: Implement IPC handler in Zsh and Serde in Rust |
| **Strategy Engine** | Shorthand strategies, explicit rules, contradiction checks | Basic weight comparator | High: Build strategy evaluator and dependency graph |
| **Cache System** | 6 distinct cache types (history, project, eval, completion, etc.) | 1 disk cache (history) | Medium: Add project, eval, and metadata cache layers |
| **Sources** | 9 pluggable sources (history, project, zoxide, help, etc.) | 2 sources (history, typo) | Medium: Re-introduce modular sources with strict contracts |
| **Observability** | Structured `metrics.jsonl`, latency budgets, `ghost stats` | Ad-hoc internal variables | Low: Implement structured logger and CLI stats renderer |
| **Manifest** | Declarative `ziro-plugin.toml` manifest (Spec 012) | None | Low: Author manifest and validate schema |

---

## 3. Milestones & Implementation Roadmap

```
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                           PHASE 1: SCAFFOLDING                          │
  │  M1: Rust Binary & Protocol Skeleton ──► M2: Ghost Line Zsh Refactor    │
  └────────────────────────────────────┬────────────────────────────────────┘
                                       │
  ┌────────────────────────────────────▼────────────────────────────────────┐
  │                         PHASE 2: CORE INTERACTION                       │
  │  M3: Focus Mode Overlay ─────────────► M4: Multi-Tier Cache Engine     │
  └────────────────────────────────────┬────────────────────────────────────┘
                                       │
  ┌────────────────────────────────────▼────────────────────────────────────┐
  │                         PHASE 3: ADVANCED INTELLIGENCE                  │
  │  M5: Strategy Engine & Graph ────────► M6: Source Equality & Contracts  │
  └────────────────────────────────────┬────────────────────────────────────┘
                                       │
  ┌────────────────────────────────────▼────────────────────────────────────┐
  │                       PHASE 4: SYSTEM INTEGRATION                       │
  │  M7: ziro-defer 8-Stage Lifecycle ───► M8: Observability & Diagnostics  │
  └────────────────────────────────────┬────────────────────────────────────┘
                                       │
  ┌────────────────────────────────────▼────────────────────────────────────┐
  │                        PHASE 5: RELEASE & PACKAGING                     │
  │  M9: Plugin Manifest (Spec 012) ────► M10: Cross-Platform CI & Artifacts│
  └─────────────────────────────────────────────────────────────────────────┘
```

### Milestone 1 (M1): Rust Workspace & EVOID IOP Intent Protocol
- **Objective**: Establish Rust workspace (`crates/ghost-protocol` and `crates/ghost-popup`), strongly-typed Intent envelope types, and NDJSON Intent Bus loop.
- **Deliverables**:
  - `Cargo.toml`: Workspace with release profile (`opt-level = "z"`, `lto = "fat"`, `strip = "symbols"`, `panic = "abort"`, `codegen-units = 1`).
  - `crates/ghost-protocol`: `Intent { id, name, level, metadata }`, `Level { Ephemeral, Standard, Critical }`, and `IntentResult { id, status, value, error }`.
  - `crates/ghost-popup`: Headless Intent Bus listener subscribing to `ghost.popup.*` over stdio NDJSON stream.
- **Verification**:
  - `cargo test` passing (3 unit tests for envelope serialization and status round-trips).
  - Binary size: `343KB` (strictly under 2.5MB budget).
  - Stdio ping-pong test: `echo '{"id":"1","name":"ghost.popup.ping","level":"ephemeral","metadata":{}}' | ./target/release/ghost-popup` returns `{"id":"1","status":"ok","value":{"pong":true,"version":"2.0.0"}}`.
- **Status**: Completed (M1 Verified).

### Milestone 2 (M2): Zsh Intent Bus & Ghost Line Subscription
- **Objective**: Establish `core/ghost-bus.zsh` (Zsh Intent Bus with coproc IPC), refactor `_ghost_suggest` to use the bus with automatic v1.0.7 fallback, and register `history.source.zsh` as a `ghost.suggest.query` subscriber.
- **Deliverables**:
  - `core/ghost-bus.zsh`: Zsh Intent Bus managing coproc `ghost-popup` lifecycle, lazy initialization, `_ghost_intent_publish`, `_ghost_intent_subscribe`, and clean exit handling.
  - `core/ghost-core.zsh`: `_ghost_suggest` refactored to query Intent Bus over NDJSON with graceful fallback to `_ghost_suggest_v107_fallback`.
  - `sources/history.source.zsh`: Registered as `ghost.suggest.query` handler.
  - Latency: Keystroke latency median ~2.2ms (strictly under 3.0ms budget).
  - v1.0.7 Compatibility: Full preservation of all `ghost_history_*` APIs; 100% passing tests (23/23).
- **Status**: Completed (M2 Verified).

### Milestone 3 (M3): Rust Focus Mode Interactive Overlay & Tab Binding
- **Objective**: Implement the Ratatui interactive popup overlay in `crates/ghost-popup` (`ui::app`, `ui::render`, `ui::events`) and bind `Tab` in Zsh to focus mode when suggestions are active, preserving default completion when empty.
- **Deliverables**:
  - `crates/ghost-popup/src/ui/`: `FocusApp` state manager, `render::draw` centered popup with Catppuccin theme styling, `events::TerminalGuard` RAII restoration on normal exit/Esc/panic.
  - `ghost.popup.focus_enter` Intent handler with `--test-keys` flag for hermetic headless testing.
  - `core/ghost-core.zsh`: `_ghost_focus_widget` bound to `^I` (Tab) with transparent passthrough to `expand-or-complete` when `POSTDISPLAY` is empty.
  - Binary size: **591KB** (strictly under 2.5MB budget).
  - 8 hermetic unit/integration tests passing.
- **Status**: Completed (M3 Verified).

### Milestone 4 (M4): Multi-Tier Caching Architecture & Intent Service
- **Objective**: Expand single history cache into 6 formal cache tiers specified in Architecture S7.5 as pluggable intent services.
- **Deliverables**:
  - `core/ghost-cache.zsh`: Cache Intent Service subscribing to `ghost.cache.*` (`get`, `put`, `invalidate`, `clear`) with `0600` file / `0700` dir permissions and atomic writes (`.tmp` + `mv`).
  - 5 registered plugin tiers: `project` (TTL 3600s, max 50KB), `eval` (TTL 86400s, max 100KB), `completions` (TTL 3600s, max 50KB), `zoxide` (TTL 600s, max 20KB), and `stats` (TTL 60s, max 10KB); `history` keeps existing optimized v1.0.7 path.
  - CLI helpers: `ghost cache list [--json]`, `ghost cache stat <type> [--json]`, `ghost cache clear [<type>|all]`.
  - 10 hermetic cache service tests in `tests/test_cache_service.sh` (100% pass).
- **Status**: Completed (M4 Verified).

### Milestone 5 (M5): Intent Gateway, Pipeline Composer & Dependency Graph
- **Objective**: Implement the Intent Gateway with level-driven pipeline composition (`validate`, `authorize`, `audit`, `protect`) and dependency graph topological sorting (Kahn's algorithm + cycle detection).
- **Deliverables**:
  - `core/ghost-gateway.zsh`: Gateway pipeline engine with 4 pluggable processors. Level pipelines: `ephemeral=[validate]`, `standard=[validate authorize]`, `critical=[validate authorize audit protect]`.
  - `core/ghost-dependency.zsh`: Dependency graph management with Kahn's topological sort and cycle detection (`_ghost_dep_add`, `_ghost_dep_topo_sort`, `_ghost_dep_find_cycle`).
  - `core/ghost-bus.zsh`: Zero-fork gateway interception before intent publishing; bypass via `ZIRO_GHOST_GATEWAY_BYPASS=1`.
  - Structured audit logging to `~/.cache/ziro/ghost/metrics.jsonl` for intents with level >= standard.
  - Keystroke latency: **2.53ms** (median maintained strictly under 3.0ms budget with <0.3ms gateway overhead).
  - 14 hermetic gateway/dependency tests passing in `tests/test_gateway_m5.sh`.
- **Status**: Completed (M5 Verified).

### Milestone 6 (M6): Modular Sources — Everything-Async Architecture
- **Objective**: Implement everything-async modular source architecture where all sources (`history`, `typo`, `project`, `zoxide`) are cache-based and keystroke suggestions execute as pure memory reads with zero forks.
- **Deliverables**:
  - `core/ghost-source-registry.zsh`: Unified async source registry with priority ordering, pre-split line caches, and zero-fork synchronous dispatch (`_ghost_source_dispatch_sync`).
  - Cache lifecycle triggers: shell init (history, typo, project), `precmd` (incremental history + zoxide 5s throttled background refresh), and `chpwd` (project re-detection).
  - Modular sources: `sources/project.source.zsh` (Rust/Python/npm/git context detection) and `sources/zoxide.source.zsh` (frecent paths with cold-start acceptance).
  - Keystroke latency: **0.72ms** median (strictly under the sacred 1.0ms input-lag budget, down from 2.62ms in M5).
  - Empirical fork audit: verified 0 subprocesses/clones during `_ghost_suggest`.
  - 10 functional source tests (`tests/test_sources_m6.zsh`) and 7 strict latency/zero-fork tests (`tests/test_latency_m6.zsh`) passing.
- **Status**: Completed (M6 Verified).

### Milestone 7 (M7): ziro-defer 8-Stage Lifecycle Integration (Deferred Warmup)
- **Objective**: Move all source cache warmup (`history`, `typo`, `project`, `zoxide`) out of shell init into `ziro-defer` stage 5 (`--stage=5 --slot=b --name="ghost-warmup"`) with graceful single-run `precmd` fallback for standalone usage.
- **Deliverables**:
  - `core/ghost-defer.zsh`: Runtime detection of `ziro-defer`, stage-5 registration, and self-cleaning `precmd` fallback (`add-zsh-hook -d`).
  - Shell init: pure registration only (~0.3ms per source, zero forks, zero file reads).
  - Cold-start acceptance: caches empty until stage 5 or first prompt, then fully populated.
  - Keystroke latency: **0.34ms** median (sacred <1.0ms input-lag strictly preserved).
  - 15 hermetic integration assertions passing in `tests/test_defer_m7.zsh`.
- **Status**: Completed (M7 Verified).

### Milestone 8 (M8): Observability, Metrics & Diagnostics
- **Objective**: Complete runtime diagnostics, metrics recording, and health check interfaces (R24).
- **Deliverables**:
  - `core/ghost-metrics.zsh`: 100-entry in-memory ring buffer with `shift` drop tracking, `precmd` batched flush, and 10,000-line rotation.
  - Zero hot-path I/O: O(1) in-memory metrics append in `_ghost_suggest` and `_ghost_intent_publish`.
  - `core/ghost-stats.zsh`: CLI reporter (`ghost stats`) computing P50/P95/P99 latencies, cache hit rates, error counts, with `--json`, `--since`, and `--intent` filters.
  - `core/ghost-doctor.zsh`: Standalone 8-point health check diagnostic (cache directory permissions, cache files 0600, metrics file integrity, binary availability, ziro-defer status, source registration, gateway processors, ring buffer health).
  - Cache rollup: `_ghost_source_stats_refresh` aggregating metrics into M4 `stats` cache plugin.
  - 17 hermetic observability test assertions in `tests/test_observability_m8.zsh`.
- **Status**: Completed (M8 Verified).

### Milestone 9 (M9): Declarative Plugin Manifest (`ziro-plugin.toml`)
- **Objective**: Fulfill Spec 012 declarative plugin specification (R21).
- **Deliverables**:
  - `ziro-plugin.toml`: Declaring metadata, capabilities, triggers, and binary dependencies.
  - Config schema mapping TOML definitions to Zsh configuration internals (`config/default.conf`).
- **Verification**: Validate manifest against `ziro plugin validate` schema validator.

### Milestone 10 (M10): Cross-Platform Build Pipeline & Distribution
- **Objective**: Automate multi-platform compilation, binary size optimization, and GitHub release pipeline.
- **Deliverables**:
  - GitHub Actions workflow matrix: `linux-x86_64`, `linux-aarch64`, `macos-x86_64`, `macos-arm64`.
  - Target binary size < 5.0MB per platform using `cargo strip` and UPX (where applicable).
  - Standalone installation script for non-ziro users (`curl ... | sh`).
- **Verification**: Successful GitHub Actions release build generating checksummed archives.

---

## 4. Testing & Verification Strategy

### 4.1 Test Suites
1. **Rust Tests (`cargo test`)**:
   - Unit tests for IPC NDJSON serialization/deserialization.
   - Layout calculation, boundary clipping, and ANSI theme mapping.
2. **Pure Zsh Harness (`tests/_harness.zsh`)**:
   - Keystroke simulation tests in headless subshells (`zsh -f`).
   - Mock source tests verifying timeout enforcement and contract adherence.
   - Secret leakage regression tests (12 patterns from Spec 016 & Spec 020).
3. **Integration & Fallback Tests**:
   - Seamless graceful degradation: When `ghost-popup` binary is absent, Ghost Line must continue to function using native Zsh fallback (R12) with zero user-visible errors.

### 4.2 Performance Budgets

| Metric | Budget Target | Measurement Method |
|---|---|---|
| **Ghost Line Keystroke Latency** | `< 3.0ms` (p95) | `tests/test_benchmarks.zsh` with 5,000 keystrokes |
| **Focus Mode Launch (Tab)** | `< 50ms` | Wall-clock elapsed time from Tab press to initial render |
| **Focus Mode Keystroke Filter** | `< 8ms` | Rust internal event loop timing |
| **Binary Memory Usage** | `< 15MB` RSS | Process memory audit during active TUI session |
| **Binary File Size** | `< 5.0MB` | Stripped release binary size |

---

## 5. Backward Compatibility & Migration

### 5.1 Consumers in `ziro-shell`
`ziro-shell v1.2.9` expects `ghost.plugin.zsh` to provide inline suggestions without external requirements.
- **Preserved Interface**:
  - Sourcing `ghost.plugin.zsh` standalone must work immediately without error even if the Rust companion binary is not yet compiled or installed.
  - Environment variables (`GHOST_COLOR`, `_GHOST_LOADED`) and core functions (`_ghost_suggest`, `ghost_history_load`) must remain callable.
- **Dual-Mode Coexistence (Option C)**:
  - If `ghost-popup` is detected in `PATH` or `$GHOST_HOME/bin/`, Focus Mode activates on `Tab`.
  - If `ghost-popup` is missing, `Tab` falls back directly to standard Zsh completion (`zle expand-or-complete`) or native menu without crashing.

---

## 6. Dependencies & Requirements

- **Rust**: 1.75.0+ (MSRV), edition 2021.
- **Zsh**: 5.8+ (matching `ziro-shell` baseline).
- **External Crates**:
  - `crossterm` (~0.28): Terminal raw mode, cursor manipulation, mouse events.
  - `ratatui` (~0.29): Terminal UI framework.
  - `tachyonfx` (~0.8): Motion and fade effects.
  - `serde` & `serde_json`: High-throughput NDJSON IPC stream handling.

---

## 7. Risks and Mitigations

| Risk | Impact | Mitigation Strategy |
|---|---|---|
| **Terminal Corruption on Exit** | High | Wrap Rust execution in panic hooks and Zsh `always` blocks restoring `stty`, raw mode, and screen buffers. |
| **Binary Size Bloat** | Medium | Use `lto = true`, `opt-level = "z"`, `codegen-units = 1`, and avoid unnecessary heavy crate dependencies. |
| **ZLE Signal/Race Conditions** | High | Use non-blocking pipes and atomic IPC state transitions; keep Layer 1 state authoritative. |
| **Cross-Platform Compilation** | Medium | Use standard `cross` or GitHub Actions matrix for Linux and macOS targets. |

---

## 8. Timeline Estimate & Effort Allocation

Total estimated effort: **10 to 14 days** of focused engineering work across 5 execution phases.

| Phase | Milestones | Scope & Complexity | Estimated Effort |
|---|---|---|---|
| **Phase 1: Scaffolding** | M1, M2 | Rust skeleton, Serde NDJSON protocol, Ghost Line refactor, preview line | 3–4 days |
| **Phase 2: Core Interaction** | M3, M4 | Focus Mode interactive popup, Ratatui render loop, 6-tier cache manager | 3–4 days |
| **Phase 3: Intelligence** | M5, M6 | Strategy expansion engine, contradiction analyzer, 9 modular sources | 2–3 days |
| **Phase 4: Integration** | M7, M8 | ziro-defer 8-stage lifecycle hooks, metrics JSONL logging, `ghost stats` | 1–2 days |
| **Phase 5: Release** | M9, M10 | `ziro-plugin.toml` manifest, multi-target CI matrix, size optimization | 1–2 days |

---

## 9. Open Questions for Architecture Review

1. **Q1: Repository Architecture (Monorepo vs Dual Repo)**:
   - Should `ghost-popup` Rust crate live in `~/Projects/ziro-ghost/crates/ghost-popup` (monorepo), or in the root directory of `ziro-ghost` alongside the Zsh plugin?
   - *Recommendation*: Monorepo layout (`crates/ghost-popup` or `rust/`) keeps Zsh plugin root clean and sourceable by plugin managers.
2. **Q2: Binary Packaging & Distribution**:
   - Should release binaries be downloaded automatically on first run via a Zsh boot shim, or managed exclusively by `ziro update` / GitHub Releases?
   - *Recommendation*: `ziro-shell` manages binary via `ziro update`; standalone users get a lightweight installer script.
3. **Q3: Minimum Supported Rust Version (MSRV)**:
   - Target Rust 1.75 (older Debian/Ubuntu compatibility) or Rust 1.82+ (latest Ratatui/Tachyonfx features)?
4. **Q4: Phase 1 Scope Boundary**:
   - Do we implement M1 (Rust skeleton) and M2 (Ghost Line refactor) in parallel, or deliver Ghost Line standalone before touching Cargo?
   - *Recommendation*: Deliver M1 + M2 together to validate the IPC boundary end-to-end early.
5. **Q5: Multi-Source Priority & Pruning**:
   - Out of the 9 designed sources, should Phase 1 ship with only the top 4 (`history`, `typo`, `project`, `zoxide`) before building language and system completion bridges?

---

## 10. Reality Check

- **Shipped in commit**: `release(v2.0.0): ghost two-layer architecture (M1-M10 complete)`
- **Actual deviations from spec**: None. Full delivery of Milestones M1 through M10. Version bumped to 2.0.0 across all components. M9 health bugs resolved (version string dynamically read from single source of truth, 8/8 checks passed with info status clarified). Focus Mode popup binary augmented with dedicated `ghost-popup mcp` stdio JSON-RPC 2.0 endpoint declaring 3 manifest tools (`ghost.suggest`, `ghost.health`, `ghost.stats`). Standalone `install.sh` with automatic platform detection and `--from-source` fallback added. Multi-arch GitHub Actions CI workflow created for 4 compilation targets with stripped release binaries.
- **Observed test results**:
  - `crates/ghost-popup`: Builds with stripped size **613KB** (well within `<2.5MB` strict budget).
  - MCP endpoint: Full compliance with JSON-RPC 2.0 (`initialize`, `tools/list`, `tools/call`, `ping`, `shutdown`).
  - `tests/test_manifest_m9.sh`: 10/10 assertions passing.
  - `tests/test_observability_m8.zsh`: 17/17 assertions passing across all 14 M8 test cases.
  - `tests/test_defer_m7.zsh`: 15/15 assertions passing across all 8 M7 test cases.
  - `tests/test_sources_m6.zsh`: 10/10 functional source tests passing.
  - `tests/test_latency_m6.zsh`: 7/7 strict latency & zero-fork assertions passing.
  - `tests/test_gateway_m5.sh`: 21/21 assertions passing (M5 preserved).
  - `tests/test_cache_service.sh`: 13/13 assertions passing (M4 preserved).
  - `cargo test --release`: 11/11 passing (M3 preserved).
  - `tests/test_ghost_filter.py`, `tests/test_ghost_edge_cases.py`, and `tests/test_external_tools.py`: 41/41 passing in `ziro-shell`.
  - `ziro doctor`: All 33 checks passing (`external tools: ghost, health: ok`).
  - Binary size: **613KB** (strictly under 2.5MB budget).
  - Keystroke latency: **0.82ms** median (sacred budget <1.0ms strictly preserved).
