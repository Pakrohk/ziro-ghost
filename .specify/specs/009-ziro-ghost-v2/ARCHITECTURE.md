# Architecture Specification: Ziro Ghost — LSP-like Autocomplete for Zsh

**Architecture ID**: `009-ARCHITECTURE`  
**Version**: 1.0.0  
**Parent Spec**: `Spec 009 (v2.0.0)` — `.specify/specs/009-ziro-ghost-plugin/spec.md`  
**Engineering Rules**: `009-RULES` — `.specify/specs/009-ziro-ghost-plugin/RULES.md`  
**Created**: 2026-10-17  
**Status**: Active / Approved Architecture  
**Target Release**: `ziro-ghost` v2.0.0 (standalone) ➔ `ziro-shell` v1.2.0 (integration)  

---

## 1. Architecture Overview

### 1.1 Scope and Intent

This architectural blueprint specifies the complete technical implementation of `ziro-ghost` v2.0.0. It defines the concrete module boundaries, data pipelines, memory layouts, inter-process communication protocols, and execution lifecycles required to build a high-performance, LSP-like autocompletion ecosystem for Zsh.

The system bifurcates responsibilities between two tightly coordinated layers:
1. **Layer 1 (Zsh In-Process)**: Manages real-time keystroke interception, in-memory source evaluation, candidate ranking, inline suggestion rendering via `POSTDISPLAY`, and the single-line context preview bar. Operates with zero forks and a strict `< 3.0ms` latency ceiling.
2. **Layer 2 (Rust Per-Shell Sidecar)**: A lightweight companion binary (`ghost-popup`) spawned on the first `Tab` press and kept alive for the shell session. Receives NDJSON updates from Zsh on every buffer change; streams selection events back. Built with `ratatui` and `tachyonfx`, it delivers rich terminal graphics, micro-animations, partial differential cell redrawing, mouse interactivity, and theme awareness without ever invoking terminal alternate screen modes (`smcup`/`rmcup`). NOT a global daemon; exits with the shell.

### 1.2 System Topology Map

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                USER TERMINAL SESSION                                    │
│                                                                                        │
│  ┌──────────────────────────────────────────────────────────────────────────────┐     │
│  │  LAYER 1: ZSH ENGINE (Interactive Shell Process)                             │     │
│  │                                                                              │     │
│  │   ┌────────────────────┐          ┌────────────────────┐                    │     │
│  │   │     ZLE Editor     │◄────────►│     Ghost Core     │                    │     │
│  │   │  (line-pre-redraw) │          │  (orchestrator)    │                    │     │
│  │   └────────────────────┘          └─────────┬──────────┘                    │     │
│  │                                             │                                │     │
│  │                                             ▼                                │     │
│  │                                   ┌────────────────────┐                     │     │
│  │                                   │  Source Registry   │                     │     │
│  │                                   └─────────┬──────────┘                     │     │
│  │                                             │                                │     │
│  │                 ┌───────────────────────────┼───────────────────────────┐    │     │
│  │                 ▼                           ▼                           ▼    │     │
│  │        ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐ │
│  │        │ history.source  │         │ project.source  │         │ zoxide.source   │ │
│  │        └─────────────────┘         └─────────────────┘         └─────────────────┘ │
│  │        ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐ │
│  │        │ lang_help.source│         │ sys_comment.src │         │ typo.source     │ │
│  │        └─────────────────┘         └─────────────────┘         └─────────────────┘ │
│  │                                             │                                │     │
│  │                                             ▼                                │     │
│  │                                   ┌────────────────────┐                     │     │
│  │                                   │  Strategy Engine   │                     │     │
│  │                                   │ (conditions/status)│                     │     │
│  │                                   └─────────┬──────────┘                     │     │
│  │                                             │                                │     │
│  │                                             ▼                                │     │
│  │                                   ┌────────────────────┐                     │     │
│  │                                   │  Comparator/Ranker │                     │     │
│  │                                   └─────────┬──────────┘                     │     │
│  │                                             │                                │     │
│  │                 ┌───────────────────────────┴───────────────────────────┐    │     │
│  │                 ▼                                                       ▼    │     │
│  │        ┌─────────────────┐                                     ┌─────────────────┐ │
│  │        │ Inline Renderer │                                     │   Preview Bar   │ │
│  │        │  (POSTDISPLAY)  │                                     │    (zle -M)     │ │
│  │        └─────────────────┘                                     └─────────────────┘ │
│  │                                                                              │     │
│  │                 ┌───────────────────────────────────────────────────────┐    │     │
│  │                 │ Interactive Trigger Widget (ghost-focus on Tab)       │    │     │
│  │                 └───────────────────────────┬───────────────────────────┘    │     │
│  └─────────────────────────────────────────────┼────────────────────────────────┘     │
│                                                │                                      │
│                                                │ First-tab spawn · then sidecar       │
│                                                │ IPC: NDJSON (bidirectional)          │
│                                                │ Lifetime: per-shell session          │
│                                                ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐     │
│  │  LAYER 2: RUST COMPANION OVERLAY (ghost-popup binary)                        │     │
│  │                                                                              │     │
│  │   ┌────────────────────┐          ┌────────────────────┐                    │     │
│  │   │  JSON Stdin Parser │─────────►│  Geometry / Layout │                    │     │
│  │   │   (serde_json)     │          │   (ratatui Area)   │                    │     │
│  │   └────────────────────┘          └─────────┬──────────┘                    │     │
│  │                                             │                                │     │
│  │                                             ▼                                │     │
│  │                                   ┌────────────────────┐                     │     │
│  │                                   │ Micro-FX Animation │                     │     │
│  │                                   │   (tachyonfx)      │                     │     │
│  │                                   └─────────┬──────────┘                     │     │
│  │                                             │                                │     │
│  │                 ┌───────────────────────────┴───────────────────────────┐    │     │
│  │                 ▼                                                       ▼    │     │
│  │        ┌─────────────────┐                                     ┌─────────────────┐ │
│  │        │ Differential    │                                     │  Input Router   │ │
│  │        │ Cell Diffing    │                                     │ (crossterm      │ │
│  │        │ (partial draw)  │                                     │  keys + mouse)  │ │
│  │        └────────┬────────┘                                     └────────┬────────┘ │
│  │                 │                                                       │          │
│  │                 └───────────────────────────┬───────────────────────────┘          │
│  │                                             ▼                                      │
│  │                                   ┌────────────────────┐                           │
│  │                                   │ Selection Response │                           │
│  │                                   │ (JSON to stdout)   │                           │
│  │                                   └─────────┬──────────┘                           │
│  └─────────────────────────────────────────────┼──────────────────────────────────────┘     │
│                                                │                                      │
│                                                ▼                                      │
│                                    Selected candidate text                            │
│                                    replaces ZLE BUFFER                                │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Repository Structure

The physical file layout of `ziro-ghost` adheres to the frozen directory structure established in Rule 1 (R1.1).

