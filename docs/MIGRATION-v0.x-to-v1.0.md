# Migration Guide: v0.x → v1.0.0

## Who This Is For

This guide is for early adopters who tested development releases of `ziro-ghost` (from v0.2.0 through v0.9.0) and are migrating to the stable **v1.0.0** release.

---

## Summary of Evolution

Across the v0.x development milestones, Ghost evolved through the following architectural additions:

- **v0.2.0 – v0.3.0**: Initial skeleton, 12-kind semantic system, in-memory/persistent history source, and native/fzf popup menu.
- **v0.4.0**: Project marker detection engine with mtime-invalidated caching for 10+ developer ecosystems.
- **v0.5.0**: Native Zsh completion capture bridge (`completions.source.zsh`) and CLI subcommand table lookup.
- **v0.6.0**: Multi-layered typo correction engine (`typo.source.zsh`) with two-tier fallback pipeline.
- **v0.7.0**: Custom Source API allowing declarative `[[sources]]` tables and file-based handlers.
- **v0.8.0**: Contract-based safety (`max_suggestions`, `timeout_ms`), interactive metadata preview pane, and documentation window (`docs_extractor.py`).
- **v0.9.0**: Pure-Zsh zero-fork loading indicator for `RPROMPT`, `zoxide` directory suggestions, and `j` jump helper.
- **v1.0.0**: Stable release, API freeze, and complete documentation.

---

## Action Items for Upgrading

### 1. Custom Sources Contract

In v0.8.0+, custom sources should declare explicit resource bounds to ensure predictable execution:

```toml
# In ~/.config/ziro/ghost.conf:
[[sources]]
name = "my-tools"
handler = "_my_handler"
weight = 20
kind = "cmd"
enabled = true

# Recommended contract bounds:
max_suggestions = 10   # Upper bound of results (default: 50)
timeout_ms = 30        # Maximum execution budget in ms (default: 100)
```

*Note: If omitted, Ghost automatically applies safe defaults (`50` suggestions, `100ms` timeout) and emits a non-fatal warning.*

### 2. Loading Indicator on Basic Terminals

If your terminal does not support Unicode Braille spinners or emoji, switch the loading indicator to ASCII/text mode:

```toml
# In ~/.config/ziro/ghost.conf:
[ui.loading]
style = "text"   # Renders [loading...] instead of ⏳
```

### 3. Zoxide Integration

If you have `zoxide` installed, Ghost v1.0.0 automatically registers `zoxide` suggestions for `cd` commands. If you prefer to disable this source:

```toml
# In ~/.config/ziro/ghost.conf:
[sources.zoxide]
enabled = false
```

---

## Backward Compatibility Guarantee

**There are no breaking changes in v1.0.0.**
Existing configurations from v0.2.0 through v0.9.0 continue to work seamlessly. All new features and sections have sensible, compiled defaults that activate automatically.
