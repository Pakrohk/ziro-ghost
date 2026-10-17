# Changelog

All notable changes to `ziro-ghost` are documented here.

## [1.0.3] — 2026-10-17 — Patch Release: Ghost Line Visibility & Lifecycle Fixes

### Fixed

- **Line-Finish Hook**: Added `line-finish` ZLE hook (`_ghost_line_finish`) to clear `POSTDISPLAY` and `region_highlight` before command execution, eliminating the visual glitch where ghost text lingered after pressing Enter.
- **Terminal Redraw**: Explicit `zle -R` invocation in inline rendering and clearing functions, ensuring suggestions render immediately on interactive keystrokes.
- **History Loader**: Robust in-memory + persistent `~/.zsh_history` parsing without assuming `extendedglob` or collapsing history array slices.
- **Key Bindings**: Explicit bindings for Right Arrow (`^[[C`, `^[OC`), `Ctrl+F`, and `Ctrl+E` for inline suggestion acceptance.

---

## [1.0.2] — 2026-10-17 — Minimal Interim Release (Ghost Line Only)

### Changed

- **Simplified to Minimal Ghost Line**:
  - Pure native ZLE `POSTDISPLAY` and `region_highlight` gray styling.
  - Zero interference with command line typing or terminal modes.
  - Active sources: `history` and `typo` (fallback).
  - Streamlined `ghost.plugin.zsh` with lazy initialization on first keystroke (`_ghost_lazy_init`).
  - Standalone sourcing verified: `zsh -f -c 'source ghost.plugin.zsh; echo OK'`.
  - Hot-path keystroke latency: < 2.0ms.

### Removed

- Stripped all popup, focus, fzf-tab, preview, docs, and loading UI modules (`ui/completion.ui.zsh`, `ui/popup.ui.zsh`, `ui/preview.ui.zsh`, `ui/docs.ui.zsh`, `ui/loading.ui.zsh`).
- Stripped popup-related secondary sources (`completions`, `subcommand`, `project`, `zoxide`).
- All advanced interactive features deferred to the full Two-Layer (Zsh + Rust) architecture in **v2.0.0** (see Spec 009 v2.0.0).

---

## [1.0.1] — 2026-10-16 — Bug Fix: Native ZLE Popup + Ghost Color + Typo & Handlers

### Fixed

- **Native ZLE popup (complete rewrite, fzf replacement)**:
  - Eliminated `fzf` alternate screen invocation that caused prompt loss and context leaving
  - Replaced with pure ZLE `zle -M` non-blocking floating menu below prompt (nvim-cmp / Iris style)
  - Non-blocking input: user can continue typing while popup is open; menu dynamically refreshes
  - Visual selection indicator (`▸`) on active item with bold cyan highlight
  - Header with counter (`1/N`) and dynamic source indicator (`[source: ...]`)
  - Compact layout, right-aligned semantic kind badges, and windowing (max 10 items)
  - Tab / Shift-Tab cycle navigation, Enter accepts selection, Esc / Ctrl-G dismisses without touching buffer

- **Ghost text dim gray color styling**:
  - Dynamic color support detection: `truecolor` (`fg=#6c6c6c`) → `256` (`fg=240`) → `ansi8` (`fg=brightblack`)
  - User configuration override support via `ui.inline.color`
  - Theme preset loader from `$GHOST_HOME/themes/<preset>.toml`
  - Canonical `region_highlight` offset starting at `${#BUFFER}`
  - Zero-fork pure Zsh parser ensuring hot-path purity (Spec 011)

- **Stdout leak from source handlers (critical)**: Handlers that printed output caused terminal corruption and line jumping during ZLE keystroke events.
  - Enforced `>/dev/null 2>&1` in `_ghost_invoke_handler` in `core/ghost-core.zsh`
  - Removed obsolete `print -rl` statements from typo, history, subcommand, completions, and project sources
  - Added centralized `_ghost_parse_candidate` helper to safely parse `weight:kind:text`