```
ziro-ghost/
├── ghost.plugin.zsh              # Lightweight entry point (<30 lines, Stage 0 boot)
├── ziro-plugin.toml              # Sovereign plugin manifest (Spec 012 compliant)
├── README.md                     # Public documentation and quick-start guide
├── CHANGELOG.md                  # Strict Keep-a-Changelog release log
├── LICENSE                       # MIT License
├── .gitignore                    # Git ignore file (build artifacts, caches, logs)
│
├── .github/                      # CI/CD and automation pipelines
│   └── workflows/
│       ├── test.yml              # Multi-OS test matrix (Zsh 5.8, 5.9 on Linux & macOS)
│       ├── bench.yml             # Hot-path latency gate & min-of-11 benchmarks
│       └── release.yml           # Cross-platform compilation & GitHub release packaging
│
├── core/                         # Core Zsh management and orchestration modules
│   ├── ghost-version.zsh         # Single source of truth for version definitions
│   ├── ghost-config.zsh          # TOML configuration parser, validator, and defaults cache
│   ├── ghost-kinds.zsh           # Semantic kinds registry (badges, icons, fallback glyphs)
│   ├── ghost-registry.zsh        # Source registration API and metadata data structures
│   ├── ghost-core.zsh            # Main ZLE event interception, staging, and widget dispatch
│   ├── ghost-strategy.zsh        # Strategy engine (conditional execution, status tracker)
│   └── ghost-cache.zsh           # High-speed in-memory LRU query cache with hook invalidation
│
├── sources/                      # Standard built-in candidate suggestion sources
│   ├── history.source.zsh        # Shell history source with frecency weighting
│   ├── project.source.zsh        # Contextual project marker commands (git, npm, cargo, etc.)
│   ├── zoxide.source.zsh         # Directory navigation suggestions from zoxide database
│   ├── lang_help.source.zsh      # Built-in command flags and keyword documentation hints
│   ├── sys_comment.source.zsh    # System package and service management suggestions
│   ├── folder.source.zsh         # Local filesystem path and folder auto-completion
│   ├── typo.source.zsh           # Bounded Levenshtein typo repair suggestions (fallback)
│   ├── completions.source.zsh    # Bridge to zsh-completions definitions
│   └── subcommand.source.zsh     # Static CLI tables + dynamic subcommand extraction
│
├── engine/                       # Matching, ranking, and post-processing engines
│   ├── ghost-matcher.zsh         # Pure Zsh prefix matching and subsequence fuzzy algorithms
│   ├── ghost-comparator.zsh      # Multi-factor ranking engine (weight, length, exactness)
│   └── ghost-filter.zsh          # Candidate deduplication, sanitization, and truncation
│
├── ui/                           # User interface presentation components (Layer 1)
│   ├── ghost-inline.ui.zsh       # POSTDISPLAY suffix injection and region_highlight styling
│   ├── ghost-preview.ui.zsh      # Non-destructive context preview bar using zle -M
│   ├── ghost-popup-native.ui.zsh # Pure Zsh fallback popup menu (box-drawing characters)
│   └── ghost-focus.ui.zsh        # Focus Mode process spawner, pipe bridge, and buffer sync
│
├── lib/                          # Reusable libraries, utilities, and external bridges
│   ├── ghost-logging.zsh         # High-speed structured JSONL error logger with rotation
│   ├── ghost-stats.zsh           # Runtime performance telemetry and source statistics
│   ├── ghost-color.zsh           # Terminal color capability detection (TrueColor/256/ANSI)
│   └── project_markers.py        # Optional cold-path Python helper for project analysis
│
├── bin/                          # Standalone binary packages
│   └── ghost-popup/              # Rust Focus Mode companion crate
│       ├── Cargo.toml            # Exact pinned dependency manifest
│       ├── Cargo.lock            # Deterministic build lockfile
│       ├── src/
│       │   ├── main.rs           # Process bootstrap, CLI parsing, and exit coordination
│       │   ├── protocol.rs       # Serde data transfer models for stdin/stdout JSON
│       │   ├── layout.rs         # Terminal geometry, floating window placement, and sizing
│       │   ├── render.rs         # Ratatui widget assembly, borders, item lists, and docs
│       │   ├── effects.rs        # TachyonFX animation routines and transition timers
│       │   ├── input.rs          # Crossterm keyboard navigation and ANSI mouse event engine
│       │   ├── diff.rs           # Differential double-buffered cell diffing engine
│       │   ├── theme.rs          # TOML theme loader, terminal palette sampler, and styling
│       │   └── errors.rs         # Custom error types and panic-free fallback handlers
│       └── tests/
│           ├── integration.rs    # End-to-end headless CLI integration assertions
│           └── fixtures/         # Standard JSON request samples for automated testing
│
├── config/                       # Factory configurations and schemas
│   ├── default.conf              # Shipped baseline default configuration in TOML format
│   └── schema.toml               # Structural schema used for configuration validation
│
├── themes/                       # Shipped theme presets (100% declarative TOML)
│   ├── catppuccin-mocha.toml
│   ├── catppuccin-latte.toml
│   ├── tokyo-night.toml
│   ├── gruvbox.toml
│   ├── dracula.toml
│   ├── nord.toml
│   ├── solarized-dark.toml
│   ├── solarized-light.toml
│   └── terminal.toml             # Auto-detected terminal palette mapping
│
├── tests/                        # Comprehensive automated test suites
│   ├── _harness.zsh              # Pure Zsh test assertion and reporting harness
│   ├── test_plugin_load.zsh      # Standalone sourcing and environment isolation tests
│   ├── test_source_history.zsh   # History source query and frecency scoring tests
│   ├── test_source_project.zsh   # Project marker detection and candidate tests
│   ├── test_source_zoxide.zsh    # Zoxide database integration tests
│   ├── test_source_typo.zsh      # Levenshtein and Damerau transposition tests
│   ├── test_source_completions.zsh
│   ├── test_source_subcommand.zsh
│   ├── test_focus_cycle.zsh      # Tab cycle, typing accept, Esc cancel
│   ├── test_path_context.zsh     # D7 source reorder tests
├── test_sidecar_lifecycle.zsh # D5 persistent process tests
├── test_registry.zsh         # Unified 7-layer source registration API tests
├── test_strategy.zsh         # Strategy engine and condition evaluation tests
├── test_config.zsh           # TOML config parsing, fallback, and precedence tests
├── test_inline.zsh           # POSTDISPLAY and region_highlight offset tests
├── test_preview.zsh          # Preview message formatting and clearing tests
├── test_focus.zsh            # Focus mode bridge and JSON serialization tests
├── test_fallback.zsh         # Graceful fallback degradation tests
├── test_hotpath.zsh          # Zero-fork static check and keystroke latency benchmarks
├── test_colors.zsh           # Color auto-detection and RGB mapping tests
├── test_themes.zsh           # Preset loading and validation tests
└── test_sovereignty.zsh      # zsh -f clean-room isolation test suite
│
└── docs/                         # Developer and user technical documentation
    ├── ARCHITECTURE.md           # This document (system design and module specifications)
    ├── CONFIG.md                 # Complete configuration key reference guide
    ├── SOURCES.md                # Source creation tutorial and 7-layer API guide
    ├── THEMES.md                 # Theme creation and styling documentation
    ├── CLI.md                    # Ghost-popup companion binary CLI and benchmarking guide
    ├── MIGRATION.md              # Detailed upgrade and migration guide from v1.0.x
    ├── TROUBLESHOOTING.md        # Diagnostic manual for performance and rendering issues
    └── CONTRIBUTING.md           # Guidelines for code style, PRs, and test requirements
```

---

## 3. Zsh Module Breakdown (Layer 1)

Every `.zsh` module enforces `emulate -L zsh` and adheres strictly to its assigned single responsibility.

### 3.1 `ghost.plugin.zsh`
- **Responsibility**: Single entry point for all plugin managers (`source`, `znap`, `zinit`, `antigen`).
- **Execution Stage**: Stage 0 (Startup Bootstrap).
- **Latency Ceiling**: `< 0.5ms`.
- **Implementation Strategy**:
  - Checks if `$GHOST_HOME` is already bound to guarantee idempotency.
  - Resolves `$GHOST_HOME` dynamically from `${${(%):-%x}:A:h}`.
  - Registers a temporary ZLE wrapper `_ghost_lazy_init` on hook `line-pre-redraw`.
  - Exits immediately without sourcing any auxiliary files or running subprocesses.
- **Rules Implemented**: R1.1, R3.1, R10.1, R14.1.

### 3.2 `core/ghost-version.zsh`
- **Responsibility**: Declares the single source of truth for the active release version and compatibility constraints.
- **Exported Globals**:
  - `typeset -g GHOST_VERSION="2.0.0"`
  - `typeset -g GHOST_NAME="ziro-ghost"`
  - `typeset -g GHOST_COMPAT_ZIRO=">=1.2.0"`
  - `typeset -g GHOST_COMPAT_ZSH=">=5.8"`
- **Rules Implemented**: R2.6, R14.7, R15.1.

### 3.3 `core/ghost-config.zsh`
- **Responsibility**: Parses declarative TOML configuration files into flattened in-memory associative arrays, verifies schema compliance, detects contradictory conditions, and resolves defaults.
- **Key Functions**:
  - `_ghost_config_load()`: Discovers and parses `~/.config/ziro/ghost.conf`, falling back to `$GHOST_HOME/config/default.conf` and built-in defaults.
  - `_ghost_config_get(key, [default])`: High-speed string lookup returning value or fallback.
  - `_ghost_config_get_bool(key, [default])`: Coerces string values (`"true"`, `"false"`, `"1"`, `"0"`) to boolean exit status (0 or 1).
  - `_ghost_config_validate()`: Verifies enum values, numeric boundaries, and data types.
  - `_ghost_config_warn_contradictions()`: Runs static analysis over registered sources to identify impossible strategy constraints.
