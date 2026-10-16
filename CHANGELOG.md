# Changelog

All notable changes to `ziro-ghost` are documented here.

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
