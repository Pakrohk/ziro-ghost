# Rules for Spec 009 v2.0.0 — Ziro Ghost

**Rules ID**: `009-RULES`  
**Version**: 1.0.0  
**Parent Spec**: `Spec 009 (v2.0.0)` — `.specify/specs/009-ziro-ghost-plugin/spec.md`  
**Created**: 2026-10-17  
**Status**: Active  
**Applies to**: `ziro-ghost` v2.0.0 implementation, code reviews, and CI test pipelines  
**Enforcement**: Automated CI gates + peer review verification  

---

## Overview

This document defines the **NON-NEGOTIABLE** engineering rules for implementing `ziro-ghost` Spec 009 v2.0.0. These rules bridge the conceptual architecture of the specification and day-to-day implementation work. Any pull request that breaches these rules will be rejected unless the rule itself is formally amended via the process described in Section 20.

---

## Rule 1 — Code Organization

- **R1.1 — Frozen Directory Structure**: The repository layout of `ziro-ghost` is strictly frozen to the following top-level directories:
  - `core/`: ZLE lifecycle, configuration engine, kind definitions, and module registry.
  - `sources/`: All candidate suggestion sources (`history`, `project`, `zoxide`, `typo`, etc.).
  - `ui/`: User interface layers (`inline`, `completion`, `preview`, `docs`, `loading`).
  - `engine/`: Ranking, string matching, comparator, and strategy resolution engines.
  - `lib/`: Pure utility helpers and marker classifiers.
  - `bin/`: Standalone companion binaries (specifically `bin/ghost-popup/` for Rust Focus Mode).
  - `config/`: Compiled fallback configuration (`default.conf`).
  - `themes/`: Palette definitions (`catppuccin-mocha.toml`, `tokyo-night.toml`, etc.).
  - `tests/`: Automated test suites and benchmark harnesses.
  - `docs/`: Technical manuals, API contracts, and user guides.
- **R1.2 — Directory Immutability**: No new top-level directories may be created without a formal spec amendment.
- **R1.3 — Namespace Prefixing**: Every `.zsh` file must export functions matching its directory domain:
  - `core/ghost-*.zsh` ➔ `_ghost_*`
  - `sources/*.zsh` ➔ `_ghost_source_*`
  - `ui/*.zsh` ➔ `_ghost_ui_*`
  - `engine/*.zsh` ➔ `_ghost_engine_*`
  - Public interface functions exposed to end-users ➔ `ghost_*`
- **R1.4 — Single Responsibility per File**: Each file must own exactly one logical concern. `core/ghost-config.zsh` parses and provides configuration only; it must not contain rendering logic or source queries.
- **R1.5 — Rust Companion Placement**: The source code for the Focus Mode Rust binary must reside strictly in `bin/ghost-popup/` with its own standard `Cargo.toml`.

---

## Rule 2 — Naming Conventions

- **R2.1 — Zsh Identifiers**: Function names and internal global variables must use `snake_case`. Private/internal symbols must begin with `_ghost_`; public API entry points must begin with `ghost_`.
- **R2.2 — Rust Identifiers**: Rust types, structs, and traits must use `UpperCamelCase`. Functions, methods, modules, and variables must use `snake_case`. Constants must use `SCREAMING_SNAKE_CASE`.
- **R2.3 — Source Identifiers**: Source names must use `snake_case` or `kebab-case` without spaces or uppercase letters (e.g., `history`, `project`, `lang_help`, `sys_comment`).
- **R2.4 — Semantic Kinds**: Kind names must be single lowercase words (e.g., `git`, `cmd`, `path`, `dir`, `file`, `alias`, `var`, `func`, `hist`, `proj`, `typo`, `snip`).
- **R2.5 — Configuration Keys**: All TOML section names and property keys in `ghost.conf` must use `snake_case` (e.g., `max_suggestions`, `timeout_ms`, `partial_render`).
- **R2.6 — Version String Format**: Version numbers must follow strict Semantic Versioning (`MAJOR.MINOR.PATCH`).
- **R2.7 — Theme Preset Identifiers**: Theme names must use lowercase `kebab-case` matching their upstream ecosystem names (e.g., `catppuccin-mocha`, `tokyo-night`, `gruvbox`).