- **Data Model**:
  ```zsh
  typeset -gA _ghost_config=(
    [ghost.line.enabled]="true"
    [ghost.line.color]="auto"
    [ghost.preview.enabled]="true"
    [ghost.focus.enter_key]="^I"
    [ghost.focus.max_items]="10"
    [behavior.debounce_ms]="0"
    [behavior.max_suggestions_total]="50"
    [behavior.timeout_total_ms]="200"
  )
  ```
- **Rules Implemented**: R5.1–R5.6, R7.3, R13.1–R13.5.

### 3.4 `core/ghost-kinds.zsh`
- **Responsibility**: Manages the semantic category registry, mapping kind identifiers (`git`, `cmd`, `path`, etc.) to Nerd Font glyphs, ASCII fallbacks, display badges, and palette colors.
- **Key Functions**:
  - `ghost_kind_register(name, icon, ascii_icon, badge, color)`: Adds or overrides a semantic kind.
  - `ghost_kind_get_icon(name)`: Returns the appropriate Nerd Font glyph or ASCII symbol based on terminal capability.
  - `ghost_kind_get_color(name)`: Retrieves the associated palette color token.
- **Baseline Data Model**:
  ```zsh
  typeset -gA _ghost_kinds=(
    [git]="󰊢|git|git|green"
    [cmd]="|$|cmd|blue"
    [path]="|/|path|yellow"
    [dir]="|d|dir|cyan"
    [file]="󰈔|f|file|white"
    [hist]="󰋚|h|hist|gray"
    [project]="◉|P|proj|peach"
    [typo]="󰁨|!|typo|red"
    [alias]="󰌷|@|alias|mauve"
  )
  ```
- **Rules Implemented**: R2.4, R4.8, R6.3.

### 3.5 `core/ghost-registry.zsh`
- **Responsibility**: Houses the unified 7-layer source registration API, maintaining metadata matrices and ensuring absolute equality between internal and user-defined sources.
- **Key Functions**:
  - `ghost_register_source(name, options...)`: The single authoritative API entry point for declaring a candidate source.
  - `ghost_unregister_source(name)`: Safely disables and removes a source definition.
  - `ghost_list_sources()`: Returns sorted list of all registered source names.
  - `ghost_source_is_enabled(name)`: Evaluates user configuration and returns boolean status.
- **Registry Data Model**:
  ```zsh
  typeset -gA _ghost_sources_handler=()
  typeset -gA _ghost_sources_weight=()
  typeset -gA _ghost_sources_kind=()
  typeset -gA _ghost_sources_max_suggestions=()
  typeset -gA _ghost_sources_timeout_ms=()
  typeset -gA _ghost_sources_strategy=()
  typeset -gA _ghost_sources_strategy_target=()
  typeset -gA _ghost_sources_requires_present=()
  typeset -gA _ghost_sources_requires_absent=()
  typeset -gA _ghost_sources_requires_success=()
  typeset -gA _ghost_sources_requires_failed=()
  typeset -gA _ghost_sources_label_type=()
  typeset -gA _ghost_sources_label_position=()
  typeset -gA _ghost_sources_label_text=()
  typeset -gA _ghost_sources_label_icon=()
  typeset -gA _ghost_sources_color_mode=()
  typeset -gA _ghost_sources_docs_enabled=()
  ```
- **Rules Implemented**: R4.8, R6.1–R6.5.

### 3.6 `core/ghost-strategy.zsh`
- **Responsibility**: Evaluates conditional execution constraints, resolves shorthand strategies (`fallback`, `alternative`, `recovery`, `dependent`), and tracks runtime source execution status.
- **Key Functions**:
  - `_ghost_strategy_should_run(name, query)`: Evaluates whether a source satisfies its precondition rules against the current query state.
  - `_ghost_strategy_record_status(name, status)`: Updates `_ghost_source_status[name]` with one of `success`, `empty`, `timeout`, `crash`, `skipped`, or `disabled`.
  - `_ghost_strategy_expand_shorthand(name)`: Compiles high-level strategies into explicit condition lists.
  - `_ghost_strategy_reset_cycle()`: Resets per-keystroke execution states before starting a new compute pass.
- **Rules Implemented**: R7.1–R7.6, R12.1.

### 3.7 `core/ghost-core.zsh`
- **Responsibility**: Top-level orchestrator. Intercepts ZLE events, stages lazy loading, invokes query evaluation, and coordinates presentation between inline and preview widgets.
- **Key Functions**:
  - `_ghost_lazy_init()`: Stage 1 bootstrap handler. **Standalone mode:** fires on first keystroke via `line-pre-redraw`. **Defer-integrated mode:** Defer Stage 5 (precmd) preloads the full plugin BEFORE any keystroke; `_ghost_lazy_init` becomes a no-op stub (guarded by `[[ -n $_ZIRO_DEFER_LOADED ]]`).
  - `_ghost_line_pre_redraw()`: Main synchronous hot-path handler executed prior to every screen refresh.
  - `_ghost_compute(query)`: Iterates enabled sources in descending weight order, queries handlers, applies strategies, ranks results, and populates `_ghost_active_candidates`.
- **Rules Implemented**: R3.1–R3.7, R8.1, R10.1–R10.3.

### 3.8 `core/ghost-cache.zsh`
- **Responsibility**: In-memory query caching engine preventing redundant computation during rapid typing or line repositioning.
- **Key Functions**:
  - `_ghost_cache_get(query)`: Retrieves serialized candidate list from associative cache array.
  - `_ghost_cache_put(query, candidates_blob)`: Stores results with timestamp.
  - `_ghost_cache_invalidate(reason)`: Clears cache entries upon working directory change (`chpwd`), manual trigger (`SIGUSR1`), or history expansion.
- **Rules Implemented**: R3.4, R17.5.

### 3.9 `sources/history.source.zsh`
- **Responsibility**: Extracts relevant command lines from shell history matching the current buffer prefix, scored by recency and frequency (frecency).
- **Handler**: `_ghost_source_history(query)`
- **Configuration Defaults**: `weight = 40`, `kind = "history"`, `strategy = "primary"`, `max_suggestions = 20`, `timeout_ms = 50`.
- **Rules Implemented**: R4.1–R4.8, R6.1.

### 3.10 `sources/project.source.zsh`
- **Responsibility**: Contextually inspects active workspace markers (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `.git`) and suggests project-specific workflows (`npm test`, `cargo build`, `git status`).
- **Handler**: `_ghost_source_project(query)`
- **Configuration Defaults**: `weight = 30`, `kind = "project"`, `strategy = "primary"`, `max_suggestions = 15`, `timeout_ms = 40`.
- **Rules Implemented**: R4.1–R4.8.

### 3.11 `sources/zoxide.source.zsh`
- **Responsibility**: Interfaces with the local zoxide database to suggest frequent directory navigation paths for commands beginning with `cd`, `z`, or path prefixes.
- **Handler**: `_ghost_source_zoxide(query)`
- **Configuration Defaults**: `weight = 15`, `kind = "path"`, `strategy = "alternative"`, `strategy_target = "z"`, `requires_absent = ["z"]`.
- **Rules Implemented**: R4.1–R4.8, R7.1.

### 3.12 `sources/lang_help.source.zsh`
- **Responsibility**: Provides flag and subcommand completions for standard UNIX commands and shell built-ins.
- **Handler**: `_ghost_source_lang_help(query)`
- **Configuration Defaults**: `weight = 15`, `kind = "cmd"`, `strategy = "primary"`, `timeout_ms = 30`.
- **Rules Implemented**: R4.1–R4.8.

### 3.13 `sources/sys_comment.source.zsh`
- **Responsibility**: Context-aware suggestions for operating system package management, hardware controls, and systemd units.
- **Handler**: `_ghost_source_sys_comment(query)`
- **Configuration Defaults**: `weight = 10`, `kind = "cmd"`, `strategy = "primary"`, `timeout_ms = 30`.
- **Rules Implemented**: R4.1–R4.8.

### 3.14 `sources/folder.source.zsh`
- **Responsibility**: Suggests relative and absolute filesystem directories matching path arguments in the current buffer.
- **Handler**: `_ghost_source_folder(query)`
- **Configuration Defaults**: `weight = 10`, `kind = "dir"`, `strategy = "primary"`, `timeout_ms = 25`.
- **Rules Implemented**: R4.1–R4.8.

