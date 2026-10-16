# Preview Pane & Documentation Window

## Overview

Ghost v0.8.0 introduces an interactive **Preview Pane** and **Documentation Window** integrated into the `Ctrl-G` interactive popup menu. This provides instant visibility into suggestion metadata and command documentation without leaving your current prompt.

## Preview Pane

When browsing candidates in the interactive popup menu, the right-hand preview pane displays structured metadata about the currently highlighted candidate:

```
╭─ Suggestion ─────────────────╮
│ git commit -m "docs update"
╰──────────────────────────────╯

Kind:     󰊢 git
Source:   subcommand
Weight:   10
Frecency: 42
```

### Configuration

Customize the preview pane in `~/.config/ziro/ghost.conf`:

```toml
[ui.preview]
enabled = true          # Set to false to disable preview pane entirely
layout = "vertical"     # "vertical" (right side) or "horizontal" (bottom)
show_kind = true
show_source = true
show_frecency = true
show_directory = false
```

### Keybindings in Popup Menu

| Key | Action |
|---|---|
| `Tab` / `Ctrl-N` | Select next candidate |
| `Shift-Tab` / `Ctrl-P` | Select previous candidate |
| `Ctrl-/` | Cycle preview layout (`down:40%` → `right:50%` → `hidden`) |
| `Ctrl-D` | Toggle between Metadata Preview and Documentation Window |
| `Enter` | Accept highlighted candidate into command line |
| `Esc` / `Ctrl-C` | Dismiss popup menu |

---

## Documentation Window

Pressing `Ctrl-D` inside the popup switches the preview pane into the **Documentation Window**. Ghost extracts concise command summaries using a cold-path background Python helper:

1. **tldr**: High-level cheatsheet examples (if installed).
2. **man pages**: Formatted manual page synopsis (via `man -P cat`).
3. **--help**: Built-in CLI help text.

### Cache & Performance Discipline

- Extracted documentation is cached in `~/.cache/ziro/ghost/docs/` with a default TTL of 24 hours (`86400s`). Subsequent views of the same command load instantly from disk.
- All external documentation lookups run strictly out-of-band with a hard **3-second timeout**, preventing shell freezes.

### Configuration

Customize documentation extraction in `~/.config/ziro/ghost.conf`:

```toml
[ui.docs]
enabled = true
source = "auto"         # "auto", "tldr", "man", or "help"
cache_ttl = 86400       # TTL in seconds (default: 24h)
max_lines = 15          # Max lines displayed in preview pane
```