---

## Rule 3 — Hot-Path Discipline

*Source Reference: Spec 009 §R1, §10; Spec 011 (Zsh Optimization)*

- **R3.1 — Emulation Guard**: Every function that executes during the keystroke lifecycle (`line-pre-redraw` and source handlers) MUST include `emulate -L zsh` as its very first executable line.
- **R3.2 — Zero Process Forks**: Under no circumstances may an external process fork (`cat`, `grep`, `sed`, `awk`, `date`, `head`, `tail`, `wc`, `cut`, `tr`, `python`, etc.) be spawned on the hot path. Any process spawning on typing is a critical defect.
- **R3.3 — No Subshell Overhead**: Command substitutions `$(...)` and backticks `` `...` `` are strictly forbidden within hot-path handlers and renderers. Zsh native parameter expansions (`${var#prefix}`, `${var:u}`, `${(s/:/)var}`, etc.) must be used instead.
- **R3.4 — Zero Disk Syscalls on Keystroke**: Source handlers must never execute synchronous disk reads or file opens while the user is typing. All dataset lookups (history lists, project marker caches) must be pre-loaded into associative arrays in memory.
- **R3.5 — Keystroke Budget Enforcement**: Total keystroke processing latency across all primary sources and the inline renderer must not exceed `3.0ms`. An individual source handler must not exceed its configured `timeout_ms`.
- **R3.6 — Module Hoisting**: Calls to `zmodload` (e.g. `zsh/datetime`, `zsh/mapfile`) must be executed once at file load time, never inside function bodies.
- **R3.7 — CI Static Check**: CI must run static grep audits on all hot-path files (`core/ghost-core.zsh`, `engine/*.zsh`, `ui/inline.ui.zsh`, `sources/*.zsh`). Any detected fork pattern will immediately block merge.

---

## Rule 4 — Source Handler Contract

*Source Reference: Spec 009 §6 Layer 7*

- **R4.1 — Uniform Signature**: Every source handler must be implemented as a single Zsh function named `_ghost_source_<name>`.
- **R4.2 — Argument Handling**: The handler must accept the active query string as `$1`.
- **R4.3 — Output Arrays**: The handler must assign its candidates to the global array `_ghost_results` (and optional metadata strings to `_ghost_result_metadata`). The handler must initialize both arrays as empty before querying.
- **R4.4 — Zero Output Leakage**: Handlers must never write to standard output or standard error. The engine wraps invocations with `>/dev/null 2>&1`, but any direct `print` or `echo` inside a handler is considered an implementation defect.
- **R4.5 — Standardized Return Codes**: The handler must return `0` if one or more valid candidates were added to `_ghost_results`. If no matches were found or a handled failure occurred, it must return a non-zero exit code (e.g. `1`).
- **R4.6 — State Isolation**: A source handler must not modify any shell environment variables, user options, or ZLE buffer states outside its own local scope and the output arrays.
- **R4.7 — Hard Timeout Guard**: Handlers that exceed their allotted `timeout_ms` will be aborted by the execution scheduler, flagged with status `timeout`, and skipped for the current keystroke.
- **R4.8 — Unified Registration**: Handlers must be registered through `ghost_register_source`. Direct manual manipulation of core registry arrays is prohibited.

---

## Rule 5 — Declarative Configuration Discipline

*Source Reference: Spec 009 §P2, §8*