### 3.15 `sources/typo.source.zsh`
- **Responsibility**: Composable typo correction pipeline: (a) bounded Levenshtein (max 2), (b) Damerau transposition (adjacent swaps), (c) keyboard adjacency distance (QWERTY/Dvorak/Colemak), (d) static dictionary. Each layer is TOML-configurable per D10. Executes only when primary sources produce zero matches (fallback strategy).
- **Handler**: `_ghost_source_typo(query)`
- **Configuration Defaults**: `weight = 5`, `kind = "typo"`, `strategy = "fallback"`, `timeout_ms = 35`.
- **Rules Implemented**: R4.1–R4.8, R7.5.

### 3.15b `sources/completions.source.zsh`
- **Responsibility**: Bridge to zsh-completions `#compdef` definitions. Translates native zsh completion functions into candidate suggestions.
- **Handler**: `_ghost_source_completions(query)`
- **Configuration Defaults**: `weight = 30`, `kind = "cmd"`, `strategy = "primary"`, `timeout_ms = 30`.
- **Rules Implemented**: R4.1–R4.8.

### 3.15c `sources/subcommand.source.zsh`
- **Responsibility**: Static CLI tables + dynamic subcommand extraction for common developer utilities (`git`, `docker`, `cargo`, `npm`, etc.).
- **Handler**: `_ghost_source_subcommand(query)`
- **Configuration Defaults**: `weight = 25`, `kind = "cmd"`, `strategy = "primary"`, `timeout_ms = 25`.
- **Rules Implemented**: R4.1–R4.8.

### 3.16 `engine/ghost-matcher.zsh`
- **Responsibility**: High-speed pure Zsh string matching algorithms.
- **Key Functions**:
  - `_ghost_match_prefix(query, candidate)`: Exact prefix verification.
  - `_ghost_match_subsequence(query, candidate)`: Fuzzy character subsequence match with contiguous bonus scoring.
- **Rules Implemented**: R3.1–R3.3.

### 3.17 `engine/ghost-comparator.zsh`
- **Responsibility**: Multi-factor candidate ranking engine.
- **Key Functions**:
  - `_ghost_rank_candidates(candidates_var)`: Sorts raw candidates based on combined score: `(source_weight * 100) - (candidate_length * 2) + bonus`.
- **Rules Implemented**: R3.5.

### 3.18 `engine/ghost-filter.zsh`
- **Responsibility**: Sanitization, deduplication, and length clamping of suggestion lists before UI delivery.
- **Rules Implemented**: R3.1, R4.6.

### 3.19 `ui/ghost-inline.ui.zsh`
- **Responsibility**: Renders the untyped suffix into `POSTDISPLAY` and registers color offsets into `region_highlight`.
- **Key Functions**:
  - `_ghost_ui_inline_render(best_candidate)`: Extracts suffix `${best_candidate#$BUFFER}`, populates `POSTDISPLAY`, and registers highlight boundaries.
  - `_ghost_ui_inline_clear()`: Clears `POSTDISPLAY` and removes corresponding entries from `region_highlight`.
- **Invariant**: ANSI escape sequences are NEVER placed inside `POSTDISPLAY`.
- **Rules Implemented**: R2.1, R3.1, R3.5.

### 3.20 `ui/ghost-preview.ui.zsh`
- **Responsibility**: Displays a single-line summary of available suggestions and keyboard cues via `zle -M`.
- **Key Functions**:
  - `_ghost_ui_preview_render(count, top_candidate)`: Displays `  N more suggestions (Tab to expand)`.
  - `_ghost_ui_preview_clear()`: Clears message area when buffer is empty or Focus Mode activates.
- **Rules Implemented**: R4.4, R8.1.

### 3.21 `ui/ghost-popup-native.ui.zsh`
- **Responsibility**: Pure Zsh fallback interactive popup using `zle -M` when the Rust binary is unavailable.
- **Key Functions**:
  - `_ghost_ui_native_open(candidates)`: Renders box-drawing borders and items list in the message line.
  - `_ghost_ui_native_next()` / `_ghost_ui_native_prev()`: Cycles selection index.
  - `_ghost_ui_native_accept()`: Injects chosen item into `BUFFER`.
- **Rules Implemented**: R9.5, R12.6, R12.7.

### 3.22 `ui/ghost-focus.ui.zsh`
- **Responsibility**: Interactive Focus Mode trigger. Serializes candidates and theme options into JSON, spawns `ghost-popup`, reads selection from stdout, and updates `BUFFER`.
- **Key Functions**:
  - `_ghost_focus_widget()`: Custom ZLE widget bound to `Tab`.
  - `_ghost_focus_serialize_request()`: Generates JSON request payload.
  - `_ghost_focus_apply_response(json_response)`: Parses selection and replaces line editor buffer.
- **Rules Implemented**: R8.1–R8.6, R10.5.

### 3.23 `lib/ghost-logging.zsh`
- **Responsibility**: Appends structured error and telemetry records to `~/.cache/ziro/ghost/errors.log` in JSONL format, rotating files when exceeding 1MB.
- **Key Functions**:
  - `_ghost_log_error(source, error_type, message, elapsed_ms)`: Writes structured JSON record.
- **Rules Implemented**: R12.2–R12.4.

### 3.24 `lib/ghost-stats.zsh`
- **Responsibility**: In-memory timing and invocation metrics collection.
- **Key Functions**:
  - `_ghost_stats_record(source, elapsed_ms, count)`: Updates telemetry counters.
  - `ghost_source_stats()`: Public diagnostics inspection function.
- **Rules Implemented**: R11.4, R18.3.

### 3.25 `lib/ghost-color.zsh`
- **Responsibility**: Samples terminal environment capabilities (`$COLORTERM`, `tput colors`) and maps semantic palette tokens to exact ANSI escape codes or hex values.
- **Rules Implemented**: R2.2, R5.1.

### 3.26 `lib/project_markers.py`
- **Responsibility**: Optional cold-path Python helper invoked during background caching (Stage 2) to analyze complex workspaces without blocking shell responsiveness.
- **Rules Implemented**: R3.2, R10.4.

---

## 4. Rust Companion Binary Breakdown (`ghost-popup`)

The companion binary `ghost-popup` is an independent, per-shell sidecar Rust application residing in `bin/ghost-popup/`. It compiles into a single, high-performance static binary with zero runtime dependencies.

### 4.1 `Cargo.toml`
All dependencies are pinned to exact versions in conformity with Rule 9 (R9.1).
```toml
[package]
name = "ghost-popup"
version = "2.0.0"
edition = "2021"
rust-version = "1.75"
license = "MIT"
description = "Ziro Ghost Focus Mode popup overlay"

[dependencies]
ratatui = "0.28.1"
tachyonfx = "0.5.0"
termbg = "0.5.1"
supports-color = "3.0.2"
serde = { version = "1.0.210", features = ["derive"] }
serde_json = "1.0.128"
crossterm = "0.28.1"
clap = { version = "4.5.20", features = ["derive"] }

[dev-dependencies]
assert_cmd = "2.0.16"
predicates = "3.1.3"

[[bin]]
name = "ghost-popup"
path = "src/main.rs"

[profile.release]
lto = true
codegen-units = 1
opt-level = 3
strip = true
panic = "abort"
```

### 4.2 `src/main.rs`
- **Responsibility**: Sidecar bootstrap. Reads NDJSON from stdin, dispatches to handlers, writes NDJSON to stdout. Runs a crossterm event loop. Cleans up on exit.
- **Modes**:
  - `--daemon=off` (default): sidecar mode, persistent per-shell, NDJSON loop
  - `--bench`: headless synthetic benchmark
  - `--version`: print version
  - `--headless`: validate one JSON without terminal attach
- **Signals**: SIGTERM/SIGINT → restore terminal, exit 0. SIGPIPE → exit 0 (shell closed).
- **Rules Implemented**: R9.2, R9.3, R9.8.

