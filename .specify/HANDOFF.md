# Handoff — ziro-ghost

Generated: 2026-10-16

## Project Identity
- **Name**: ziro-ghost
- **Purpose**: IDE-like autocomplete for Zsh (standalone plugin)
- **Repository**: https://github.com/Pakrohk/ziro-ghost
- **License**: MIT
- **Principle**: Principle XIV (Plugin Sovereignty — fully decoupled standalone repository)

## Current Version
- **Latest**: v0.3.0 (this milestone)
- **Previous**: v0.2.0 (skeleton + kind system)

## Roadmap
| Version | Content | Status |
|---|---|:---:|
| **v0.2.0** | Skeleton + kind system + history source | ✅ released |
| **v0.3.0** | Popup + Tab navigation + quality fixes (Spec 011) | ✅ released (this) |
| **v0.4.0** | Project markers detection (Python integration) | planned |
| **v0.5.0** | zsh-completions + subcommand support | planned |
| **v0.6.0** | Typo correction | planned |
| **v0.7.0** | Custom source API | planned |
| **v0.8.0** | Preview pane + docs window | planned |
| **v0.9.0** | Benchmarks + optimization | planned |
| **v1.0.0** | Stable — ready for ziro-shell integration | planned |

## Architecture
- **Entry point**: `ghost.plugin.zsh` (standalone sourceable)
- **Core (`core/`)**:
  - `ghost-registry.zsh`: IOP module registry (sources, uis, matchers, comparators)
  - `ghost-config.zsh`: Hybrid config engine (TOML + zstyle + compiled defaults)
  - `ghost-kinds.zsh`: 12-kind semantic styling & icon renderer (Nerd font / ASCII)
  - `ghost-core.zsh`: Core ZLE lifecycle, hooks, and widget coordinator
- **Sources (`sources/`)**: Pluggable suggestion providers (`history.source.zsh`, etc.)
- **Engine (`engine/`)**: Matcher (`matcher.zsh`) and pure-Zsh comparator (`comparator.zsh`)
- **UI (`ui/`)**: Inline POSTDISPLAY (`inline.ui.zsh`) and interactive popup menu (`popup.ui.zsh`)
- **Lib (`lib/`)**: Optional helper enrichment tools (`project_markers.py`)

## Test Status
- **Suites**: 8 suites
- **Last run**: 2026-10-16 — all passing
- **Suites list**:
  - `tests/test_plugin_load.zsh`
  - `tests/test_kinds.zsh`
  - `tests/test_registry.zsh`
  - `tests/test_config.zsh`
  - `tests/test_popup.zsh`
  - `tests/test_tab_navigation.zsh`
  - `tests/test_comparator.zsh`
  - `tests/test_hotpath_quality.zsh`

## Key Decisions
- **ADR-006**: Hybrid configuration model (TOML on cold-path, zstyle on hot-path).
- **ADR-009**: Code style guide — function-based, idiom-first, strict scoping.
- **Spec 011**: Zsh optimization rules — zero forks on hot path, hoisted modules, pure-Zsh ranking.
- **Spec 009**: Ghost functional specifications (FR-001 through FR-010, R11 through R18).

## Cross-Project References
- **ziro-shell**: https://github.com/Pakrohk/ziro-shell
- `ziro-ghost` is planned to integrate into `ziro-shell` v1.1.3 after reaching v1.0.0.

## Next Steps
- **v0.4.0**: Project markers detection and project-aware suggestions.

## Known Issues
- None. All 7 audit quality issues from v0.2.0 resolved in v0.3.0.