- **R5.1 — Zero Hardcoded Parameters**: Visual colors, score weights, timeouts, thresholds, and keybindings must never be hardcoded into `.zsh` or `.rs` files. They must be resolved dynamically from the configuration engine.
- **R5.2 — Default Value Guarantee**: Every configuration key must possess a documented, sensible default declared in `$GHOST_HOME/config/default.conf`.
- **R5.3 — Schema Evolution**: Additions to the configuration schema require a SemVer minor bump. Changes that rename or remove existing keys are breaking changes and require a SemVer major bump.
- **R5.4 — Strict Validation**: The config parser must validate field types, enum values, and dependency declarations during initialization.
- **R5.5 — Non-Crashing Resilience**: A syntax error or invalid value in user configuration must emit an informative warning to `stderr` and fallback to the compiled default value. The shell must never crash or refuse to boot due to an invalid configuration file.
- **R5.6 — Precedence Order**: Configuration must resolve in strict order:
  `~/.config/ziro/ghost.conf` (User) ➔ `$GHOST_HOME/config/default.conf` (Plugin) ➔ Compiled In-Memory Defaults.

---

## Rule 6 — Source Equality Enforcement

*Source Reference: Spec 009 §P1*

- **R6.1 — Identical Registration API**: Built-in sources (`history`, `project`, `zoxide`, `typo`, etc.) and user-authored custom sources must register through the exact same function: `ghost_register_source`.
- **R6.2 — Zero Private Bypasses**: The engine must not implement special `if [[ "$source" == "history" ]]` branches that bypass standard ranking, timeout, or formatting pipelines.
- **R6.3 — Symmetrical Schema**: Every source exposes the identical 7-layer configuration block in `ghost.conf`.
- **R6.4 — Total User Overridability**: Users must be able to override any attribute (weight, display label, color mode, timeout, documentation) of any built-in source via `ghost.conf`.
- **R6.5 — Total Disablability**: Users must be able to completely disable any built-in source (including `history`) by setting `enabled = false`.
- **R6.6 — CI Test for Disabling**: The test suite must assert that setting `[sources.history] enabled = false` removes all history suggestions from the pipeline.
- **R6.7 — CI Test for User Priority**: The test suite must assert that a user source configured with `weight = 100` ranks strictly higher than built-in sources.

---

## Rule 7 — Strategy Engine Rules

*Source Reference: Spec 009 §7*

- **R7.1 — Deterministic Evaluation**: Strategy conditions (`requires_present`, `requires_absent`, `requires_success`, `requires_failed`) must be evaluated in the exact order defined in Spec 009 §R16.
- **R7.2 — State Machine Lifecycle**: The execution state of each source during a query must be recorded as one of: `success`, `empty`, `timeout`, `crash`, `skipped`, or `disabled`.
- **R7.3 — Contradiction Auditing**: If a source declares mutually exclusive conditions (e.g. `requires_present = ["foo"]` and `requires_absent = ["foo"]`), the configuration engine must print a warning at startup and mark the source as `disabled`.
- **R7.4 — Circular Dependency Guard**: Dependency graphs among sources must be checked for cycles during initialization. Detected cycles must be reported and broken by disabling the dependent source.
- **R7.5 — Deprecation of `fallback_only`**: The legacy v1.0.x flag `fallback_only = true` is deprecated. Handlers must use `strategy = "fallback"`.
- **R7.6 — Idempotent Expansions**: Expanding shorthand strategies into explicit condition lists must be idempotent; running the expansion multiple times on the same configuration must yield the identical state.

---

## Rule 8 — Layer Separation Rules

*Source Reference: Spec 009 §P3, §3*

- **R8.1 — Hot-Path Isolation**: Layer 1 (Zsh) must never spawn or interact with the Layer 2 Rust binary during keystroke handling or Ghost Line rendering.
- **R8.2 — Trigger Discipline**: Layer 2 (Rust) must be executed if and only if the user invokes the interactive completion trigger (`ghost-focus` / `Tab`).
- **R8.3 — Clean Channel Protocol**: Zsh ↔ Rust IPC uses stdin/stdout NDJSON. No sockets, no shared memory, no temp files.
- **R8.4 — Per-Shell Sidecar Lifecycle**: The `ghost-popup` process is a per-shell sidecar. Spawns on first Tab press (or `[rust] prewarm = true` at Stage 2). Lives as long as the shell session. Exits on shell exit, SIGTERM, or `[rust] enabled = false`. NO global daemon, NO systemd unit, NO UNIX socket. This is NOT a service.
- **R8.5 — Process Guard**: If sidecar is unresponsive for > 5 seconds (no NDJSON response), the parent widget MUST kill it (SIGTERM) and fall back to native popup for the rest of the session.
- **R8.6 — Unidirectional State Flow**: Zsh sends candidates and layout parameters to Rust; Rust returns the user's selected index and text. Zsh never inspects or manipulates internal Rust UI state.