### 4.3 `src/protocol.rs`
- **Responsibility**: Strongly-typed Serde data definitions mapping the JSON IPC contract between Zsh and Rust.
- **Key Structs**:
  ```rust
  #[derive(Debug, Deserialize)]
  pub struct Request {
      pub version: String,
      pub query: String,
      pub cursor_position: usize,
      pub theme: ThemeConfig,
      pub config: UiConfig,
      pub items: Vec<CandidateItem>,
  }

  #[derive(Debug, Deserialize)]
  pub struct CandidateItem {
      pub text: String,
      pub kind: String,
      pub weight: u32,
      pub label: LabelConfig,
      pub docs: DocsConfig,
  }

  #[derive(Debug, Serialize)]
  pub struct Response {
      pub action: Action,
      pub selected_index: usize,
      pub accepted_text: String,
      pub elapsed_ms: u64,
  }

  #[derive(Debug, Serialize, PartialEq, Eq)]
  #[serde(rename_all = "lowercase")]
  pub enum Action {
      Accept,
      Cancel,
  }
  ```
- **Rules Implemented**: R8.3, R9.4.

### 4.4 `src/layout.rs`
- **Responsibility**: Computes geometric bounding boxes (`ratatui::layout::Rect`) for border frames, header counters, candidate items, documentation split panes, and footer key hints based on active terminal dimensions.
- **Layout Constraints**:
  - Height automatically fits the number of items up to `max_items`.
  - Splits horizontally if documentation is present and terminal width > 100 columns; otherwise stacks vertically.
  - Preserves command prompt visibility by positioning strictly below the active cursor line.
- **Rules Implemented**: R9.5.

### 4.5 `src/render.rs`
- **Responsibility**: Translates application state into Ratatui widgets (`Block`, `List`, `Paragraph`), applies styling tokens, and draws frames to the terminal buffer.
- **Key Functions**:
  - `render_frame(frame, state, layout)`: Coordinates drawing passes across all UI regions.
  - `render_item_row(frame, area, item, is_selected, theme)`: Renders selection indicator (`▸`), semantic kind icon, candidate text, and right-aligned badge.
  - `render_preview_pane(frame, area, item, theme)`: Formats documentation markdown and command metadata.
- **Rules Implemented**: R9.5, R11.

### 4.6 `src/effects.rs`
- **Responsibility**: Orchestrates micro-animations and transition shaders using `tachyonfx`.
- **Supported Effects**:
  - `slide-fade`: Window expands downward while fading in foreground elements over 100ms.
  - `fade`: Smooth brightness transition from background luminance to theme colors.
  - `slide`: Height interpolation without opacity modulation.
  - `none`: Direct instant frame render.
- **Safety**: Automatically forces `Animation::None` if `NO_COLOR` is detected in the environment.
- **Rules Implemented**: R9.7.

### 4.7 `src/input.rs`
- **Responsibility**: Intercepts keyboard and ANSI mouse events from Crossterm.
- **Key Mappings**:
  - `Tab` / `Down Arrow`: Cycle highlight to next candidate (`{"type":"cycle_next"}`; buffer unchanged).
  - `Shift-Tab` / `Up Arrow`: Cycle highlight to previous candidate (`{"type":"cycle_prev"}`).
  - `Any printable character`: Emits `{"type":"accept_typed", "char":"<c>"}` → Zsh sets BUFFER=`<suggestion><char>`. Per D6/D8.
  - `Enter`: Emits `{"type":"execute_buffer"}` → Zsh runs `zle accept-line` on the ORIGINAL buffer (never accepts suggestion). Per D8.
  - `Esc` / `Ctrl-G`: Emits `{"type":"cancel"}` → Focus exits, buffer unchanged.
  - `Left Click`: Selects and immediately accepts item under mouse pointer (equivalent to typing the whole suggestion).
  - `Scroll Wheel`: Increments or decrements active selection index.
- **Note**: `Ctrl-C` (SIGINT) is NOT intercepted by the sidecar; it propagates normally and the parent shell handles it.
- **Rules Implemented**: R9.8.

### 4.8 `src/diff.rs`
- **Responsibility**: Differential partial rendering engine. Maintains double-buffered terminal cell matrices, comparing the back-buffer against the front-buffer.
- **Mechanism**:
  - Detects identical glyph, foreground color, background color, and modifier flags.
  - Emits cursor positioning sequences and color updates only for cells that changed since the preceding frame.
  - Drastically minimizes payload size over SSH and high-latency terminal connections.
- **Rules Implemented**: R9.6.

### 4.9 `src/theme.rs`
- **Responsibility**: Loads color presets from TOML definitions or auto-detects background luminance using `termbg`.
- **Supported Themes**: Catppuccin Mocha/Latte, Tokyo Night, Gruvbox, Dracula, Nord, Solarized Dark/Light, and Terminal Auto-Palette.
- **Rules Implemented**: R5.1, R11.

### 4.10 `src/errors.rs`
- **Responsibility**: Custom error types providing panic-free failure handling. All fatal errors are formatted cleanly to stderr before process termination.
- **Rules Implemented**: R9.4.

---

## 5. Data Flow Diagrams

### 5.1 Keystroke Data Flow (Hot Path `< 3.0ms`)

```
User types character in terminal
            │
            ▼
ZLE hook `line-pre-redraw` fires
            │
            ▼
_ghost_line_pre_redraw()  [emulate -L zsh enforced]
            │
            ├──► 1. Check in-memory query cache for $BUFFER
            │         │
            │         ├─► [Cache Hit] ──► Retrieve candidates immediately
            │         │
            │         └─► [Cache Miss] ──► _ghost_compute(BUFFER)
            │                                    │
            │                                    ├──► Reset status tracker (_ghost_strategy_reset_cycle)
            │                                    │
            │                                    ├──► Loop registered sources in descending weight order:
            │                                    │       │
            │                                    │       ├──► Evaluate strategy conditions (_ghost_strategy_should_run)
            │                                    │       │     ├── Enabled check
            │                                    │       │     ├── requires_present / requires_absent
            │                                    │       │     └── requires_success / requires_failed
            │                                    │       │
            │                                    │       ├─► [Conditions Met]
            │                                    │       │     ├── Call handler: _ghost_source_<name> "$BUFFER" >/dev/null 2>&1
            │                                    │       │     ├── Enforce source timeout_ms
            │                                    │       │     └── Record status: success / empty / timeout
            │                                    │       │
            │                                    │       └─► [Conditions Unmet] ──► Mark status = skipped
            │                                    │
            │                                    ├──► Aggregate _ghost_results arrays
            │                                    ├──► Run ranking engine (_ghost_rank_candidates)
            │                                    ├──► Filter & deduplicate (_ghost_filter_sanitize)
            │                                    └──► Store top candidate in query cache
            │
            ├──► 2. Render Ghost Line (_ghost_ui_inline_render)
            │         │
            │         ├──► Extract untyped suffix: suffix="${top_candidate#$BUFFER}"
            │         ├──► Assign POSTDISPLAY="$suffix" (Pure text, zero ANSI codes)
            │         └──► Append highlight span to region_highlight: "${#BUFFER} $((start + ${#suffix})) $color"
            │
            └──► 3. Render Preview Bar (_ghost_ui_preview_render)
                      │
                      └──► Call zle -M "  N more suggestions (Tab to expand)"
```

### 5.2 Focus Mode Interactive Flow (On-Demand Tab)

**Focus Mode Interactive Flow (per-shell sidecar via NDJSON)**

Tab is an **EXTERNAL ZLE widget** owned by Ghost; NOT a Defer task.

```
User types → line-pre-redraw → compute candidates → render preview
                                                          │
                                                          ▼
                                                 (no Rust involved)

User presses Tab (first time)
              │
              ▼
Zsh: spawn ghost-popup sidecar (if not already running)
     send {"type":"init"} then {"type":"update", "query":"...", "items":[...]}
     send {"type":"focus_enter"}
              │
              ▼
Rust sidecar: render focus UI
              send {"type":"selection", "index":0, "preview_text":"..."}
              │
Zsh: render preview as gray inline suffix; buffer UNCHANGED

User presses Tab again
              │
Zsh → Rust: {"type":"cycle_next"}
Rust → Zsh: {"type":"selection", "index":1, ...}

User TYPES character 's'
              │
Zsh → Rust: {"type":"accept_typed", "char":"s"}
Rust → Zsh: {"type":"accept", "text":"git push origin main", "cursor":19}
Zsh: BUFFER = text + 's'; FOCUS_EXIT
     recompute candidates; update Rust with new items

User presses Enter
              │
Zsh: executes BUFFER (standard zle accept-line)
     send {"type":"exit"} to Rust (but keeps process alive)

User presses Esc or Ctrl-G
              │
Zsh → Rust: {"type":"exit"}
Zsh: revert to pre-focus buffer; FOCUS_EXIT

Shell exits
              │
Zsh → Rust: {"type":"shutdown"}
Rust: clean up, exit 0
```