- **Typo source over-firing**:
  - Minimum query length raised to 3 characters (`TF-1`)
  - Length difference filter tightened to ±1 (`TF-2`)
  - Dynamic Levenshtein threshold: max distance 1 for words ≤ 4 chars, max distance 2 for longer (`TF-3`)
  - First-character heuristic with transposition allowance (`TF-4`)
  - Skip exact matches for valid commands

### Compatibility

- Public API remains frozen (v1.0.0 guarantee)
- No breaking changes

### Compatibility

- Public API remains frozen (v1.0.0 guarantee)
- No breaking changes

---

## [1.0.0] — 2026-10-16 — Stable Release

First stable release of `ziro-ghost` — standalone, modular, IDE-like autocomplete for Zsh.

### Features

- **Ghost text**: Instant inline `POSTDISPLAY` suggestions with zero-latency keystroke response.
- **Popup menu**: Interactive `fzf` candidate exploration with Tab/Shift-Tab navigation and native ZLE menu fallback.
- **12 Semantic Kinds**: Distinct styling for `git`, `cmd`, `path`, `dir`, `file`, `alias`, `var`, `func`, `history`, `project`, `typo`, and `snippet`.
- **Icons**: High-definition Nerd Font glyphs with clean ASCII fallbacks for basic TTYs.
- **Multi-Source Engine**: Calibrated weighted scoring:
  - `history` (weight 40)
  - `project` (weight 30)
  - `zoxide` (weight 15)
  - `subcommand` (weight 10)
  - `completions` (weight 10)
  - `typo` (fallback-only, weight 5)
- **Project-Aware**: Intelligent recipe and command discovery for Python, Node, Rust, Go, Ruby, PHP, Make, Docker, Just, and Git.
- **Typo Correction Engine**: Multi-tiered correction using static maps, Damerau transposition, QWERTY keyboard distance, and bounded Levenshtein algorithm.
- **Custom Source API**: Declarative `[[sources]]` configuration or file-based handlers with contract-based safety (`max_suggestions`, `timeout_ms`).
- **Preview Pane**: Real-time structured metadata preview (kind, source, weight, frecency) in `fzf` popup.
- **Docs Window**: Command documentation lookup querying `tldr`, `man -P cat`, or `--help` with 3-second timeout and 24-hour disk cache.
- **Loading Indicator**: Pure-Zsh zero-fork spinner for `RPROMPT` with 200ms threshold gating.
- **Zoxide Integration**: Smart directory suggestions on `cd` commands and interactive `j` jump helper shortcut.
- **Contract-Based Safety**: In-process runtime bounds with zero forks in hot-path.
- **Source Stats API**: `ghost_source_stats`, `ghost_all_source_stats`, `ghost_source_stats_reset` for runtime observability.

### Configuration

- `~/.config/ziro/ghost.conf` (TOML format) with compiled defaults fallback.
- Sections: `[ui]`, `[ui.preview]`, `[ui.docs]`, `[ui.loading]`, `[correction]`, `[safety]`, `[[sources]]`.

### Architecture & Standards

- IOP-compliant (Intent-Oriented Programming).
- Registry pattern for sources, UIs, matchers, and comparators.
- Fully decoupled: zero dependencies on `ziro-shell`.
- Complies with Spec 011 Zsh Optimization (zero forks on hot path, hoisted modules).

### Performance Metrics

- Plugin load time: ~8ms (budget < 50ms).
- History query time: ~0.1ms (budget < 10ms).
- Zero forks in hot-path.

### Testing & CI

- 29 test suites with 100% pass rate.
- Cross-platform CI verified on Ubuntu and macOS runners.

### Breaking Changes

None — initial stable release.

---

## [v0.9.0] — Loading Indicator, Zoxide Integration & Benchmarks (2026-10-16)

