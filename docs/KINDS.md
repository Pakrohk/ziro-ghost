# The Kind System

> Semantic classification, glyph styling, and user customization.

---

## 1. Overview

The **Kind System** is Ghost's visual language. By categorizing suggestions into distinctive visual types, developers can immediately recognize the context and source of a completion before pressing Enter or Tab.

---

## 2. Default Kinds Table

| Kind | Nerd Font Icon | ASCII Fallback | Color Token | Default Label | Source Context |
|---|:---:|:---:|---|---|---|
| `git` | 󰊢 | `*` | `green` | `git` | Git branch, commit, tag, remote |
| `cmd` |  | `$` | `blue` | `cmd` | Executable in `$PATH` |
| `path` | 󰉋 | `~` | `yellow` | `path` | Filesystem path |
| `dir` |  | `/` | `cyan` | `dir` | Directory |
| `file` | 󰈔 | `#` | `white` | `file` | Regular file |
| `alias` | 󰌷 | `@` | `magenta` | `alias` | Defined shell alias |
| `var` | `$` | `$` | `red` | `var` | Environment / shell variable |
| `func` | 󰊕 | `ƒ` | `cyan` | `func` | Shell function |
| `history` | 󰋚 | `h` | `gray` | `hist` | Historical command |
| `project` | ◉ | `p` | `blue` | `proj` | Detected project command |
| `typo` | 🔧 | `!` | `red` | `typo` | Suggested typo correction |
| `snippet` | 󰩫 | `&` | `magenta` | `snip` | Command template / recipe |

---

## 3. Customizing Kinds via Configuration

You can override any kind's icon, color, or label in `~/.config/ziro/ghost.conf`:

```toml
# ~/.config/ziro/ghost.conf

[ui.kinds.git]
icon = ""
color = "cyan"
label = "vcs"

[ui.kinds.cmd]
icon = "λ"
color = "magenta"

[ui.kinds.history]
color = "yellow"
```

### Supported Colors
- `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, `gray`

### Respecting NO_COLOR
If the environment variable `NO_COLOR` is set (per [no-color.org](https://no-color.org)), Ghost automatically disables all ANSI escape styling while retaining glyphs.

---

## 4. Registering a Custom Kind via Shell API

Custom sources can register custom kinds at runtime:

```zsh
ghost_kind_register docker \
  --icon "󰡨" \
  --ascii-icon "D" \
  --color blue \
  --label "docker"
```