### 5.3 Fallback Chain Degradation Flow

```
Focus Mode Triggered (Tab)
            │
            ▼
Sidecar already running?
            │
            ├─► YES ──► Send NDJSON update; receive selection events
            │           │
            │           ├─► Responsive (< 5s) ──► Complete interaction (Tier 1)
            │           │
            │           └─► Unresponsive (> 5s)
            │                 │
            │                 ▼
            │           Kill sidecar (SIGTERM) → Fall back to Zsh native (Tier 2)
            │
            └─► NO ──► Can spawn `ghost-popup`?
                       │
                       ├─► YES ──► Spawn sidecar, send init, proceed
                       │
                       └─► NO ──► Zsh Native Popup (Tier 2)
                                 │
                                 └─► If also disabled: Ghost Line only (Tier 3)
```

Degradation is graceful. On any sidecar failure, log once to `~/.cache/ziro/ghost/popup.log` and continue without disrupting editing.

### 5.4 Staged Loading Architecture (`ziro-defer`)

```
T0: Shell Bootstrap (Stage 0) ─── Budget: < 0.5ms
    │
    ├── Source ghost.plugin.zsh
    ├── Bind GHOST_HOME path variable
    ├── Register stub ZLE hook _ghost_lazy_init
    └── Return immediately to allow prompt rendering
    │
T1: First Keystroke (Stage 1) ─── Budget: < 8.0ms
    │
    ├── _ghost_lazy_init hook fires on user typing
    ├── Source core/ghost-version.zsh
    ├── Source core/ghost-config.zsh and load ghost.conf
    ├── Source core/ghost-kinds.zsh, ghost-registry.zsh, ghost-strategy.zsh
    ├── Source engine/ modules (matcher, comparator, filter)
    ├── Source ui/ghost-inline.ui.zsh and ui/ghost-preview.ui.zsh
    ├── Source primary sources: history.source.zsh, project.source.zsh, zoxide.source.zsh
    ├── Swap ZLE hook: replace _ghost_lazy_init with _ghost_line_pre_redraw
    └── Perform immediate compute and render for the first keystroke
    │
T2: Idle Background (Stage 2) ─── Asynchronous
    │
    ├── ziro-defer loads secondary sources: lang_help, sys_comment, folder, typo
    └── Background warmup of project markers cache
    │
T3: Interactive Tab Press (Stage 3) ─── Budget: < 30.0ms
    │
    ├── Source ui/ghost-focus.ui.zsh and ui/ghost-popup-native.ui.zsh
    └── Spawn ghost-popup binary on demand
```

---

## 6. Data Models and Schemas

### 6.1 Source Registration Schema (Zsh)

When `ghost_register_source` is invoked, it populates synchronized associative arrays keyed by source name:

```zsh
# Core parameters
_ghost_sources_handler[history]="_ghost_source_history"
_ghost_sources_weight[history]="40"
_ghost_sources_kind[history]="history"
_ghost_sources_max_suggestions[history]="20"
_ghost_sources_timeout_ms[history]="50"

# Strategy parameters
_ghost_sources_strategy[history]="primary"
_ghost_sources_strategy_target[history]=""
_ghost_sources_requires_present[history]=""
_ghost_sources_requires_absent[history]=""
_ghost_sources_requires_success[history]=""
_ghost_sources_requires_failed[history]=""

# Presentation parameters
_ghost_sources_label_type[history]="badge"
_ghost_sources_label_position[history]="right"
_ghost_sources_label_text[history]="hist"
_ghost_sources_label_icon[history]="󰋚"
_ghost_sources_color_mode[history]="theme"

# Documentation parameters
_ghost_sources_docs_enabled[history]="true"
_ghost_sources_docs_source[history]="builtin"
```

### 6.2 Inter-Process Communication JSON Contract

#### NDJSON Stream (Zsh → Rust via Stdin)

Each line is a standalone JSON object. The first object is `init`; subsequent updates are `update`, `focus_enter`, `cycle_next`, `cycle_prev`, `accept_typed`, `exit`, or `shutdown`.

```jsonl
{"type":"init","version":"2.0.0","theme":{"preset":"catppuccin-mocha","border":"#89b4fa","selection_bg":"#313244","item_fg":"#cdd6f4"},"config":{"max_items":10,"border":"rounded","animation":"slide-fade","animation_ms":100,"mouse_support":true,"partial_render":true}}
{"type":"update","query":"git pu","cursor":6,"items":[{"text":"git push origin main","kind":"git","weight":40,"label":{"type":"badge","text":"git","icon":"󰊢","color":"#a6e3a1"},"docs":{"enabled":true,"content":"Update remote refs."}},{"text":"git pull --rebase","kind":"git","weight":35,"label":{"type":"badge","text":"git"},"docs":{"enabled":false}}]}
{"type":"focus_enter"}
{"type":"cycle_next"}
{"type":"accept_typed","char":"s"}
{"type":"exit"}
{"type":"shutdown"}
```

#### NDJSON Stream (Rust → Zsh via Stdout)

```jsonl
{"type":"ready"}
{"type":"selection","index":0,"preview_text":"git push origin main"}
{"type":"selection","index":1,"preview_text":"git pull --rebase"}
{"type":"accept","text":"git push origin main","typed_char":"s","cursor":20}
{"type":"cancel"}
{"type":"error","msg":"..."}
```

- `selection`: emitted on every highlight change. Zsh renders `preview_text` as gray inline suffix.
- `accept`: emitted after user types a character while focused. Zsh sets `BUFFER=text+typed_char` and exits Focus.
- `cancel`: user pressed Esc/Ctrl-G. Buffer unchanged.
- `error`: non-fatal; Zsh logs and continues.

### 6.3 Theme Specification Schema (TOML)

Theme definitions in `themes/<name>.toml` conform to this declarative schema:

```toml
[meta]
theme_version = "1.0.0"
name = "catppuccin-mocha"
author = "catppuccin"

[colors]
border = "#89b4fa"
header_fg = "#cdd6f4"
header_bg = "#1e1e2e"
item_fg = "#cdd6f4"
item_bg = "#1e1e2e"
selection_fg = "#1e1e2e"
selection_bg = "#89b4fa"
preview_fg = "#a6adc8"
preview_bg = "#181825"
footer_fg = "#6c7086"
counter_fg = "#f9e2af"

[kind_colors]
git = "#a6e3a1"
cmd = "#89b4fa"
path = "#f9e2af"
dir = "#94e2d5"
file = "#cdd6f4"
hist = "#9399b2"
project = "#fab387"
typo = "#f38ba8"
alias = "#cba6f7"
var = "#eba0ac"
func = "#94e2d5"
snippet = "#f5c2e7"
```

### 6.4 Runtime Source Execution Status Model

Tracked in memory inside `_ghost_source_status`:
```zsh
typeset -gA _ghost_source_status=(
  [history]="success"
  [project]="empty"
  [zoxide]="skipped"
  [lang_help]="timeout"
  [sys_comment]="crash"
  [folder]="success"
  [typo]="disabled"
)
```

### 6.5 Error Log Record Schema (JSONL)

Every record written to `~/.cache/ziro/ghost/errors.log` must conform to:
```json
{"ts":1729123456,"level":"warn","source":"project","error_type":"timeout","message":"handler exceeded 50ms","elapsed_ms":54}
{"ts":1729123480,"level":"info","source":"typo","error_type":"skipped","message":"conditions unmet (primary sources produced matches)","elapsed_ms":0}
```

---

## 7. Execution Lifecycles

### 7.1 Shell Startup Lifecycle (Stage 0)
- **T + 0.0ms**: Interactive shell process launches; starts executing `.zshrc`.
- **T + 0.5ms**: `ghost.plugin.zsh` sourced by plugin manager.
- **T + 0.7ms**: `$GHOST_HOME` bound; `_ghost_lazy_init` registered on `line-pre-redraw`.
- **T + 0.9ms**: Control returned to shell. Stage 0 completes well within the `< 0.5ms` budget.

