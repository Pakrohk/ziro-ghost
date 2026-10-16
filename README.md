# ziro-ghost 👻

> Standalone, modular, IDE-like autocomplete and autosuggest plugin for Zsh.

[![CI Test](https://github.com/Pakrohk/ziro-ghost/actions/workflows/test.yml/badge.svg)](https://github.com/Pakrohk/ziro-ghost/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Ziro Ghost** brings modern IDE completion ergonomics (similar to `nvim-cmp` or VS Code) directly to the command line, adhering to **Constitution Principle XIV (Plugin Sovereignty)**.

---

## ✨ Highlights

- **Dual-Mode Ergonomics**:
  - **Inline Ghost Text (`POSTDISPLAY`)**: Instant, zero-latency single-candidate completion.
  - **Interactive Popup Menu (`Ctrl-G` / `Tab`)**: Multi-candidate exploration powered by fzf with rich metadata.
- **Kind System**: Semantic icons and color highlights distinguishing `git`, `cmd`, `path`, `dir`, `file`, `alias`, `var`, `func`, `history`, `project`, `typo`, and `snippet`.
- **Nerd Font Aware**: Automatic high-definition Nerd Font glyphs with clean ASCII fallbacks for basic TTYs.
- **Multi-Source Architecture (IOP)**: Open Registry pattern allowing history, project markers, shell aliases, and custom external scripts to contribute suggestions.
- **Fully Standalone**: Works in plain Zsh, Oh-My-Zsh, Prezto, or [Ziro Shell](https://github.com/Pakrohk/ziro-shell). Zero runtime dependencies.

---

## 🚀 Installation

### Standalone (Manual Sourcing)

Clone the repository and source `ghost.plugin.zsh` in your `~/.zshrc`:

```zsh
git clone https://github.com/Pakrohk/ziro-ghost.git ~/.local/share/ziro-ghost
echo 'source ~/.local/share/ziro-ghost/ghost.plugin.zsh' >> ~/.zshrc
```

### With znap

```zsh
znap source Pakrohk/ziro-ghost
```

### With zinit / zplug / antibody

```zsh
zinit light Pakrohk/ziro-ghost
```

---

## ⌨️ Default Keybindings

| Keybinding | Action | Description |
|---|---|---|
| <kbd>→</kbd> (Right Arrow) | `ghost-accept-full` | Accept the entire suggestion |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> | `ghost-accept-word` | Accept the next word of the suggestion |
| <kbd>Ctrl</kbd> + <kbd>G</kbd> | `ghost-popup` | Open interactive selection menu |
| <kbd>Esc</kbd> | `ghost-dismiss` | Clear inline ghost text |

---

## 🎨 The Kind System

Ghost categorizes every suggestion into semantic kinds with distinctive colors and glyphs:

| Kind | Nerd Font Glyph | ASCII Fallback | Color | Description |
|---|:---:|:---:|---|---|
| `git` | 󰊢 | `*` | Green | Git branches, commits, remotes |
| `cmd` |  | `$` | Blue | System executables and commands |
| `path` | 󰉋 | `~` | Yellow | Relative or absolute filepaths |
| `dir` |  | `/` | Cyan | Directories |
| `file` | 󰈔 | `#` | White | Files |
| `alias` | 󰌷 | `@` | Magenta | Shell aliases |
| `var` | `$` | `$` | Red | Environment and shell variables |
| `func` | 󰊕 | `ƒ` | Cyan | Shell functions |
| `history` | 󰋚 | `h` | Gray | History suggestions |
| `project` | ◉ | `p` | Blue | Contextual project build targets |
| `typo` | 🔧 | `!` | Red | Typo corrections |
| `snippet` | 󰩫 | `&` | Magenta | Code and command snippets |

See [docs/KINDS.md](docs/KINDS.md) for customizing icons, labels, and color mappings.

---

## ⚙️ Configuration

Ghost configuration can be placed in `~/.config/ziro/ghost.conf` (TOML format) or set via standard Zsh `zstyle`:

```toml
# ~/.config/ziro/ghost.conf

[ui]
nerd_font = true
color_scheme = "auto"

[ui.kinds.git]
color = "green"

[sources]
history.weight = 40
```

See [docs/CONFIG.md](docs/CONFIG.md) for full configuration reference.

---

## 📚 Documentation

- [Architecture & IOP Registry](docs/ARCHITECTURE.md)
- [Kind System Reference](docs/KINDS.md)
- [Configuration Guide](docs/CONFIG.md)
- [Changelog](CHANGELOG.md)

---

## 📜 License

[MIT](LICENSE) © 2026 [Pakrohk](https://github.com/Pakrohk)
