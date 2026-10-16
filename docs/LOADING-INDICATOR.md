# Loading Indicator

## Overview

Ghost v0.9.0 provides an ultra-lightweight, zero-fork loading indicator designed for Zsh's `RPROMPT` and interactive redraws. When background tasks or slower queries (such as project marker detection on cold repositories or complex completions) take noticeable time, Ghost renders a subtle indicator without blocking or delaying your prompt.

## Performance Discipline (Spec 011)

- **Pure Zsh**: Implemented entirely using native Zsh arithmetic and string operations. Zero Python startups, zero subprocess forks (`cat`, `grep`, `sleep`).
- **Overhead**: ~0.1ms per redraw.
- **Threshold-Gated**: By default, the indicator remains completely silent and invisible for fast operations under 200ms. It only renders when an operation exceeds the configured threshold.

## Configuration

Configure the loading indicator in `~/.config/ziro/ghost.conf`:

```toml
[ui.loading]
enabled = true          # Set to false to disable completely
threshold_ms = 200      # Milliseconds before indicator appears
style = "minimal"       # "minimal", "spinner", or "text"
show_label = false      # Append operation name (e.g. "⏳ project")
```

### Supported Styles

| Style | Appearance | Description |
|---|---|---|
| `minimal` (default) | `⏳` | Clean, subtle hourglass indicator |
| `spinner` | `⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏` | Braille cycling animation frame per redraw |
| `text` | `[project...]` | Descriptive text indicating current source operation |

## RPROMPT Integration

Ghost exposes the hook `_ghost_loading_rprompt_wrap` to integrate cleanly with your existing prompt themes:

```zsh
# In your .zshrc:
RPROMPT='$(_ghost_loading_rprompt_wrap)'
```

If `RPROMPT` is not set or not configured, Ghost silently skips rendering without error.