### 7.2 First Keystroke Lifecycle (Stage 1)
- **T + 0.0ms**: User types first character into the command line.
- **T + 0.2ms**: ZLE invokes `_ghost_lazy_init`.
- **T + 1.5ms**: Core orchestration modules loaded into memory.
- **T + 3.0ms**: Configuration loaded from `ghost.conf`.
- **T + 4.5ms**: Primary sources registered and initialized.
- **T + 5.2ms**: Real `_ghost_line_pre_redraw` hook substituted; lazy stub removed.
- **T + 6.0ms**: Query computed, inline ghost suffix rendered. User perceives zero lag.

### 7.2b — Defer-Integrated Lifecycle

When loaded via Defer (recommended):
- **T+0.0ms (Stage 0)**: `ghost.plugin.zsh` sourced by Defer Stage 1. Registers stubs only.
- **T+0.5ms (end of Stage 0)**: Prompt rendered. Defer Stage 5 (precmd) fires.
- **T+0.5ms to T+8.5ms**: Defer Stage 5 dispatches Ghost task at slot=`a`. All core loaded. First compute against empty buffer.
- **T+8.5ms+**: User types. Every keystroke is hot-path compute (<2ms). No lazy-init.
- **T+idle (Stage 2)**: Defer Stage 6 loads auxiliary sources.
- **T+Tab (Stage 3)**: Ghost's Tab widget (**EXTERNAL ZLE widget**) spawns Rust sidecar. Defer not involved.

Standalone users see §7.2; integrated users see §7.2b.

### 7.3 Regular Keystroke Cycle (Hot Path)
- **T + 0.0ms**: Keystroke event intercepted by `line-pre-redraw`.
- **T + 0.2ms**: Previous inline highlights removed; query cache checked.
- **T + 1.0ms**: Sources evaluated; candidates aggregated and ranked.
- **T + 1.6ms**: Untyped suffix injected into `POSTDISPLAY`; color offsets added to `region_highlight`.
- **T + 1.8ms**: Preview bar updated via `zle -M`. Cycle completes in `< 2.0ms`.

### 7.4 Interactive Focus Mode Lifecycle (Tab)

**First Tab of the session** (sidecar spawn):
- **T+0.0ms**: User presses Tab.
- **T+0.3ms**: `_ghost_focus_widget` clears inline display; serializes init+update NDJSON.
- **T+1.2ms**: `ghost-popup` sidecar spawned, reads `init` from stdin.
- **T+12.0ms**: Rust sidecar computes layout, sends `{"type":"ready"}` then `{"type":"selection","index":0}`.
- **T+22.0ms**: First frame displayed with TachyonFX transition.

**Subsequent Tabs** (sidecar reused):
- **T+0.0ms**: User presses Tab. ZLE widget sends `{"type":"cycle_next"}`.
- **T+2.0ms**: Sidecar advances highlight; sends `{"type":"selection","index":N}`. Zsh re-renders gray inline preview.

**Accept via typing** (D6):
- **T+0.0ms**: User types character `c`.
- Zsh sends `{"type":"accept_typed","char":"c"}` to sidecar.
- Sidecar replies `{"type":"accept","text":"<suggestion>","typed_char":"c"}`.
- Zsh sets `BUFFER=<suggestion>c`; FOCUS_EXIT; recomputes candidates; sends `{"type":"update",...}` to sidecar.

**Enter** (D8):
- Enter is NOT intercepted by the sidecar. It flows through ZLE as `accept-line` and executes the current BUFFER. Focus exits before execution.

**Cancel (Esc/Ctrl-G)**:
- User presses Esc/Ctrl-G. Zsh sends `{"type":"exit"}`. Buffer unchanged. Focus exits.

**Shell exits**:
- Zsh sends `{"type":"shutdown"}`. Sidecar restores terminal mode, exits 0. No zombie processes.

### 7.5 Cache Invalidation Matrix

| Invalidation Trigger | Scope Affected | Action Taken |
|---|---|---|
| `chpwd` hook (directory change) | `project`, `folder`, `zoxide` | Invalidate directory caches immediately |
| `SIGUSR1` signal | All sources | Flush entire query cache and re-read history |
| Shell command execution (`preexec`) | Query cache | Clear temporary suggestion buffers |
| Line reset (`Ctrl-C` / `Ctrl-U`) | Inline UI | Clear `POSTDISPLAY` and `region_highlight` |
| Configuration file edit | Configuration cache | Re-parse `ghost.conf` and re-validate schemas |
| Source execution timeout | Specific source | Set source status to `timeout` for current line |

---

## 8. Rule Compliance Matrix

The following matrix maps each architectural component directly to the mandatory engineering rules established in `RULES.md`:

| Component / Module | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | R10 | R11 | R12 | R13 | R14 | R15 | R16 | R17 | R18 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `ghost.plugin.zsh` | ✅ | ✅ | ✅ | | | | | | | ✅ | | | | ✅ | ✅ | ✅ | ✅ | ✅ |
| `core/ghost-version.zsh` | ✅ | ✅ | | | | | | | | | | | ✅ | | ✅ | ✅ | | |
| `core/ghost-config.zsh` | ✅ | ✅ | ✅ | | ✅ | | | | | | | | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `core/ghost-kinds.zsh` | ✅ | ✅ | ✅ | | ✅ | | | | | | | | | | ✅ | ✅ | | |
| `core/ghost-registry.zsh` | ✅ | ✅ | ✅ | ✅ | | ✅ | | | | | | | | ✅ | ✅ | ✅ | | ✅ |
| `core/ghost-strategy.zsh` | ✅ | ✅ | ✅ | | | | ✅ | | | | | | | | ✅ | ✅ | | ✅ |
| `core/ghost-core.zsh` | ✅ | ✅ | ✅ | | | | | | | ✅ | | | | | ✅ | ✅ | ✅ | ✅ |
| `core/ghost-cache.zsh` | ✅ | ✅ | ✅ | | | | | | | | | | | | ✅ | ✅ | ✅ | |
| `sources/*.zsh` | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ | | | | ✅ | ✅ | | | ✅ | ✅ | ✅ | ✅ |
| `engine/*.zsh` | ✅ | ✅ | ✅ | | | | | | | | | | | | ✅ | ✅ | | |
| `ui/ghost-inline.ui.zsh` | ✅ | ✅ | ✅ | | ✅ | | | | | | | | | | ✅ | ✅ | | ✅ |
| `ui/ghost-preview.ui.zsh` | ✅ | ✅ | ✅ | | | | | | | | | | | | ✅ | ✅ | | |
| `ui/ghost-popup-native.ui.zsh` | ✅ | ✅ | ✅ | | | | | | | | | | | | ✅ | ✅ | | |
| `ui/ghost-focus.ui.zsh` | ✅ | ✅ | ✅ | | | | | ✅ | | ✅ | | | | | ✅ | ✅ | | ✅ |
| `lib/ghost-logging.zsh` | ✅ | ✅ | ✅ | | | | | | | | | ✅ | | | ✅ | ✅ | ✅ | |
| `lib/ghost-stats.zsh` | ✅ | ✅ | ✅ | | | | | | | | ✅ | | | | ✅ | ✅ | | |
| `lib/ghost-color.zsh` | ✅ | ✅ | ✅ | | ✅ | | | | | | | | | | ✅ | ✅ | | |
| `bin/ghost-popup/` (Rust) | ✅ | ✅ | | | | | | ✅ | ✅ | | ✅ | ✅ | | | ✅ | ✅ | ✅ | ✅ |

---

## 9. Build and Distribution Architecture

### 9.1 Rust Binary Compilation Pipeline

#### Development Build
```bash
cd bin/ghost-popup
cargo build --release
# Artifact generated at: target/release/ghost-popup
```

#### Automated End-User Installation (`ziro ghost install-popup`)
1. Checks whether `cargo` and `rustc` exist in `$PATH`.
2. If toolchain is missing: prints guidance for installing Rust or prompts to download pre-built binaries.
3. If toolchain is present:
   ```bash
   cargo build --release --manifest-path "$GHOST_HOME/bin/ghost-popup/Cargo.toml"
   cp "$GHOST_HOME/bin/ghost-popup/target/release/ghost-popup" "$GHOST_HOME/bin/ghost-popup/ghost-popup"
   chmod +x "$GHOST_HOME/bin/ghost-popup/ghost-popup"
   ```
4. Executes `ghost-popup --version` to verify runtime health.

