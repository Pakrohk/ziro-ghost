# Public API Specification

> Status: **STABLE** (Guaranteed from v1.0.0)

This document formalizes the public shell API exposed by `ziro-ghost`. Commencing with version 1.0.0, all functions and interfaces documented here are backward-compatible and guaranteed stable until version 2.0.0.

---

## 1. Source Registration & Lifecycle

### `ghost_register_source`

Registers a suggestion source in the Intent-Oriented Programming (IOP) registry.

```zsh
ghost_register_source <name> \
  --intent <description> \
  --handler <function_name> \
  --weight <integer> \
  --kind <kind_name> \
  --enabled <true|false> \
  [--fallback-only] \
  [--max-suggestions <int>] \
  [--timeout-ms <int>]
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `<name>` | string | *required* | Unique identifier for the source (must not collide with built-in sources). |
| `--intent` | string | `""` | Human-readable explanation of source purpose. |
| `--handler` | string | *required* | Name of the shell function called to compute suggestions. |
| `--weight` | integer | `10` | Relative scoring weight used by the comparator engine. |
| `--kind` | string | `"cmd"` | Semantic kind badge assigned to candidates. |
| `--enabled` | boolean | `"true"` | Enables or disables querying of this source. |
| `--fallback-only` | flag | *absent* | Restricts execution to the secondary pass when primary sources return 0 items. |
| `--max-suggestions` | integer | `50` | Contract bound: truncates excessive suggestions. |
| `--timeout-ms` | integer | `100` | Contract bound: discards results if execution exceeds this limit. |

### Source Management

- `ghost_unregister_source <name>`: Completely removes a source and its contract/stats from the registry.
- `ghost_source_info <name>`: Prints formatted metadata for a registered source.
- `ghost_custom_sources_list`: Returns array of names for all user-registered custom sources.
- `ghost_load_custom_sources`: Loads custom sources declared in `ghost.conf`.
- `ghost_reload_custom_sources`: Flushes and re-registers custom sources at runtime.

---

## 2. Handler Function Contract

A handler is a shell function invoked by Ghost's core pipeline:

```zsh
_my_custom_handler() {
  emulate -L zsh
  local query="$1"

  # 1. Clear output arrays
  _ghost_results=()
  _ghost_result_kinds=()

  # 2. Populate suggestions
  # Either plain text:
  _ghost_results+=("deploy production")
  _ghost_result_kinds+=(cmd)

  # Or pre-formatted weight:kind:text
  # _ghost_results+=("25:cmd:deploy production")

  # 3. Return 0 if results found, 1 otherwise
  (( ${#_ghost_results} > 0 ))
}
```

### Handler Invariants
1. **Purity**: Avoid modifying ZLE buffers or shell global state outside `_ghost_results` and `_ghost_result_kinds`.
2. **Spec 011 Compliance**: Do not execute external subprocesses (`cat`, `grep`, `sed`, `awk`) during query evaluation.
3. **Bounded Execution**: The function must terminate in bounded time.

---

## 3. Observability & Source Statistics

Ghost tracks runtime execution metrics to guarantee prompt responsiveness:

- `ghost_source_stats <name>`: Prints execution counters for `<name>`:
  - `calls`: Total number of queries executed.
  - `avg_ms`: Running average execution time in milliseconds.
  - `max_ms`: Maximum execution time recorded.
  - `last_ms`: Duration of the most recent call.
  - `timeout_violations`: Count of times execution exceeded `timeout_ms`.
  - `truncations`: Count of times results were truncated to `max_suggestions`.
- `ghost_all_source_stats`: Aggregates and displays stats for all registered sources.
- `ghost_source_stats_reset [name]`: Clears statistics counters for `<name>` or all sources.

---

## 4. Semantic Kind API

The semantic kind engine manages icons, colors, and badge labels:

- `ghost_kind_register <name> --icon <glyph> --color <ansi_code> --label <text>`
- `ghost_kind_render <name>`: Renders the formatted icon and color escape sequence for `<name>` into `$REPLY`.
- `ghost_kind_fallback <name>`: Returns the ASCII fallback symbol for `<name>`.
- `ghost_kind_get <name>`: Retrieves property mappings for `<name>`.

Built-in kinds: `git`, `cmd`, `path`, `dir`, `file`, `alias`, `var`, `func`, `history`, `project`, `typo`, `snippet`.

---

## 5. Configuration Engine API

- `_ghost_config_get <key> [default_value]`: Returns the resolved configuration value, querying TOML cache, `zstyle` overrides, and compiled defaults.
- `_ghost_config_load_toml <path>`: Cold-path TOML parser loading configuration keys and `[[sources]]` tables.

---

## 6. Stability Guarantee

Starting with version **1.0.0**:
- No existing function signature, option, or behavior documented here will be modified in a backward-incompatible way before **v2.0.0**.
- Minor and patch releases (v1.x.y) may introduce new functions, flags, or configuration keys, but will never break existing integrations.
