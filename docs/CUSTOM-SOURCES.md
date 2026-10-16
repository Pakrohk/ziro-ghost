# Custom Sources

## Overview

Ghost supports user-defined sources registered declaratively via configuration or imperatively via the IOP Registry API. Custom sources allow you to inject project-specific commands, internal scripts, organizational workflows, or dynamic completions into both inline suggestions and the interactive popup menu (`Ctrl-G`).

## Config Schema

To configure custom sources declaratively, add one or more `[[sources]]` tables to your `ghost.conf` (located in `~/.config/ziro/ghost.conf` or `$XDG_CONFIG_HOME/ziro/ghost.conf`):

```toml
[[sources]]
name = "work"
handler = "_my_work_query"
weight = 25
kind = "cmd"
enabled = true
fallback_only = false
intent = "work-specific command suggestions"

[[sources]]
name = "custom-tools"
handler = "~/.config/ziro/ghost/custom-source.zsh"
weight = 15
kind = "alias"
enabled = true
fallback_only = false
intent = "team automation tools"
```

### Table Properties

| Key | Type | Default | Description |
|---|---|---|---|
| `name` | string | **required** | Unique identifier for the source (must not collide with built-in sources). |
| `handler` | string | **required** | Name of a Zsh function, or path to a `.zsh` file defining the handler. |
| `weight` | integer | `20` | Base ranking weight (relative to history 40, project 30, subcommand 10). |
| `kind` | string | `"cmd"` | Semantic kind badge (`cmd`, `alias`, `git`, `path`, `project`, etc.). |
| `enabled` | boolean | `true` | Set to `false` to disable without deleting the definition. |
| `fallback_only` | boolean | `false` | If `true`, only executes when primary sources return no suggestions. |
| `intent` | string | `"custom"` | Explanatory description for IOP metadata. |

## Handler Interface

A handler is a shell function that accepts the current buffer query as `$1` and populates the global `_ghost_results` array.

1. Takes query string as `$1`.
2. Emulates local zsh options: `emulate -L zsh`.
3. Populates `_ghost_results` array (either plain strings or `weight:kind:text` formatted entries).
4. Returns `0` on success, `1` if no candidates match.

### Example Function

```zsh
_my_work_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()

  local -a work_cmds=(
    "deploy staging"
    "deploy production --force"
    "kubectl get pods -n production"
    "kubectl logs -f deploy/api-service"
  )

  local cmd
  for cmd in "${work_cmds[@]}"; do
    if [[ -z "$query" || "$cmd" == "$query"* ]]; then
      _ghost_results+=("$cmd")
    fi
  done

  (( ${#_ghost_results} > 0 ))
}
```

## Handler as a File

You can also point `handler` to an external file. Ghost will safely source the file and discover the handler function:

```toml
[[sources]]
name = "team-ops"
handler = "~/.config/ziro/ghost/ops.zsh"
weight = 25
kind = "cmd"
```

Inside `ops.zsh`:
```zsh
# Function can be named _ghost_<name>_query, _ghost_<name>_handler, or any function
_ghost_team_ops_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  [[ "$query" == ops* ]] && _ghost_results+=("ops healthcheck" "ops deploy")
}
```

## Safety & Performance Guards

- **Timeout Guard**: Each handler execution is timed. If a handler takes longer than `safety.handler_timeout_ms` (default: `50ms`), its results are discarded to keep shell typing responsive.
- **Error Isolation**: Handler syntax errors or runtime crashes are isolated and will not break shell execution or other suggestion providers.
- **Performance Discipline**: Per Spec 011, custom sources should avoid external subprocess forks (`cat`, `grep`, `sed`, `awk`) during query evaluation.

## Runtime Management

- Reload custom sources dynamically without restarting the shell:
  ```zsh
  ghost_reload_custom_sources
  ```
- Inspect registered sources:
  ```zsh
  ghost_custom_sources_list
  ghost_source_info <source-name>
  ```