### Added
- **Pure-Zsh Loading Indicator (`ui/loading.ui.zsh`)**:
  - Zero-fork, ultra-lightweight indicator designed for RPROMPT and terminal redraws.
  - Spec 011 compliant: ~0.1ms overhead, zero Python, zero subprocess forks.
  - Threshold-gated (default: 200ms) so fast queries remain completely silent.
  - Three distinct visual styles: `minimal` (⏳), `spinner` (Braille frames), and `text` (operation label).
  - Configurable via `[ui.loading]` section in `ghost.conf`.
- **Zoxide Directory Suggestion Source (`sources/zoxide.source.zsh`)**:
  - Ingests directory frecency database directly from `zoxide`.
  - Registered with IOP: weight 15, kind `path`.
  - Triggers on `cd ` prefix or bare `cd`, proposing matching directories.
  - Graceful no-op fallback if zoxide is not installed.
- **Helper Jump Shortcut (`lib/helpers.zsh`)**:
  - Provides `j` command and alias for fast fuzzy directory switching.
  - Interactive mode with real-time directory listing preview when `fzf` is available.
- **Comprehensive Benchmarks & Quality Suites (`tests/test_benchmarks.zsh`)**:
  - Hot-path plugin load measured under 10ms (well within 50ms ceiling).
  - History query speed measured under 0.1ms (well within 10ms ceiling).
  - Static audit verifying zero external forks in hot-path files.
- **Developer Documentation**:
  - `docs/LOADING-INDICATOR.md`: Complete guide on loading indicator styles and RPROMPT hooks.
  - `docs/ZOXIDE-INTEGRATION.md`: Guide to zoxide suggestion source and `j` helper shortcut.
- **Test Suites (29 Suites Total)**:
  - `tests/test_loading_indicator.zsh` (8 test cases)
  - `tests/test_zoxide_source.zsh` (6 test cases)
  - `tests/test_helper_j.zsh` (3 test cases)
  - `tests/test_benchmarks.zsh` (3 benchmark cases)

## [v0.8.0] — Contract Safety, Preview Pane & Documentation Window (2026-10-16)

### Added
- **Contract-Based Safety Enforcement (`core/ghost-registry.zsh`, `core/ghost-core.zsh`)**:
  - Replaces fork-based timeout with pure-Zsh contract enforcement (Spec 011 zero-forks).
  - Custom sources declare `max_suggestions` and `timeout_ms` directly in `ghost.conf`.
  - Missing contract defaults to safe limits (50 suggestions, 100ms) with a warning.
  - Contract violations handled gracefully: exceeding `timeout_ms` discards candidates, exceeding `max_suggestions` truncates the array.
  - Structured accountability metrics tracked per source: `calls`, `avg_ms`, `max_ms`, `last_ms`, `timeout_violations`, `truncations`.
  - New inspection and reset APIs: `ghost_source_stats`, `ghost_all_source_stats`, `ghost_source_stats_reset`.
- **Interactive Preview Pane (`ui/preview.ui.zsh`, `ui/popup.ui.zsh`)**:
  - Live metadata preview pane rendered on the right side of `fzf` popup (`Ctrl-G`).
  - Displays formatted suggestion text, kind badge with icon, origin source, scoring weight, and frecency score.
  - Layout toggle bound to `Ctrl-/` (cycles through `down:40%`, `right:50%`, and `hidden`).
  - Configuration section `[ui.preview]` in `ghost.conf`.
- **Documentation Window (`lib/docs_extractor.py`, `ui/docs.ui.zsh`)**:
  - Instant command documentation extraction via `Ctrl-D` toggle in the popup menu.
  - Cold-path Python extractor querying `tldr`, `man -P cat`, or `--help` with strict 3-second timeout.
  - TTL-based file cache in `~/.cache/ziro/ghost/docs/` with configurable 24-hour expiration (`[ui.docs] cache_ttl = 86400`).
  - Configuration section `[ui.docs]` in `ghost.conf`.
