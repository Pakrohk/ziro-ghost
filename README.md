# ziro-ghost 👻

> IDE-like autocomplete for Zsh — standalone, modular, IOP-compliant

[![Test Ziro Ghost](https://github.com/Pakrohk/ziro-ghost/actions/workflows/test.yml/badge.svg)](https://github.com/Pakrohk/ziro-ghost/actions/workflows/test.yml)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Pakrohk/ziro-ghost/releases/tag/v1.0.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What is ziro-ghost?

**ziro-ghost** brings modern IDE-level autocomplete and autosuggestion ergonomics to Zsh without any external daemon or heavyweight framework. It combines instant inline ghost text (`POSTDISPLAY`), an interactive fuzzy popup menu with real-time documentation and metadata preview, semantic kind styling, a multi-source suggestion engine with typo correction, and declarative custom source extensibility.

Designed in strict compliance with **Spec 011 Zsh Optimization**, Ghost executes with zero subprocess forks on the hot path, achieving an ~8ms load time and instantaneous keystroke feedback.

---

## ✨ Features

- **Ghost Text**: Instant single-candidate inline completion via ZLE `POSTDISPLAY`.
- **Interactive Popup Menu**: Multi-candidate exploration powered by `fzf` with Tab/Shift-Tab navigation (or native ZLE menu fallback).
- **12 Semantic Kinds**: Distinct icons and colors for `git`, `cmd`, `path`, `dir`, `file`, `alias`, `var`, `func`, `history`, `project`, `typo`, and `snippet`.
- **Nerd Font Aware**: Automatic high-definition Nerd Font glyphs with clean ASCII fallbacks for basic TTYs.
- **Multi-Source Engine**: Calibrated weighted scoring combining history (40), project tasks (30), zoxide frecency (15), subcommand completions (10), native zsh completions (10), and typo correction (5).
- **Project-Aware**: Discovers commands for 10+ ecosystems (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Makefile`, `Dockerfile`, `Justfile`).
- **Typo Correction Engine**: Multi-layered correction (static map + Damerau transposition + QWERTY keyboard distance + bounded Levenshtein).
- **Custom Source API**: Declare custom suggestions via TOML config or shell functions with contract-based bounds.
- **Preview Pane & Docs Window**: Instant metadata preview and command documentation lookup (`tldr`, `man`, `--help`) with cold-path disk cache.
- **Pure Zsh Loading Indicator**: Zero-fork, threshold-gated spinner in `RPROMPT` for async operations.
- **Zoxide Integration**: Smart directory suggestions on `cd` and interactive `j` jump helper.
- **Contract-Based Safety**: Strict execution timeouts and suggestion limits with structured accountability stats.

---

## 🚀 Installation

### 1. With znap (Recommended)

```zsh
znap source Pakrohk/ziro-ghost
```

### 2. Standalone (Any Zsh installation)

Clone the repository and source `ghost.plugin.zsh` in your `~/.zshrc`:

```zsh
git clone https://github.com/Pakrohk/ziro-ghost.git ~/.local/share/ziro-ghost
echo 'source ~/.local/share/ziro-ghost/ghost.plugin.zsh' >> ~/.zshrc
```

### 3. With ziro-shell (v1.1.3+)

Ziro Ghost is scheduled for native, zero-config Layer 3 integration into [ziro-shell](https://github.com/Pakrohk/ziro-shell) v1.1.3.

---

## ⌨️ Quick Start & Keybindings

Start typing any command. A ghost suggestion will appear instantly after the cursor.

| Key | Action | Description |
|---|---|---|
| <kbd>→</kbd> (Right Arrow) | `ghost-accept-full` | Accept the entire suggestion |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> | `ghost-accept-word` | Accept the next word of the suggestion |
| <kbd>Ctrl</kbd> + <kbd>G</kbd> | `ghost-popup` | Open interactive popup menu |
| <kbd>Tab</kbd> / <kbd>Ctrl</kbd> + <kbd>N</kbd> | `down` | Select next candidate in popup |
| <kbd>Shift</kbd> + <kbd>Tab</kbd> / <kbd>Ctrl</kbd> + <kbd>P</kbd> | `up` | Select previous candidate in popup |
| <kbd>Ctrl</kbd> + <kbd>/</kbd> | `layout` | Cycle preview layout (right / bottom / hidden) |
| <kbd>Ctrl</kbd> + <kbd>D</kbd> | `docs` | Toggle between Metadata Preview and Docs Window |
| <kbd>Enter</kbd> | `accept` | Insert selected candidate into command line |
| <kbd>Esc</kbd> / <kbd>Ctrl</kbd> + <kbd>C</kbd> | `dismiss` | Dismiss ghost suggestion or popup |

---

## ⚙️ Configuration

Create `~/.config/ziro/ghost.conf` (or `$XDG_CONFIG_HOME/ziro/ghost.conf`):

```toml
[ui]
nerd_font = true        # Set to false for ASCII icon fallback

[ui.preview]
enabled = true          # Enable metadata preview pane in popup
layout = "vertical"     # "vertical" (right) or "horizontal" (bottom)
show_kind = true
show_source = true
show_frecency = true

[ui.docs]
enabled = true          # Enable documentation window (Ctrl-D in popup)
source = "auto"         # "auto", "tldr", "man", or "help"
cache_ttl = 86400       # Cache duration in seconds (24h)
max_lines = 15

[ui.loading]
enabled = true          # Enable RPROMPT loading indicator
threshold_ms = 200      # Only show if operation takes > 200ms
style = "minimal"       # "minimal" (⏳), "spinner" (Braille), or "text"
show_label = false

[correction]
enabled = true          # Enable typo correction fallback
mode = "suggest"        # "suggest" or "auto"
max_edit_distance = 2
keyboard_distance = true
confidence_threshold = 0.7

[safety]
handler_timeout_ms = 50 # Default timeout for sources

# Optional custom source example:
[[sources]]
name = "work"
handler = "_my_work_query"
weight = 25
kind = "cmd"
enabled = true
max_suggestions = 10    # Upper bound of results
timeout_ms = 30         # Max allowed runtime
```

---

## 🔌 Custom Sources

Ghost allows you to define declarative or script-based custom sources in seconds. See the full [Custom Sources Guide](docs/CUSTOM-SOURCES.md).

```toml
[[sources]]
name = "team-tools"
handler = "~/.config/ziro/ghost/tools.zsh"
weight = 20
kind = "cmd"
max_suggestions = 10
timeout_ms = 40
```

Inside `tools.zsh`:
```zsh
_ghost_team_tools_query() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  [[ "$query" == deploy* ]] && _ghost_results+=("deploy staging" "deploy production")
  (( ${#_ghost_results} > 0 ))
}
```

---

## 📋 Requirements

- **Zsh**: ≥ 5.8
- **fzf** *(optional)*: For fuzzy popup menu, layout cycling, and directory jump preview.
- **zoxide** *(optional)*: For directory frecency suggestions and the `j` helper shortcut.
- **Python**: ≥ 3.11 *(optional)*: For project marker detection and documentation extraction on cold repositories.

---

## 🏛️ Architecture

Ziro Ghost follows an **Intent-Oriented Programming (IOP)** architecture. Components declare intents and communicate via registries without tight coupling:

```
┌────────────────────────────────────────────────────────┐
│                   ghost.plugin.zsh                     │
└──────────────────────────┬─────────────────────────────┘
                           │
 ┌─────────────────────────┼───────────────────────────┐
 │ Core                    │ Engine                    │ UI
 ├─────────────────────────┼───────────────────────────┼─────────────────────
 │ ghost-kinds.zsh         │ matcher.zsh (prefix)      │ inline.ui.zsh
 │ ghost-registry.zsh      │ comparator.zsh (pure Zsh) │ popup.ui.zsh
 │ ghost-config.zsh (TOML) │                           │ preview.ui.zsh
 │ ghost-core.zsh (ZLE)    │                           │ docs.ui.zsh
 └─────────────────────────┼───────────────────────────┤ loading.ui.zsh
                           │ Sources (Pluggable)       └─────────────────────
                           ├───────────────────────────
                           │ history (40) · project (30) · zoxide (15)
                           │ subcommand (10) · completions (10) · typo (5)
                           │ [[sources]] user-defined custom sources
```

For in-depth details, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/API.md](docs/API.md).

---

## 🔗 Related Projects

- [ziro-shell](https://github.com/Pakrohk/ziro-shell) — Fast, modular shell runtime environment for Zsh.
- [ziro-pf](https://github.com/Pakrohk/ziro-pf) — Universal cross-platform package management frontend (planned).

---

## 📄 License

MIT © [Pakrohk](https://github.com/Pakrohk) — see [LICENSE](LICENSE) for details.