#### Pre-Compiled Release Artifacts
GitHub Actions automatically compiles and attaches release binaries for:
- `ghost-popup-x86_64-unknown-linux-gnu`
- `ghost-popup-aarch64-unknown-linux-gnu`
- `ghost-popup-x86_64-apple-darwin`
- `ghost-popup-aarch64-apple-darwin`

### 9.2 Plugin Installation Workflows

- **Znap**:
  ```zsh
  znap source Pakrohk/ziro-ghost
  ```
- **Zinit**:
  ```zsh
  zinit light Pakrohk/ziro-ghost
  ```
- **Standalone Clone**:
  ```zsh
  git clone https://github.com/Pakrohk/ziro-ghost.git ~/.local/share/ziro/vendor/Pakrohk/ziro-ghost
  source ~/.local/share/ziro/vendor/Pakrohk/ziro-ghost/ghost.plugin.zsh
  ```

### 9.3 Post-Installation Filesystem Blueprint

```
$HOME/
├── .config/ziro/
│   ├── ghost.conf                      # User configuration
│   └── ghost.conf.v1.backup            # Archived legacy configuration
│
├── .cache/ziro/ghost/
│   ├── errors.log                      # JSONL structured exception log
│   ├── popup.log                       # Companion binary diagnostics
│   └── stats.json                      # Performance telemetry cache
│
└── .local/share/ziro/vendor/Pakrohk/ziro-ghost/  # Sovereign plugin repository
    ├── ghost.plugin.zsh
    ├── core/
    ├── sources/
    ├── engine/
    ├── ui/
    ├── lib/
    ├── bin/
    │   └── ghost-popup/
    │       └── ghost-popup             # Compiled executable
    ├── themes/
    └── config/
```

---

## 10. Testing Architecture

### 10.1 Automated Test Suite Taxonomy

| Category | Path | Runner | Minimum Count | Pass Criteria |
|---|---|---|:---:|---|
| **Unit (Zsh)** | `tests/test_source_*.zsh` | `_harness.zsh` | 100+ assertions | 100% passing |
| **Integration (Zsh)** | `tests/test_integration_*.zsh` | `_harness.zsh` | 20+ scenarios | Zero ZLE errors |
| **Rust Unit** | `bin/ghost-popup/src/*.rs` | `cargo test` | 40+ unit tests | 100% passing |
| **Rust Integration** | `bin/ghost-popup/tests/*.rs` | `assert_cmd` | 15+ CLI tests | Zero panics |
| **Hot-Path Benchmarks** | `tests/test_hotpath.zsh` | Custom bench | 5 iterations | Keystroke `< 3.0ms` |
| **Sovereignty Tests** | `tests/test_sovereignty.zsh` | `zsh -f` | 5 isolation checks | Return code 0 |

### 10.2 Pure Zsh Test Assertion Harness (`tests/_harness.zsh`)

```zsh
typeset -gi _GHOST_TESTS_RUN=0
typeset -gi _GHOST_TESTS_PASSED=0
typeset -gi _GHOST_TESTS_FAILED=0

_ghost_assert_eq() {
  local expected="$1"
  local actual="$2"
  local description="${3:-assertion}"
  (( _GHOST_TESTS_RUN++ ))

  if [[ "$expected" == "$actual" ]]; then
    (( _GHOST_TESTS_PASSED++ ))
    print -u1 "  ✅ PASS: $description"
  else
    (( _GHOST_TESTS_FAILED++ ))
    print -u2 "  ❌ FAIL: $description"
    print -u2 "     expected: '$expected'"
    print -u2 "     actual:   '$actual'"
    return 1
  fi
}

_ghost_test_summary() {
  print "\nTest Summary: $_GHOST_TESTS_PASSED / $_GHOST_TESTS_RUN passed."
  (( _GHOST_TESTS_FAILED == 0 ))
}
```

### 10.3 Sample Unit Test (`tests/test_source_typo.zsh`)

```zsh
#!/usr/bin/env zsh
emulate -L zsh
source "${0:A:h}/../core/ghost-version.zsh"
source "${0:A:h}/../sources/typo.source.zsh"
source "${0:A:h}/_harness.zsh"

test_typo_correction_single_transposition() {
  _ghost_source_typo "sl"
  _ghost_assert_eq "ls" "${_ghost_results[1]}" "Transposition 'sl' corrects to 'ls'"
}

test_typo_ignores_single_character() {
  _ghost_source_typo "a"
  _ghost_assert_eq "0" "${#_ghost_results[@]}" "Single character produces zero typo corrections"
}

print "Running Typo Source Tests..."
test_typo_correction_single_transposition
test_typo_ignores_single_character
_ghost_test_summary
```

---

## 11. Performance Verification and Budgets

### 11.1 Benchmarking Methodology

Performance measurements follow the standard `min-of-11` methodology to eliminate system scheduling noise:
```zsh
# Keystroke hot-path measurement
zsh -c '
  zmodload zsh/datetime
  times=()
  for i in {1..11}; do
    t0=$EPOCHREALTIME
    source ./ghost.plugin.zsh
    _ghost_compute "git status"
    t1=$EPOCHREALTIME
    times+=($(( (t1 - t0) * 1000 )))
  done
  print -l "${times[@]}" | sort -n | head -n1
'
```

### 11.2 Performance Budgets Table

| Performance Dimension | Target | Hard Ceiling | Enforcement Mechanism |
|---|:---:|:---:|---|
| **Stage 0 Bootstrap** | `< 0.30ms` | `0.50ms` | CI automated failure |
| **Keystroke Hot Path** | `< 1.80ms` | `3.00ms` | CI automated failure |
| **Color Resolution** | `< 0.05ms` | `0.20ms` | Static code review |
| **Source Execution (Individual)** | `< 5.00ms` | `timeout_ms` | Runtime abort & skip |
| **Focus Mode Spawn to Frame** | `< 25.0ms` | `40.0ms` | CI benchmark assertion |
| **Differential Cell Diff** | `< 6.00ms` | `12.0ms` | Cargo benchmark suite |
| **Memory Resident Set (RSS)** | `< 4.0MB` | `8.0MB` | Leak audit in CI |

### 11.3 Performance Regression Policy

- **Regression `< 0.3ms`**: Permissible without formal approval.
- **Regression `0.3ms – 0.5ms`**: Permissible only with explicit justification documented in the pull request.
- **Regression `0.5ms – 2.0ms`**: Requires architecture team escalation and review.
- **Regression `> 2.0ms`**: Automatic pull request merge block.

---

## 12. References

### 12.1 Internal Specifications and Decisions
- **`Spec 009 (v2.0.0)`**: Ziro Ghost Specification (`.specify/specs/009-ziro-ghost-plugin/spec.md`)
- **`009-RULES (v1.0.0)`**: Engineering Rules for Spec 009 (`.specify/specs/009-ziro-ghost-plugin/RULES.md`)
- **`Spec 000`**: System Architecture & Layered Model (`.specify/specs/000-architecture/spec.md`)
- **`Spec 011`**: Zsh Optimization Specification (`.specify/specs/011-zsh-optimization/spec.md`)
- **`Spec 012`**: Optional Plugin Manifest Specification (`.specify/specs/012-plugin-manifest/spec.md`)
- **`ADR-006`**: Ghost Plugin Architecture (`.specify/decisions/ADR-006-ghost-architecture.md`)
- **`ADR-007`**: Versioning Policy (`.specify/decisions/ADR-007-versioning-policy.md`)
- **`ADR-009`**: Code Style Guide (`.specify/decisions/ADR-009-code-style-guide.md`)
- **`ADR-011`**: Plugin Manifest Decision (`.specify/decisions/ADR-011-plugin-manifest.md`)

### 12.2 External References and Frameworks
- **Ratatui Terminal UI Library**: `https://github.com/ratatui-org/ratatui`
- **TachyonFX Micro-Animations**: `https://github.com/junkdog/tachyonfx`
- **Crossterm Terminal Input Engine**: `https://github.com/crossterm-rs/crossterm`
- **Termbg Background Luminance Detector**: `https://github.com/ayosec/termbg`
- **Supports-Color Palette Detector**: `https://github.com/zkat/supports-color`
- **Neovim `nvim-cmp` Completion Architecture**: `https://github.com/hrsh7th/nvim-cmp`
- **Zsh Official Manual**: Zsh Line Editor (`man zshzle`) and Parameter Expansion (`man zshexpn`)