---

## Rule 9 — Rust Binary Rules

*Source Reference: Spec 009 §3.3, §5*

- **R9.1 — Pinned Dependencies**: In `bin/ghost-popup/Cargo.toml`, all third-party crates must have exact versions specified (e.g. `ratatui = "0.28.1"`). Wildcards (`"*"`) or unpinned ranges are forbidden.
- **R9.2 — Headless Benchmarking Flag**: The binary must implement a `--bench` flag that performs synthetic layout and differential diff passes without opening the terminal device.
- **R9.3 — Compatibility Flag**: The binary must implement a `--version` flag that returns the matching plugin version (e.g. `ghost-popup 2.0.0`).
- **R9.4 — Robust Input Handling**: The binary must handle invalid or truncated JSON on `stdin` gracefully, exiting with code `1` and logging to `stderr` without ever triggering a panic.
- **R9.5 — Alternate Screen Ban**: The binary must NEVER send `smcup` / `rmcup` escape sequences to the terminal. It must draw exclusively within the free space below the prompt using relative cursor positioning.
- **R9.6 — Differential Cell Diffing**: The binary must use double-buffering and redraw only cells whose glyph or color has changed since the previous frame.
- **R9.7 — `NO_COLOR` Compliance**: If the environment variable `NO_COLOR` is present, all color codes and `tachyonfx` animations must be completely disabled.
- **R9.8 — Signal Cleanliness**: The binary must catch `SIGINT` and `SIGTERM`, immediately restore terminal mouse and cursor modes, and exit cleanly with code `0`.
- **R9.9 — Rust Unit Test Coverage**: The Rust crate must provide comprehensive automated unit tests covering JSON serialization, layout constraints, item windowing, and differential rendering.

---

## Rule 10 — ziro-defer Staging Rules

*Source Reference: Spec 009 §9 R20*

- **R10.1 — Stage 0 Startup Budget**: The initial bootstrap contribution of `ziro-ghost` during shell startup must be `< 0.5ms`. It must do nothing more than register ZLE widget stubs and define `$GHOST_VERSION`.
- **R10.2 — File Size Limit for Bootstrap**: Any file sourced during Stage 0 must not exceed 100 lines of Zsh code.
- **R10.3 — Stage 1 First Keystroke**: The core engine, configuration loader, and primary sources must load during Stage 1 upon the first keystroke, with a latency budget `< 8.0ms`.
- **R10.4 — Stage 2 Idle Load**: Auxiliary UI helpers and documentation extractors must load asynchronously during Stage 2 after the first prompt has been drawn.
- **R10.5 — Stage 3 Focus Mode**: Spawning of the Rust Focus Mode binary as a per-shell sidecar must occur lazily on demand during Stage 3 when `Tab` is pressed.
- **R10.6 — Manifest Staging Declarations**: The root `ziro-plugin.toml` manifest must explicitly declare all loading stages in conformity with Spec 012.
- **R10.7 — Non-Fatal Budget Overruns**: If an environment exceeds a staging latency budget, the engine must log a warning to `~/.cache/ziro/ghost/errors.log`, but must never break shell initialization.

---

## Rule 11 — Testing Rules

*Source Reference: Spec 009 §11*

