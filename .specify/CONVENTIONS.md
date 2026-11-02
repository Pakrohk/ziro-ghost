# Ziro Shell Coding & Engineering Conventions

This document captures the real, observed engineering standards across the Ziro Shell codebase.

---

## 1. Python Architecture & Standards (Layer 3 Core)

### 1.1 Module Structure & Responsibilities
- **Single Responsibility**: Each file has one focused role:
  - `core/*_cli.py`: Command-line dispatchers and user interaction handlers.
  - `core/analyzer.py`, `core/build.py`, `core/generator.py`: Core computational engines.
  - `core/paths.py`: Single source of truth for filesystem locations.
- **Top of File Prologue**:
  ```python
  """ziro-shell — <short description>.

  Layer: 3 (Python core, cold-path only)
  Spec: NNN (<Spec Name>)
  """
  from __future__ import annotations
  ```

### 1.2 Type Annotations
- Full typing on all function signatures: parameters and return values.
- Modern union syntax (`X | None`, `str | Path`) instead of `Optional[X]`.
- Avoid `Any` when a concrete protocol or type can be expressed.

### 1.3 Data Models
- Use `@dataclass` for internal structured data (`core/models.py`, `core/build.py`).
- Prefer frozen dataclasses for immutable value objects.

### 1.4 CLI Dispatch (Cyclopts)
- CLI commands defined in `core/cli.py` using Cyclopts declarative apps.
- Subcommands parse options cleanly and route execution to `cmd_<name>(argv: list[str]) -> int`.

### 1.5 Path Resolution
- **Rule**: Never construct paths with raw strings like `os.path.expanduser("~/.ziro")` or `/home/...`.
- **Always use**: `core.paths.get_paths()`:
  ```python
  from core.paths import get_paths
  paths = get_paths()
  # paths['home'], paths['config'], paths['cache'], paths['data']
  ```

### 1.6 Configuration & Serialization
- Load TOML with `tomllib.load(f)` (read binary `"rb"` mode).
- For writing `load.toml`, use `core.loadtoml_writer.write_load_toml` to preserve comments and layout.

### 1.7 Error Handling
- Never use bare `except:`.
- Catch specific expected exceptions (`OSError`, `subprocess.SubprocessError`, `ValueError`).
- Raise `ValueError` with clear, actionable context when inputs violate preconditions.

### 1.8 User Output & Diagnostics
- CLI user-facing output uses standard `print()`.
- Error and diagnostic warnings print to `file=sys.stderr`.
- Health reporting adheres to Neovim `+checkhealth` format via `HealthReport` class.

### 1.9 Testing
- All tests reside in `tests/test_*.py`.
- Tests must be isolated and hermetic: use `tempfile.TemporaryDirectory` or `tmp_path`.
- Mock or isolate environment variables (`ZIRO_HOME`, `ZIRO_CONFIG`, `ZIRO_CACHE`).

---

## 2. Zsh Architecture & Standards (Layer 0–2 Runtime)

### 2.1 Function Prologue & Hygiene
- Every shell function must reset options to standard Zsh behavior:
  ```zsh
  my_function() {
    emulate -L zsh
    setopt local_options
    ...
  }
  ```

### 2.2 Startup Performance Invariants (Hot Path)
- **Zero Subprocess / Zero Fork**: No command substitutions (`$(...)`) or external binary calls during shell initialization.
- **Compiled-Only Rule**: Every eager Zsh script loaded during boot must have a valid, fresh `.zwc` compiled sibling.

### 2.3 Variable Scoping & Naming
- **Private Internal Variables/Functions**: Prefix with `_ziro_` or `_ghost_` (lowercase).
- **Public Environment Variables**: Uppercase with `ZIRO_` prefix (`ZIRO_HOME`, `ZIRO_CONFIG`).
- **Local Scope**: Always declare with `local`, `typeset -a`, `typeset -g`, or `typeset -gi`.

### 2.4 Hook Registration
- Register prompt and precmd hooks exclusively via `add-zsh-hook`:
  ```zsh
  autoload -Uz add-zsh-hook 2>/dev/null || return 1
  add-zsh-hook precmd _ziro_defer_core_dispatch_precmd
  ```
- Guard interactive-only hooks so they never run in non-interactive subshells (`[[ -o interactive ]]`).

---

## 3. Git & Commit Conventions

### 3.1 Format
Commits follow Conventional Commits:
```text
<type>(<scope>): <subject>

[optional body referencing Spec requirement]

[optional footer]
```

### 3.2 Types
- `feat`: New feature or capability.
- `fix`: Bug fix or patch.
- `security`: Hardening, permission, or vulnerability fix.
- `docs`: Documentation, specs, ADRs, or guides.
- `refactor`: Code change that neither fixes a bug nor adds a feature.
- `test`: Adding or correcting tests.
- `chore`: Release bumps, metadata, or tooling updates.

### 3.3 Body Reference
Commit messages for implementation work must reference the spec requirement:
```text
security(ghost): exclude tokens and passwords from history cache

Implements R1 and R2 of Spec 016.
```

---

## 4. Intent-Oriented Programming (EVOID IOP) Architecture

Ghost v2.0.0 implements the EVOID IOP specification:

### 4.1 Topology Map
- **Gateway**: `ziro` CLI / Zsh ZLE frontend.
- **Intent Bus**: Asynchronous bidirectional NDJSON stdio streaming.
- **Services / Modules**: Decoupled subscribers listening on distinct Intent namespaces.

### 4.2 Module Intent Namespaces
Each subsystem owns an isolated namespace. **No module may call another module directly**; all interactions flow strictly through the Intent Bus:
- `ghost.suggest.*`: Ghost Line suggestion queries, completions, and candidate evaluations.
- `ghost.popup.*`: Interactive Focus Mode overlay lifecycle, navigation, and selection events.
- `ghost.cache.*`: Multi-tier cache get, put, invalidation, and cleanup operations.
- `ghost.strategy.*`: Strategy evaluation, source weight assignment, and pipeline composition.

### 4.3 Intent Envelope Schema
Every intent transmitted across the bus follows the immutable envelope:
```json
{
  "id": "uuid-or-monotonic-id",
  "name": "ghost.namespace.action",
  "level": "ephemeral | standard | critical",
  "metadata": {}
}
```

### 4.4 Intent Levels & Execution Pipeline
Intent level determines execution pipeline, authorization, and timeout budgets:
- **`ephemeral`**: Transient keystroke queries (e.g. inline suggestion). Pipeline: `[validate]`. Timeout budget: **5s** (internal target <3ms).
- **`standard`**: Stateful UI actions and cache mutations (e.g. Tab popup, cache write). Pipeline: `[validate, authorize]`. Timeout budget: **10s** (target <50ms).
- **`critical`**: Security, secret scrubbing, and persistent configuration changes. Pipeline: `[validate, authorize, audit, protect]`. Timeout budget: **30s**.

### 4.5 Plugin Architecture
- Infrastructure capabilities (Cache, Storage, Suggestion Sources) are implemented as self-contained plugins subscribing to their respective intent names.

