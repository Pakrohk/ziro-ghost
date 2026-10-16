# Changelog

All notable changes to `ziro-ghost` are documented here.

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