- **R11.1 — Source Unit Tests**: Every registered source must have a dedicated automated test suite located at `tests/test_source_<name>.zsh`.
- **R11.2 — Public API Verification**: All public functions prefixed with `ghost_*` must have unit test assertions verifying parameter validation and return codes.
- **R11.3 — End-to-End Integration Tests**: Automated tests must verify the entire pipeline: keystroke handling, fallback chain degradation, and Focus Mode handoff.
- **R11.4 — Performance Benchmarks in CI**: CI workflows must execute the automated benchmark suite on every pull request, verifying compliance with Spec 009 §10.
- **R11.5 — Code Coverage Minimums**: Pull requests must maintain a minimum of 80% line coverage for Zsh modules and 70% coverage for the Rust companion binary.
- **R11.6 — Rust Command Assertions**: The Rust binary must be tested using `assert_cmd` or `rexpect` to verify standard stream handling and exit status behavior.
- **R11.7 — Cross-Platform Matrix**: CI test runs must execute on both Linux (Ubuntu latest) and macOS (latest) runners.
- **R11.8 — Informative Failure Messages**: All test assertions must emit descriptive failure messages specifying what failed, the expected value, and the actual observed value.

---

## Rule 12 — Error Handling & Resilience

*Source Reference: Spec 009 §P5*

- **R12.1 — Source Fault Isolation**: A fatal error, crash, or infinite loop inside a single source handler must never crash the ZLE line editor or prevent other sources from executing.
- **R12.2 — Structured Error Logging**: All source exceptions, timeouts, and execution anomalies must be appended to `~/.cache/ziro/ghost/errors.log` in structured JSONL format.
- **R12.3 — JSONL Record Schema**: Each log entry must follow the schema:
  `{"ts": 1729123456, "source": "project", "error_type": "timeout", "message": "exceeded 50ms", "elapsed_ms": 52}`
- **R12.4 — Log File Rotation**: Error log files must be capped at 1MB or 1,000 lines; older records must be truncated automatically.
- **R12.5 — Rust Diagnostics**: Stderr emissions from the `ghost-popup` binary must be directed to `~/.cache/ziro/ghost/popup.log`.
- **R12.6 — Silent Degradation**: Fallback transitions (from Rust to Zsh native popup, or from popup to Ghost Line) must proceed silently without displaying interactive error popups.
- **R12.7 — Session Notification Rate Limiting**: If Focus Mode falls back to native mode, a single informational message may be logged once per shell session.

---

## Rule 13 — Config Versioning & Migration

*Source Reference: Spec 009 §8, §14*

- **R13.1 — Version Property Requirement**: Every valid configuration file must declare `config_version = "2.0.0"` within the `[meta]` section.
- **R13.2 — Release Synchronization**: The `config_version` property must match the major release version of the installed `ziro-ghost` plugin.
- **R13.3 — Mandatory Migration Tooling**: Any major release that alters key names or nesting must supply an automated migration utility (`ziro ghost migrate-config`).
- **R13.4 — Additive Minor Changes**: Minor releases may add new configuration keys with defaults, but must remain 100% backward-compatible with existing configuration files.
- **R13.5 — Lenient Key Handling**: The config parser must warn about unrecognized keys without terminating execution.
- **R13.6 — Automated Backup**: When running migration tools, the pre-existing configuration must be backed up with a timestamped extension (e.g. `ghost.conf.v1.backup`).
- **R13.7 — Migration Test Verification**: CI must maintain test cases that execute `migrate-config` against historical v1.0.x configuration files to confirm accurate conversion.

---

## Rule 14 — Plugin Sovereignty & Standalone Support

*Source Reference: Spec 009 §P6; Constitution Principle XIV*

- **R14.1 — Clean Environment Boot**: Sourcing `ghost.plugin.zsh` in a vanilla environment (`zsh -f`) must succeed with return code `0` and initialize full inline ghost text support.
- **R14.2 — Strict XDG Standards**: The plugin must use `$XDG_CONFIG_HOME/ziro/` and `$XDG_CACHE_HOME/ziro/ghost/`. It must never assume or require that `~/.ziro/` exists.
- **R14.3 — Zero Framework Coupling**: `ziro-ghost` must not call internal functions belonging to `ziro-shell` (symbols prefixed with `_ziro_*`).
- **R14.4 — Robust Path Resolution**: Plugin root resolution must inspect `$GHOST_HOME`, standard XDG directories, and `${${(%):-%x}:A:h}` in order.
- **R14.5 — Standalone CI Job**: CI must execute a test workflow that clones and runs `ziro-ghost` in complete isolation from the `ziro-shell` repository.
- **R14.6 — Framework Agnostic Packaging**: The plugin must remain installable through any standard Zsh plugin manager (`znap source`, `zinit load`, `antigen bundle`, `oh-my-zsh`).
- **R14.7 — Metadata Single Source**: Package metadata (version, license, author) must reside exclusively in `core/ghost-version.zsh` and `ziro-plugin.toml`.