- **Developer Guides**:
  - `docs/PREVIEW-AND-DOCS.md`: Complete guide to preview configuration, keybindings, and documentation window.
  - `docs/CUSTOM-SOURCES.md`: Updated with contract-based safety guidelines and infinite loop caveats.
- **Comprehensive Test Suites (25 Suites Total)**:
  - `tests/test_contract_enforcement.zsh` (6 test cases)
  - `tests/test_source_stats.zsh` (4 test cases)
  - `tests/test_preview.zsh` (2 test cases)
  - `tests/test_docs_extractor.zsh` (4 test cases)

## [v0.7.0] — Custom Source API & Safety Guards (2026-10-16)

### Added
- **Config-Driven Custom Source Parser (`core/ghost-config.zsh`)**:
  - Full TOML parsing for `[[sources]]` arrays of tables.
  - Supports fields: `name`, `handler`, `weight`, `kind`, `enabled`, `fallback_only`, `intent`.
  - Supports handlers as Zsh function names or external `.zsh` file paths with `~` home directory expansion.
- **Custom Source Lifecycle & Management (`core/ghost-registry.zsh`)**:
  - `ghost_load_custom_sources`: Loads custom sources, sources handler files, auto-detects handler functions, and enforces built-in source conflict prevention.
  - `ghost_reload_custom_sources`: Dynamically reloads and re-registers custom sources at runtime.
  - `ghost_unregister_source`: Safely unregisters sources by name.
  - `ghost_source_info`: Displays formatted metadata for any registered source.
  - `ghost_custom_sources_list`: Returns the list of registered custom sources.
- **Handler Timeout & Error Isolation Guards (`core/ghost-core.zsh`)**:
  - Configurable execution timeout via `[safety] handler_timeout_ms = 50`. Handlers exceeding this threshold are automatically discarded to preserve prompt responsiveness.
  - Complete error isolation: crashing or non-zero exiting handlers are silenced and cannot break ZLE or other sources.
  - Automatic candidate format normalization (`weight:kind:text`).
- **Developer Documentation & Guides**:
  - `docs/CUSTOM-SOURCES.md`: Comprehensive guide for creating declarative and file-based custom sources.
  - `docs/examples/work-source.zsh`: Full working reference example for team-specific command suggestions.
- **Comprehensive Test Suites**:
  - `tests/test_custom_source_config.zsh`: 5 test cases testing empty tables, single/multiple sources, disabled sources, and path resolution.
  - `tests/test_custom_source_register.zsh`: 5 test cases testing function handlers, file handlers, built-in name collisions, and fallback propagation.
  - `tests/test_custom_source_pipeline.zsh`: 4 test cases testing pipeline participation, fallback execution, crash isolation, and execution timeouts.
  - `tests/test_public_api.zsh`: 4 test cases testing unregistration, metadata retrieval, custom filtering, and duplicate warning.

## [v0.6.0] — Typo Correction Engine (2026-10-16)

### Added
- **Typo Correction Suggestion Source (`sources/typo.source.zsh`)**:
  - Multi-layered correction engine complying with Spec 009 R18:
    * Layer 1: High-speed static typo map (over 30 frequent shell, git, docker, and package manager typos).
    * Layer 2: Algorithmic checks against common commands including Damerau adjacent-character transposition detection.
    * Layer 3: QWERTY keyboard-distance heuristic matching adjacent key slip-ups.
    * Layer 4: Pure-Zsh bounded Levenshtein distance algorithm (max bound 2, zero forks).
  - Registered with IOP: weight 5, kind `typo`, flag `--fallback-only`.
- **Two-Tier Source Pipeline (`core/ghost-core.zsh`)**:
  - Implemented primary vs fallback-only source dispatch: fallback sources only trigger if primary sources return 0 candidate suggestions.
- **IOP Registry Flag Extension (`core/ghost-registry.zsh`)**:
  - Added `--fallback-only` parameter to `ghost_register_source` and exposed it via `ghost_get_source`.
