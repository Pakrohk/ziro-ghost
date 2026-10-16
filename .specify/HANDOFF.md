# Handoff — ziro-ghost

Generated: 2026-10-16

## Project Identity
- **Name**: ziro-ghost
- **Purpose**: IDE-like autocomplete for Zsh (standalone plugin)
- **Repository**: https://github.com/Pakrohk/ziro-ghost
- **License**: MIT
- **Principle**: Principle XIV (Plugin Sovereignty — fully decoupled standalone repository)

## Current Version
- **Latest**: v0.9.0 (this milestone)
- **Previous**: v0.8.0 (preview pane, docs window, contract safety)

## Roadmap
| Version | Content | Status |
|---|---|:---:|
| **v0.2.0** | Skeleton + kind system + history source | ✅ released |
| **v0.3.0** | Popup + Tab navigation + quality fixes (Spec 011) | ✅ released |
| **v0.4.0** | Project markers detection (Python integration) | ✅ released |
| **v0.5.0** | zsh-completions bridge + subcommand support | ✅ released |
| **v0.6.0** | Typo correction engine (Spec 009 R18) | ✅ released |
| **v0.7.0** | Custom Source API & Safety Guards (Spec 009 R17) | ✅ released |
| **v0.8.0** | Preview pane + docs window + contract safety | ✅ released |
| **v0.9.0** | Pure-Zsh Loading Indicator + Zoxide Integration + Benchmarks | ✅ released (this) |
| **v1.0.0** | Stable — ready for ziro-shell integration | planned (next) |

## Architecture
- **Entry point**: `ghost.plugin.zsh` (standalone sourceable)
- **Core (`core/`)**:
  - `ghost-registry.zsh`: IOP module registry with contract safety validation (`max_suggestions`, `timeout_ms`) and source stats API
  - `ghost-config.zsh`: Hybrid config engine (TOML + zstyle + compiled defaults) with `[ui.preview]`, `[ui.docs]`, and `[ui.loading]` support
  - `ghost-kinds.zsh`: 12-kind semantic styling & icon renderer (Nerd font / ASCII)
  - `ghost-core.zsh`: Core ZLE lifecycle, contract-based enforcement (zero forks), stats tracking, two-tier pipeline, and widget coordinator
- **Sources (`sources/`)**: Pluggable suggestion providers:
  - `history.source.zsh`: In-memory & persistent history with mtime disk cache (weight 40)
  - `project.source.zsh`: Project-aware ecosystem detection & recipes (weight 30)
  - `subcommand.source.zsh`: Fast static CLI tables + dynamic subcommand extraction (weight 10)
  - `completions.source.zsh`: Native zsh-completions bridge via `compadd` wrapper (weight 10)
  - `zoxide.source.zsh`: Frecency directory suggestion source via zoxide (weight 15, kind `path`)
  - `typo.source.zsh`: Bounded Levenshtein, Damerau transposition, keyboard distance, and static map (fallback-only, weight 5)
  - User-defined custom sources loaded via `[[sources]]` tables or IOP registry with contract safety
- **Engine (`engine/`)**: Matcher (`matcher.zsh`) and pure-Zsh comparator (`comparator.zsh`)
- **UI (`ui/`)**:
  - `inline.ui.zsh`: Inline POSTDISPLAY ghost suggestion
  - `popup.ui.zsh`: Interactive popup menu with fzf / native fallback, preview toggle, docs toggle
  - `preview.ui.zsh`: Structured metadata preview renderer
  - `docs.ui.zsh`: Command documentation renderer bridge
  - `loading.ui.zsh`: Pure Zsh zero-fork loading indicator (⏳, Braille spinner, text label)
- **Lib (`lib/`)**: Optional cold-path enrichment tools:
  - `project_markers.py`: Marker detection helper
  - `docs_extractor.py`: tldr/man/--help doc extractor with 3s timeout and TTL file cache
  - `helpers.zsh`: Shell shortcuts (`j` jump command with fzf preview)
- **Docs (`docs/`)**: Architecture, kinds, custom sources, preview & docs, loading indicator, and zoxide integration

## Test Status
- **Suites**: 29 suites
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
  - `tests/test_project_markers.zsh`
  - `tests/test_project_cache.zsh`
  - `tests/test_project_source.zsh`
  - `tests/test_completions_source.zsh`
  - `tests/test_subcommand_source.zsh`
  - `tests/test_integration_multisource.zsh`
  - `tests/test_levenshtein.zsh`
  - `tests/test_typo_source.zsh`
  - `tests/test_fallback_pipeline.zsh`
  - `tests/test_custom_source_config.zsh`
  - `tests/test_custom_source_register.zsh`
  - `tests/test_custom_source_pipeline.zsh`
  - `tests/test_public_api.zsh`
  - `tests/test_contract_enforcement.zsh`
  - `tests/test_source_stats.zsh`
  - `tests/test_preview.zsh`
  - `tests/test_docs_extractor.zsh`
  - `tests/test_loading_indicator.zsh`
  - `tests/test_zoxide_source.zsh`
  - `tests/test_helper_j.zsh`
  - `tests/test_benchmarks.zsh`

## Key Decisions
- **ADR-006**: Hybrid configuration model (TOML on cold-path, zstyle on hot-path).
- **ADR-009**: Code style guide — function-based, idiom-first, strict scoping.
- **Spec 011**: Zsh optimization rules — zero forks on hot path, hoisted modules, pure-Zsh ranking.
- **Spec 009**: Ghost functional specifications (FR-001 through FR-010, R11 through R18).
  - R11: Popup menu and preview pane.
  - R14: Source weights strictly calibrated (history 40, project 30, zoxide 15, subcommand 10, completions 10, typo 5).
  - R17: Custom Source API with Contract-Based Safety (max_suggestions + timeout_ms) and source stats API.
  - FR-005 / Spec 011: Pure Zsh loading indicator (zero forks, ~0.1ms overhead, threshold-gated at 200ms).
  - FR-007: Zoxide frecency integration with directory propositions on `cd`.
  - FR-009: Documentation window querying tldr/man/--help with cold-path caching.
  - FR-010: Benchmarks verifying hot-path load < 50ms (measured ~8ms) and query < 10ms (measured ~0.1ms).

## Cross-Project References
- **ziro-shell**: https://github.com/Pakrohk/ziro-shell
- `ziro-ghost` is planned to integrate into `ziro-shell` v1.1.3 after reaching v1.0.0.

## Next Steps
- **v1.0.0**: Stable Release (Final polish, readiness for ziro-shell v1.1.3 integration).

## Known Issues
- None. All 29 test suites passing green; zero forks on hot-path verified.