---

## Rule 15 — Documentation Standards

*Source Reference: Spec 009 §16*

- **R15.1 — Standardized Function Headers**: Every public function and source handler must be preceded by a formatted header documenting intent, arguments, output variables, and failure modes.
- **R15.2 — Exhaustive Config Documentation**: Every configuration key must be documented with its data type, default value, and an example in `docs/CONFIG.md`.
- **R15.3 — Source Reference Guide**: All built-in sources must have an architectural reference in `docs/SOURCES.md` detailing strategy defaults and kind badges.
- **R15.4 — CLI Documentation**: The Rust binary's `--help` output must be kept in exact synchronization with `docs/CLI.md`.
- **R15.5 — Synchronized README**: Any change that modifies user-facing behavior, defaults, or keybindings must update `README.md`.
- **R15.6 — Structured Changelog**: Updates to `CHANGELOG.md` must follow Keep a Changelog formatting with entries categorized under `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, or `Security`.
- **R15.7 — Migration Guides**: Any breaking behavioral change must be accompanied by step-by-step upgrade documentation in `docs/MIGRATION.md`.

---

## Rule 16 — Git & Contribution Discipline

*Source Reference: ADR-007 (versioning), ADR-008 (per-plugin repos)*

- **R16.1 — Dedicated Repository**: All source code and issue tracking for `ziro-ghost` must occur within `Pakrohk/ziro-ghost`.
- **R16.2 — Branch Taxonomy**: Feature branches must strictly use established prefixes: `feat/`, `fix/`, `chore/`, `docs/`, `perf/`.
- **R16.3 — Conventional Commits**: Commit messages must adhere to Conventional Commits: `<type>(<scope>): <subject>`.
- **R16.4 — Annotated Release Tags**: Release tags must be created as annotated Git tags: `git tag -a vMAJOR.MINOR.PATCH -m "..."`.
- **R16.5 — Strict Release Tiers**: Version increments must adhere to ADR-007 release tier rules: Patch for fixes, Minor for features, Major for architectural shifts.
- **R16.6 — Pull Request Gates**: PRs require passing CI checks, updated documentation, and matching changelog entries before merge.
- **R16.7 — Clean Git History**: Never force-push (`git push --force`) to default branches (`main`), and never amend commits that have already been pushed to shared remotes.

---

## Rule 17 — Security & Privacy

*Source Reference: Spec 009 §12 (Out of Scope)*

- **R17.1 — No Hot-Path Network Activity**: Source handlers must never perform network lookups or invoke remote protocols (`curl`, `wget`, `ssh`, remote `git`).
- **R17.2 — Safe String Evaluation**: The engine must never call `eval` on unvalidated strings originating from user input or external directories.
- **R17.3 — Rust Memory Safety**: The `ghost-popup` binary must avoid `unsafe` blocks. Any necessary `unsafe` block (e.g. for low-level libc ioctl calls) must be thoroughly documented with safety invariants.
- **R17.4 — Local-Only Data Privacy**: Shell history entries, file paths, and environment variables must never be transmitted off the host. Telemetry, analytics, and crash reporting over the network are strictly forbidden.
- **R17.5 — Immutable Config State**: Configuration maps must be marked read-only after initial load to prevent runtime tampering.
- **R17.6 — Unprivileged Execution**: The Rust binary must run strictly with user privileges; setuid/setgid execution is explicitly disallowed.

---

## Rule 18 — Continuous Integration (CI) Mandates

*Source Reference: Spec 009 §11*

- **R18.1 — Environment Matrix**: CI workflows must validate against Zsh 5.8 and 5.9 across Linux and macOS runners.
- **R18.2 — Mandatory Pipeline Stages**: The CI workflow must execute:
  1. Static analysis (`shellcheck`, Zsh syntax verification `zsh -n`).
  2. Test execution (running all `tests/*.zsh` suites).
  3. Hot-path fork purity and benchmark assertions.
  4. Rust compilation, `cargo clippy`, and `cargo fmt`.
- **R18.3 — Automated Benchmark Reports**: Benchmarking workflows must record execution latency diffs and post summary metrics on pull requests.
- **R18.4 — Regression Threshold Warning**: Any keystroke latency increase > 0.5ms must require explicit engineering justification in the PR description.
- **R18.5 — Hard Latency Block**: Any PR causing keystroke latency to exceed the 3.0ms hard ceiling will be automatically blocked from merging.
- **R18.6 — Zero Clippy Warnings**: The Rust crate must build with zero warnings under `cargo clippy --all-targets -- -D warnings`.
- **R18.7 — Formatter Compliance**: Rust code must be verified against `cargo fmt --check` before passing CI.

---

## 19. Enforcement Matrix

| Rule Domain | Automated CI Gate | Static Analysis | Code Review Focus |
|---|:---:|:---:|:---:|
| **R1 — Organization** | Directory check script | Namespace pattern audit | Module boundaries |
| **R2 — Naming** | Shellcheck / Linter | Naming convention regex | API consistency |
| **R3 — Hot-Path** | Latency benchmark gate | Fork & subshell grep audit | Architectural purity |
| **R4 — Source Contract** | Unit test harness | Signature verifier | Handler side-effects |
| **R5 — Declarative Config** | Schema validation test | Hardcoded string scanner | Default values |
| **R6 — Source Equality** | Integration test suite | Registry path inspection | Symmetrical power |
| **R7 — Strategy Engine** | Condition unit tests | Contradiction detector | Graph dependencies |
| **R8 — Layer Separation** | Stream protocol tests | Process spawn checks | Clean boundaries |
| **R9 — Rust Binary** | `cargo test` / `clippy` | `cargo fmt --check` | Memory safety |
| **R10 — ziro-defer** | Startup benchmark gate | Line count linter | Staged loading |
| **R11 — Testing** | Coverage reporter | Assertion completeness | Edge cases |
| **R12 — Error Handling** | Fault injection tests | Log schema validator | Graceful fallbacks |
| **R13 — Config Versioning** | Migration test suite | Schema comparator | Backward compatibility |
| **R14 — Sovereignty** | `zsh -f` standalone job | Dependency analyzer | Standalone portability |
| **R15 — Documentation** | Link & manual checks | Header docstring audit | Completeness |
| **R16 — Git Workflow** | PR merge gate | Commit linter | Semantic versioning |
| **R17 — Security** | Dependency audit | `unsafe` block scanner | Data privacy |
| **R18 — CI Requirements** | GitHub Actions matrix | Benchmark diff comment | Performance regressions |

---

## 20. Rule Amendment Process

Rules defined in this document are living standards that may be updated as technology evolves, provided the core principles of Spec 009 are upheld.

1. **Proposal**: Open an issue or discussion outlining the specific rule, observed friction, and proposed revision.
2. **Review**: The architecture team reviews the proposed change against Spec 009 principles (P1–P8).
3. **Approval**: Changes require consensus approval from core maintainers.
4. **Version Bump**: On approval, increment the `Version` of this rules document in accordance with Semantic Versioning:
   - Patch bump (`1.0.x`): Clarifications, wording adjustments, documentation improvements.
   - Minor bump (`1.x.0`): Adding new rules, relaxing existing constraints without breaking contracts.
   - Major bump (`x.0.0`): Fundamental shifts in engineering rules or enforcement mechanisms.
5. **Changelog**: Record the rule amendment in `CHANGELOG.md` with links to the approving issue.

---

## 21. Rules Version History

- **v1.0.0 (2026-10-17)**: Initial comprehensive rules specification accompanying Spec 009 v2.0.0 rewrite. Established 18 rule domains, the hot-path fork ban, 7-layer source contract, Rust companion rules, and the automated enforcement matrix.