- **Configuration Section `[correction]` (`core/ghost-config.zsh`)**:
  - Integrated `correction.enabled`, `correction.mode` (`suggest`/`off`), `correction.max_edit_distance`, and `correction.keyboard_distance`.
- **Automated Test Suites**:
  - `tests/test_levenshtein.zsh`: 6 test cases verifying DP matrix correctness, insertions, substitutions, early bounded termination, and length filters.
  - `tests/test_typo_source.zsh`: 8 test cases verifying static map lookups, algorithmic transposition, keyboard distance, Levenshtein distance, and configuration disabling.
  - `tests/test_fallback_pipeline.zsh`: 4 test cases testing primary source precedence, fallback invocation on empty queries, and popup rendering of typo results.

## [v0.5.0] — Zsh Completions Bridge & Subcommand Support (2026-10-16)

### Added
- **Zsh Completions Bridge Source (`sources/completions.source.zsh`)**:
  - Bridges native Zsh completion system into ghost suggestion pipeline via isolated `compadd` function interception.
  - Intercepts candidates from standard completion functions (`_git`, `_docker`, `_uv`, etc.).
  - Registered with IOP: weight 10, kind `cmd`.
- **Subcommand Suggestion Source (`sources/subcommand.source.zsh`)**:
  - High-performance static subcommand tables for major developer CLI tools: `git`, `docker`, `kubectl`, `uv`, `pnpm`, `npm`, `yarn`, `cargo`, `go`, `pip`, and `brew`.
  - Dynamic subcommand extraction fallback via completion functions.
  - Registered with IOP: weight 10, kind `cmd`.
- **Comprehensive Test Suites**:
  - `tests/test_completions_source.zsh`: 4 test cases verifying IOP registration, graceful failure on uninitialized compinit, and compadd capture.
  - `tests/test_subcommand_source.zsh`: 5 test cases testing static table retrieval, prefix matching, unknown command handling, and duplicate elimination.
  - `tests/test_integration_multisource.zsh`: 3 test cases testing multi-source merging, weight-based ranking, and coexistence of project & subcommand sources.

### Changed
- **Calibrated Source Weights (Spec 009 R14)**:
  - Adjusted `project` source weight from 50 to 30 to strictly align with Spec 009 R14 hierarchy (`history` 40, `project` 30, `subcommand` 10, `completions` 10).

## [v0.4.0] — Project Markers Detection (2026-10-16)

### Added
- **Project Markers Detection Helper (`lib/project_markers.py`)**:
  - Cold-path Python detector identifying project types and recommended command recipes.
  - Ecosystem support: Python (`pyproject.toml`, `requirements.txt`), Node (`package.json`), Rust (`Cargo.toml`), Go (`go.mod`), Ruby (`Gemfile`), PHP (`composer.json`), Make (`Makefile`), Docker (`docker-compose.yml`, `Dockerfile`), just (`justfile`), and Git (`.git`).
  - Strict cold-path isolation: never invoked during hot-path shell startup.
- **Project Suggestion Source (`sources/project.source.zsh`)**:
  - Registered IOP source with kind `project` and weight 50.
  - Dual-tier caching: in-memory cache + persistent per-directory disk cache (`~/.cache/ziro/ghost/project-cache/*.json`).
  - Automatic cache invalidation based on marker file modification time (`mtime`).
- **ZLE Lifecycle Integration (`core/ghost-core.zsh`)**:
  - Added `_ghost_on_chpwd` hook attached to `chpwd` to instantly clear in-memory project caches when switching directories.
- **Automated Test Suites**:
  - `tests/test_project_markers.zsh`: 5 test cases verifying multi-language marker detection and empty directory handling.
  - `tests/test_project_cache.zsh`: 4 test cases testing cache creation, cache hits without Python re-execution, `chpwd` invalidation, and mtime refresh.
  - `tests/test_project_source.zsh`: 3 test cases testing IOP registration, prefix filtering, and result formatting.

## [v0.3.0] — Popup Menu, Tab Navigation & Quality Fixes (2026-10-16)

### Added
- **Interactive Popup Menu & Fallback (`ui/popup.ui.zsh`)**:
  - Full fzf integration with `--bind="tab:down,btab:up"` for seamless Tab/Shift-Tab cycling.
  - Native ZLE fallback menu when fzf is absent with numeric and Tab cycling.
  - Accurate raw buffer insertion without text corruption via tab-separated tokens.
  - Kind icon and label decoration in popup list (`[icon] text │ kind │ source`).
- **Comprehensive Test Suites**:
  - `tests/test_popup.zsh`: fzf availability, native fallback rendering, and buffer updating.
  - `tests/test_tab_navigation.zsh`: Tab/Shift-Tab selection stepping and keybinding registration.
  - `tests/test_comparator.zsh`: Pure-Zsh scoring, kind bias, and zero-fork ranking.
  - `tests/test_hotpath_quality.zsh`: Spec 011 static checks, module hoisting, and `emulate -L zsh`.
- **Handoff Mechanism (`.specify/HANDOFF.md`)**: Full project identity, roadmap, architecture, test status, and cross-project references.

### Changed & Optimized (Spec 011 Compliance)
- **Local Shell Emulation**: Added `emulate -L zsh` across all 39 functions in `core/`, `ui/`, `engine/`, and `sources/`.
- **Module Hoisting**: Hoisted `zmodload zsh/datetime` and `zmodload zsh/mapfile` to file headers.
- **Zero-Fork Candidate Pipeline**:
  - Replaced subshell execution in `_ghost_compute` with global array returns.
  - Replaced external `sort` in comparator with pure Zsh numerical sorting `${(@On)scored}`.
  - Replaced `cat | tail` in history source with `zmodload zsh/mapfile` array slice `[-2000,-1]`.
- **Contextual Kind Bias**: Connected `ghost_score_candidate` to ranking pipeline with git repository awareness.
- **Disk Cache**: Added mtime-invalidated disk cache for history entries (`~/.cache/ziro/ghost/history-cache`).

## [v0.2.0] — Initial Skeleton Release (2026-10-16)

### Added
- **Plugin Entry Point (`ghost.plugin.zsh`)**: Standalone Zsh plugin architecture compliant with Constitution Principle XIV (Plugin Sovereignty).
- **Semantic Kind System (`core/ghost-kinds.zsh`)**:
  - 12 default kinds (`git`, `cmd`, `path`, `dir`, `file`, `alias`, `var`, `func`, `history`, `project`, `typo`, `snippet`).
  - Automatic Nerd Font detection with clean ASCII fallback.
  - Per-kind icon, color, and label registration and user overrides.
  - Strict compliance with `NO_COLOR` standard.
- **IOP Module Registry (`core/ghost-registry.zsh`)**: Open registration model for sources, UI engines, matchers, and comparators.
- **Configuration Engine (`core/ghost-config.zsh`)**: TOML configuration parsing with `zstyle` hot-path fallback.
- **ZLE Lifecycle Coordinator (`core/ghost-core.zsh`)**: Native `POSTDISPLAY` hook and keybinding widgets (`Right`, `Ctrl-F`, `Ctrl-G`, `Esc`).
- **Matching & Comparator Engine (`engine/`)**: Prefix/fuzzy matching and score ranking with kind-aware bias.
- **UI Renderers (`ui/`)**: Inline ghost text and fzf-powered interactive popup menu.
- **First Suggestion Source (`sources/history.source.zsh`)**: In-memory and persistent shell history aggregation.
- **Project Markers Helper (`lib/project_markers.py`)**: Skeleton for contextual project command detection.
- **Automated Test Suite (`tests/`)**: Automated test scripts for plugin load, kind system, registry, and configuration.
- **Continuous Integration (`.github/workflows/test.yml`)**: Multi-OS test matrix (Ubuntu + macOS).
- **Documentation (`docs/`)**: Full guides for Architecture, Kind System, Configuration, and README.
