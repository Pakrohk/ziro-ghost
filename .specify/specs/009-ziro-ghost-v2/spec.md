# Feature Specification: Ziro Ghost — LSP-like Autocomplete for Zsh

**Spec ID**: 009  
**Version**: 2.0.0 (major rewrite — supersedes v1.0.x)  
**Parent Spec**: `000-architecture`  
**Related Specs**: `001-plugin-analyzer-layer1`, `011-zsh-optimization`, `012-plugin-manifest`  
**Related ADRs**: `ADR-006` (ghost config), `ADR-007` (versioning), `ADR-009` (code style), `ADR-011` (manifest)  
**Created**: 2026-10-17  
**Status**: Draft  
**Target Release**: ghost v2.0.0 (independent) → ziro-shell v1.2.0 (integration)  
**Previous Version**: v1.0.x archived at `.specify/specs/_deprecated/009-ziro-ghost-v1/`  

---

> **⚠️ MAJOR REWRITE**: This specification completely replaces the Zsh-only architecture of v1.0.x
> with a two-layer architecture (Zsh inline core + Rust focus mode menu). Existing
> v1.0.x behavior is preserved via a backward-compatibility layer; all new capabilities are
> fully declarative, modular, and non-blocking.

---

## 1. Purpose & Vision

### 1.1 Purpose

Define `ziro-ghost` v2 — an LSP-like autocomplete plugin for Zsh that simulates Language Server Protocol behavior directly in the command line interface. Unlike traditional IDE code completion that requires heavy daemon infrastructures, `ziro-ghost` targets shell commands with two clean, decoupled layers: instant inline suggestions (**Ghost Line**) and an interactive, animated graphical overlay (**Focus Mode**).

### 1.2 Vision

`ziro-ghost` v2 is not a thin wrapper around existing tools. It is a complete, self-contained, high-performance autocompletion subsystem designed around three foundational capabilities:

#### Capability 1 — Ghost Line (Instant Inline Suggestion)
Inline dim gray text rendered immediately after the cursor using native Zsh ZLE `POSTDISPLAY`. Updated on every single keystroke from fast primary sources (history, command tables, directory paths). It operates with zero perceptible latency (< 2ms), never blocks user typing, and cleanly recalculates without leaking terminal control codes or ANSI escape sequences into cursor positioning metrics.

#### Capability 2 — Ghost Complete (Always-Visible Context Preview)
An unobtrusive single-line preview message displayed below the prompt (via native `zle -M`) summarizing available suggestions gathered across multiple sources (history, project markers, zoxide directories, typo fixes, language helpers, and user-defined custom sources). The menu is **only entered** when the user explicitly presses `Tab`. When entered, the interactive menu replaces the inline ghost text. If the user continues regular typing instead of navigating, the menu smoothly yields back to preview mode without breaking the user's flow — exactly mirroring the ergonomics of modern code editors.

#### Capability 3 — Focus Mode (Rust-Powered Interactive Overlay)
An interactive terminal selection menu rendered via a lightweight per-shell Rust sidecar (`ghost-popup`). Spawned on the first `Tab` press of the shell session; persists across subsequent tabs and accepts NDJSON updates from Zsh. Built with `ratatui` and `tachyonfx`, it delivers clean borders, smooth micro-animations, full mouse support (clicking, hovering, scrolling), terminal theme compliance, and partial rendering (only redrawing cells that actually changed). Shuts down cleanly on shell exit or SIGTERM. Never uses alternate screen buffers (`smcup`/`rmcup`), keeping the prompt strictly pinned and in sight.

### 1.3 Why This Is Better Than `cmp-nvim` and `IRIS`

- **Source Equality**: Internal built-in sources and user-defined custom sources are registered, configured, ranked, and executed through identical schemas and pipelines.
- **Declarative by Default**: 100% of behavioral, stylistic, and mechanical settings are declared in TOML (`~/.config/ziro/ghost.conf`). No hardcoded magic strings or magic numbers exist in source code.
- **Two-Layer Rendering Seam**: Fast Zsh logic handles native line editing and lightweight preview; Rust handles graphical presentation, animation, and cell diffing on demand.
- **Strategy Engine**: Sources declare conditional relationships (fallbacks, alternatives, recovery, dependencies) rather than competing blindly.
- **Plugin Sovereignty**: Operates as a completely independent, standalone Zsh plugin. It requires neither `ziro-shell` nor external daemons, yet integrates natively when present.

### 1.4 LSP-like Behavior Mapping

| Language Server (LSP) Concept | Ziro-Ghost v2 Architecture Equivalent |
|---|---|
| Completion Items (`textEdit`, `label`) | Suggestion candidates from registered sources (`_ghost_results`) |
| Documentation / Markdown Hover | Preview pane rendering command usage, manuals (`tldr`/`man`), and explanations |
| Signature Help | Inline preview line displaying parameter hints and command templates |
| Trigger Characters | Configurable trigger keys (`cycle_key = "^I"` / `Tab` by default, per D8) |
| Snippets / Template Expansions | Custom user sources expanding parameterized shell patterns |
| Diagnostic Providers | Typo correction engine generating nearest-match command alternatives |
| Workspace Symbols | Project markers source detecting ecosystem context (Node, Rust, Go, Python) |

---

## 2. Core Principles (Non-Negotiable)

These eight principles govern every architectural choice, code change, and extension. Any proposed feature that violates them must be rejected or redesigned.

### P1 — Source Equality
Every suggestion source — whether built into the core plugin or written by an end user in their personal configuration — is defined, loaded, scheduled, and ranked through an identical 7-layer contract. Built-in sources possess zero special privileges, private APIs, or hidden priority bypasses. Users can reconfigure, reprioritize, or disable any built-in source without patching source code.

### P2 — Declarative by Default
All configuration resides in a single, well-structured TOML file (`~/.config/ziro/ghost.conf`). Zero-config users get optimal defaults; power users customize every attribute via declarative keys. Code contains no hardcoded styling constants, timeout limits, or source weight overrides.

### P3 — Two-Layer Rendering
Rendering is bifurcated strictly by performance and context:
- **Layer 1 (Zsh)**: Operates synchronously within the ZLE event loop (`line-pre-redraw`). Handles the untyped suffix `POSTDISPLAY` and one-line status in `< 3ms`.
- **Layer 2 (Rust)**: A per-shell sidecar spawned on the FIRST `Tab` press; reused for all subsequent tabs. Renders the interactive menu, animations, and preview documentation; returns selection events to Zsh over NDJSON. Exits cleanly on shell exit.

### P4 — IOP Compliance (Intent-Oriented Programming)
Components declare *intent* (e.g., provide directory paths, request fallback on failure, supply command documentation), decoupling the registration interface from runtime implementation. Adding a new source requires writing a handler function and declaring a TOML entry — nothing in the core plugin changes.

### P5 — ziro-defer Integration
All heavy logic is staged cleanly. Shell startup registers only the basic ZLE widgets (< 0.5ms). Core engines, sources, and configuration load upon the user's first keystroke via `ziro-defer`. Focus Mode binaries are spawned strictly on demand.

### P6 — Plugin Sovereignty (Constitution Principle XIV)
`ziro-ghost` is an autonomous, standalone repository and plugin. It can be loaded via `source ghost.plugin.zsh`, via `znap source`, or via any standard Zsh framework. It never assumes the existence of `ziro-shell` specific internal functions or non-standard paths.

- **$GHOST_HOME resolution**: dynamically set at plugin source time from `${${(%):-%x}:A:h}` (directory containing `ghost.plugin.zsh`). Users may pre-set `$GHOST_HOME` before sourcing to override. If not set, falls back to XDG-standard `$XDG_DATA_HOME/ziro/ghost` or `$HOME/.local/share/ziro/ghost`. Ghost NEVER assumes `~/.ziro/` or `$ZIRO_HOME` exists (sovereignty).

### P7 — Strategy-Based Execution
Sources do not run blindly or waste CPU cycles when their output is redundant. Through declarative strategies (`primary`, `fallback`, `alternative`, `recovery`, `dependent`), sources run conditionally based on the presence, success, or failure of peer sources.

### P8 — Partial Rendering (Performance & Cleanliness)
Focus Mode tracks cell diffs between frames. Only terminals cells whose glyph, foreground, or background attributes have actually changed are redrawn. Full screen clears, terminal alternate screens (`smcup`/`rmcup`), and destructive cursor movements are strictly forbidden.

---

## 3. Two-Layer Architecture

### 3.1 Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │            User Keystroke              │
                      └───────────────────┬────────────────────┘
                                          │
                                          ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 1 — Zsh Core Engine (Hot Path: < 3ms)                                            │
│                                                                                        │
│   • ZLE Hook: line-pre-redraw intercepts input buffer                                  │
│   • Source Engine: queries enabled primary sources within timeout limits                │
│   • Ranking & Comparator: computes top match using weights and length penalty          │
│   • Inline Renderer: sets pure untyped suffix into POSTDISPLAY                         │
│   • Highlight Engine: registers start/end offsets in region_highlight (dim gray)       │
│   • Preview Bar: renders concise candidate count via zle -M                           │
│                                                                                        │
└─────────────────────────────────────────┬──────────────────────────────────────────────┘
                                          │ User presses Tab (Focus Mode Trigger)
                                          ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 2 — Rust Per-Shell Sidecar: ghost-popup (First-tab spawn, then persistent)       │
│                                                                                        │
│   • IPC: NDJSON (bidirectional over stdin/stdout)                                      │
│   • TUI Engine (ratatui): builds virtual layout (border, items, preview, footer)      │
│   • Animation Engine (tachyonfx): applies micro-transitions and entry effects          │
│   • Input Router: handles keyboard navigation, mouse clicks, and scroll wheel          │
│   • Differential Redraw: writes only modified cells to stdout                          │
│   • Lifetime: per-shell session; exits on shell exit or SIGTERM                        │
│   • First-tab spawn ~30ms; subsequent tabs < 2ms                                       │
│                                                                                        │
└─────────────────────────────────────────┬──────────────────────────────────────────────┘
                                          │
                                          ▼
                      ┌────────────────────────────────────────┐
                      │    Buffer Updated / Line Redrawn       │
                      └────────────────────────────────────────┘
```

### 3.2 Layer 1 — Zsh Core Engine (In-Process)

- **Role**: Synchronous orchestration of keystrokes, source querying, ranking, inline rendering, and state dispatching.
- **Execution Model**: Runs directly inside the interactive Zsh process.
- **Constraints**:
  - `emulate -L zsh` enforced at the head of every function.
  - Zero external process forks (`cat`, `grep`, `sed`, `awk`, `python`) on the typing path.
  - Hard latency ceiling: `3.0ms` per keystroke.
  - Handlers must direct all output to arrays; stdout/stderr leakage is strictly trapped via redirection.

### 3.3 Layer 2 — Rust Sidecar (Per-Shell, Optional)

- **Role**: Lightweight per-shell sidecar that hosts interactive widgets (Focus Mode being the first). Renders the popup UI, handles mouse and keyboard events, streams selection state back to Zsh. No global daemon.
- **Binary Name**: `ghost-popup` (installed in `$GHOST_HOME/bin/ghost-popup`).
- **Lifetime**: Per-shell sidecar. Spawns on FIRST Tab press (or on `[rust] prewarm = true` during Stage 2). Stays alive while the shell session lives. Exits cleanly on `exit`, `SIGTERM`, or when `[rust] enabled = false`.
- **IPC**: Bidirectional NDJSON over stdin/stdout pipes. Zsh → Rust: candidate updates. Rust → Zsh: selection state and accept events. No file-based IPC, no sockets, no shared memory.
- **Optionality**: If binary missing or `[rust] enabled = false`, Ghost Line + native Zsh popup fallback handle interaction. Ghost Line NEVER depends on Rust.
- **Rust Crates**: `ratatui` (layout + widgets), `tachyonfx` (micro-animations), `termbg` (luminance), `supports-color`, `serde_json`.
- **Not a daemon**: No UNIX socket, no systemd unit, no cross-shell process. One sidecar per shell session.

### 3.4 Inter-Layer Communication Protocol

Zsh and Rust communicate over bidirectional pipes using NDJSON (newline-delimited JSON).

**Zsh → Rust (stdin) message types:**
- `{"type":"init", "theme":{...}, "config":{...}}` — sent once at sidecar spawn
- `{"type":"update", "query":"git pu", "cursor":6, "items":[...]}` — sent on every buffer change
- `{"type":"focus_enter"}` — sent when Tab first pressed
- `{"type":"cycle_next"}` — Tab pressed in focus, advance highlight
- `{"type":"cycle_prev"}` — Shift-Tab pressed in focus, retreat highlight
- `{"type":"accept_typed", "char":"c"}` — user typed character while focused
- `{"type":"exit"}` — sent on Esc/Ctrl-G
- `{"type":"shutdown"}` — sent on shell exit

**Rust → Zsh (stdout) message types:**
- `{"type":"ready"}` — sidecar initialized
- `{"type":"selection", "index":0, "preview_text":"git push origin main"}` — current highlighted item (Zsh renders as gray inline)
- `{"type":"accept", "text":"git push origin main", "typed_char":"s", "cursor":20}` — user typed; Zsh must set BUFFER and continue from cursor
- `{"type":"cancel"}` — user pressed Esc/Ctrl-G
- `{"type":"error", "msg":"..."}` — non-fatal; Zsh logs and continues

**Fallback**: If pipe breaks (process died), Zsh switches to native popup (or Ghost Line only) silently, logs once.

### 3.5 Fallback Chain

If Layer 2 cannot be executed (e.g., `ghost-popup` binary is not compiled or installed, terminal lacks raw mode support, or execution times out):
1. **Tier 1 (Rust Focus Mode)**: The primary experience.
2. **Tier 2 (Zsh Native Popup)**: Pure Zsh fallback utilizing `zle -M` with ANSI styling and box-drawing characters. Provides keyboard navigation, counter, selection marker, and preview without requiring Rust.
3. **Tier 3 (Ghost Line Only)**: If even native popup fails or message area is suppressed, autocompletion continues functioning silently via inline Ghost Line suggestions.

Degradation is completely graceful. On the first failure of Tier 1, an informational notice is logged once to `~/.cache/ziro/ghost/popup.log` without disrupting command line editing.

---

## 4. Ghost Line Specification

### R1 — Inline Suggestion Rendering
- Ghost Line displays the **untyped suffix** of the highest-ranked candidate matching the current buffer.
- Formula: `suffix="${best_candidate#$BUFFER}"`.
- `POSTDISPLAY` is assigned strictly the plain string `$suffix`. Under no circumstances may ANSI escapes, icons, or badges be placed inside `POSTDISPLAY` (doing so corrupts cursor metrics across terminal emulators).
- Visual styling (dim gray) is applied exclusively via Zsh's native `region_highlight`:
  ```zsh
  local start=$#BUFFER
  local end=$(( start + $#POSTDISPLAY ))
  region_highlight+=("$start $end $color")
  ```

### R2 — Color Resolution Pipeline
The inline ghost color is resolved through a prioritized fallback chain:
1. **User Direct Override**: `[ghost.line] color` in `ghost.conf` (e.g. `color = "fg=#6c6c6c"` or `color = "fg=242"`).
2. **Active Theme Preset**: Color defined for `ghost_text` within `$GHOST_HOME/themes/<preset>.toml`.
3. **Automatic Terminal Capabilities Detection**:
   - `truecolor` / `24bit` (`COLORTERM` matching): `fg=#6c6c6c`
   - `256-color` (`tput colors >= 256`): `fg=240`
   - `8-color ANSI`: `fg=brightblack` (or `fg=8`)
   - Monochrome: text decoration (e.g. `underline`) or no styling.

### R3 — Source Query & In-Memory Caching
- Query results are cached in an associative memory cache keyed by `$BUFFER`.
- Cache is invalidated immediately on:
  - Working directory change (`chpwd` hook).
  - Shell history write/flush.
  - Receipt of `SIGUSR1`.
  - Manual buffer reset via `Ctrl-C` / `Ctrl-U`.
- Debouncing: configurable via `[behavior] debounce_ms` (default: `0ms` for local synchronous sources).

### R4 — Context Preview Line
When `[ghost.preview] enabled = true`:
- Displays a non-destructive status message below the prompt via `zle -M`.
- Format: `  N more suggestions (Tab to expand)`
- If a candidate includes immediate documentation or command hints, it formats dynamically:
  `  1/8: git push origin main · Tab to expand · [hist]`
- Automatically cleared when `BUFFER` becomes empty or when Focus Mode takes over.

### R5 — Focus Mode Handoff
- Upon pressing `Tab`, Ghost Line temporarily clears `POSTDISPLAY` and hands control over to Focus Mode.
- On exit:
  - If selection accepted: `BUFFER` is replaced by the chosen text, `CURSOR` is moved to `${#BUFFER}`, and Ghost Line updates against the new buffer.
  - If selection cancelled: `BUFFER` remains unchanged, and Ghost Line restores its previous suffix.

---

## 5. Focus Mode Specification

### R6 — Activation & Lifecycle

- **Preview (always visible)**: The popup shows suggestions on every keystroke once buffer length ≥ 1. No focus yet — Tab has not been pressed. Top suggestion rendered as gray inline suffix (Ghost Line).
- **Focus entry**: Pressing Tab (default `^I`) enters Focus Mode: first candidate highlighted. Rust sidecar spawns on this FIRST Tab only; subsequent Tabs reuse the same process.
- **Tab = cycle**: Every subsequent Tab advances highlight to next candidate. BUFFER unchanged; highlighted item rendered as gray inline preview.
- **Exit**: Esc or Ctrl-G leaves Focus without changing BUFFER.
- **Accept**: Typing ANY character while in Focus accepts the currently highlighted suggestion → BUFFER becomes `<suggestion><typed_char>`, suggestions recompute from new buffer. Focus exits automatically.
- **Enter = execute**: Enter ALWAYS executes the current BUFFER (never accepts suggestion). This preserves standard shell UX.
- **Sidecar shutdown**: Rust sidecar exits cleanly on `exit`, `SIGTERM`, or config disable. No zombie processes.

### R7 — Visual Layout Architecture

```
╭─ Suggestions (1/8) ───────────────────────── [source: history] ─╮
│ ▸ 󰊢  git push origin main                              [git]   │
│   󰊢  git pull --rebase                                 [git]   │
│   󰊢  git push --force-with-lease                       [git]   │
│     npm run build                                     [cmd]   │
│     ~/Projects/ziro-shell                             [path]  │
├─────────────────────────────────────────────────────────────────┤
│ Preview:                                                        │
│   Update remote refs along with associated objects.             │
│   Frecency score: 142 · Last used: 12 mins ago                  │
╰─────────────────────────────────────────────────────────────────╯
  Tab: cycle · S-Tab: prev · Type to accept · Enter: execute · Esc/Ctrl-G: close · 󰍽 click
```

- **Header**: Shows current item index over total (`1/8`), optional active source filter, and clean border line.
- **Item Row**: Selection indicator (`▸`), semantic Nerd Font icon, suggestion text, and right-aligned kind badge (`[git]`, `[cmd]`, `[path]`, `[hist]`).
- **Preview Pane**: Collapsible split pane rendering documentation, parameter flags, and metadata.
- **Footer**: Keybinding hints and mouse interaction cues.

**Interaction flow (Preview → Focus → Accept):**

```
[Preview — no Tab yet]
$ git pu█
  ▸ git push origin main       ← gray inline suffix
    git pull --rebase
    git push --force-with-lease

[First Tab — enter Focus]
$ git pu█                        ← buffer unchanged
  [▸] git push origin main       ← highlighted, gray inline
      git pull --rebase
      git push --force-with-lease

[Second Tab — cycle]
$ git pu█                        ← buffer unchanged
  [ ] git push origin main
  [▸] git pull --rebase          ← highlighted
      git push --force-with-lease

[User types 's' — ACCEPT]
$ git pull --rebases█            ← buffer = item + 's'
  (focus exited, new suggestions from new buffer)

[OR — Enter pressed]
$ git pu█  <ENTER>
→ executes `git pu` (fails, but shell did what user asked)

[OR — Esc/Ctrl-G pressed]
$ git pu█                        ← buffer unchanged, focus exited
```

### R8 — Animations (`tachyonfx`)
- Micro-transitions powered by `tachyonfx`:
  - `slide-fade`: Window smoothly expands downwards while fading in opacity (duration: `100ms`).
  - `fade`: Smooth brightness fade from background color to target foreground.
  - `slide`: Vertical height expansion.
  - `none`: Instant rendering without procedural effects.
- Strict animation safety:
  - If `NO_COLOR` is present in the environment, animations are automatically disabled.
  - Total frame duration capped at `< 16ms` (guaranteeing 60fps).
  - Users can disable animations globally via `animation = "none"`.

### R9 — Mouse Interaction
- `ghost-popup` intercepts ANSI mouse tracking events (`1000h`, `1002h`, `1006h`):
  - **Left Click**: Selects and immediately accepts the clicked candidate.
  - **Hover**: Moves the selection cursor (`▸`) to the item under the mouse pointer.
  - **Scroll Wheel**: Scrolls candidate list up or down by 1 row per notch.
- Automatically disabled if terminal does not report mouse tracking capability.

### R10 — Differential Partial Rendering
- The popup maintains an offscreen virtual frame buffer.
- On each frame, `ghost-popup` compares current cells against previous cells:
  - Only cells with changed characters, colors, or attributes generate escape sequences.
  - Bandwidth consumption over remote SSH connections drops by over 85% compared to full redraws.

### R11 — Theme Awareness & Palettes
Focus Mode dynamically loads palette colors matching user configuration:
- Supported Presets: `catppuccin-mocha`, `catppuccin-latte`, `tokyo-night`, `gruvbox`, `dracula`, `nord`, `solarized-dark`, `solarized-light`, `terminal` (auto-sampling).
- Each semantic kind receives a dedicated palette color (e.g. `git` = green, `cmd` = blue, `path` = yellow, `typo` = red, `hist` = gray).

### R12 — Zsh Native Fallback (when Rust sidecar unavailable)

When Rust sidecar is missing or `[rust] enabled = false`, Ghost uses pure-Zsh rendering:

- **Preview**: Top-3 suggestions rendered below prompt via `zle -M` with box-drawing characters and gray styling. No focus state, no Tab cycling (Tab falls through to standard zsh completion if `only_when_candidates = true`).
- **Native popup (best-effort)**: If `[ghost.focus] native_popup = true` (default), a minimal Zsh popup is rendered on Tab via rebind mechanism:
  1. `_ghost_ui_native_open()` sets `_GHOST_NATIVE_POPUP_ACTIVE=1`, saves current Tab/Enter/Esc/Ctrl-G bindings
  2. Rebinds: Tab → `_ghost_native_next`, S-Tab → `_ghost_native_prev`, Enter → `_ghost_native_execute`, Esc/Ctrl-G → `_ghost_native_cancel`
  3. Any typed key that is NOT in {Tab, S-Tab, Enter, Esc, Ctrl-G} triggers `_ghost_native_accept_current` (accepts highlighted, sets BUFFER, exits native mode, restores bindings)
  4. `_ghost_native_close()` restores bindings and clears message area
- **Degradation**: If even native popup fails, Ghost Line alone works. No shell crashes.

### R12b — Path-Context Detection (D7)

When `_ghost_is_path_query(buffer)` returns true, source priority is: `zoxide` (35) > `completions` (30) > `history` (25). Path-context triggers:
- Buffer ends with `/` or `~`
- Last whitespace-delimited token starts with `cd `, `ls `, `cat `, `vim `, `code `, `open `, `rm `, `cp `, `mv `, `mkdir `, `touch `
- Buffer contains no spaces (bare path being typed)

Outside path-context: weights apply as declared in §6 table (history 25, project 20, ...).

Implementation: `_ghost_is_path_query()` lives in `engine/ghost-filter.zsh`. Sources remain unaware; the strategy engine dynamically reorders at compute time by checking this flag.

---

## 6. Source Standard (7 Layers)

Every source — internal or user-defined — MUST be configured and evaluated through this standard 7-layer contract.

### Layer 1 — Core Attributes
| Field | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Master toggle for the source |
| `handler` | string | *required* | Name of the Zsh query function |
| `weight` | integer | `10` | Base ranking weight (0-100) |
| `kind` | string | `"cmd"` | Semantic kind identifier |
| `max_suggestions` | integer | `20` | Maximum candidate count returned |
| `timeout_ms` | integer | `50` | Maximum allowable execution time |

### Layer 2 — Presentation Attributes
| Field | Type | Default | Description |
|---|---|---|---|
| `label_type` | enum | `"badge"` | `none` \| `text` \| `icon` \| `icon+text` \| `badge` |
| `label_position` | enum | `"right"` | `left` \| `right` \| `before` \| `after` \| `inline` |
| `label_text` | string | source name | Custom text displayed in badge |
| `label_icon` | string | kind default | Custom Nerd Font glyph |
| `label_width` | integer | `0` | Fixed column width (`0` = auto-size) |

### Layer 3 — Appearance Attributes
| Field | Type | Default | Description |
|---|---|---|---|
| `color_mode` | enum | `"theme"` | `theme` \| `kind` \| `custom` \| `auto` |
| `color_custom` | string | `""` | Hex (`#89b4fa`) or ANSI (`fg=8`) override |
| `color_priority` | integer | `0` | Resolution priority when rules conflict |

### Layer 4 — Documentation Attributes
| Field | Type | Default | Description |
|---|---|---|---|
| `docs_enabled` | boolean | `false` | Whether source supplies documentation |
| `docs_source` | enum | `"none"` | `none` \| `builtin` \| `file` \| `url` \| `inline` |
| `docs_path` | string | `""` | Path to documentation files or database |
| `docs_inline` | string | `""` | Static documentation text |
| `docs_show_on` | enum | `"focus"` | `never` \| `focus` \| `preview` \| `always` |

### Layer 5 — Strategy Attributes
| Field | Type | Default | Description |
|---|---|---|---|
| `strategy` | enum | `"primary"` | `primary` \| `fallback` \| `alternative` \| `recovery` \| `dependent` |
| `strategy_target` | string | `""` | Target source referenced by the strategy |

### Layer 6 — Conditional Execution Attributes
| Field | Type | Default | Description |
|---|---|---|---|
| `requires_present` | list[string] | `[]` | List of sources that must be enabled |
| `requires_absent` | list[string] | `[]` | List of sources that must NOT be enabled |
| `requires_success` | list[string] | `[]` | Sources that must have returned results |
| `requires_failed` | list[string] | `[]` | Sources that must have produced zero matches |
| `on_condition_unmet` | enum | `"skip"` | Action: `skip` \| `log` \| `warn` \| `error` |

### Layer 7 — Handler Function Contract
A source handler function MUST strictly obey the following runtime contract:
1. Accepts query string as `$1`.
2. Must initialize `_ghost_results=()` and `_ghost_result_metadata=()`.
3. Appends matched candidates into `_ghost_results` array.
4. Returns exit status `0` on success, non-zero on error.
5. Must complete strictly within `timeout_ms`.
6. Must not write to `stdout` or `stderr` (output is redirected to `/dev/null`).
7. Must declare `emulate -L zsh`.
8. Must not invoke subshells `$(...)` or external process forks.

#### Standard Handler Implementation Template
```zsh
_ghost_source_custom() {
  emulate -L zsh
  local query="$1"
  _ghost_results=()
  _ghost_result_metadata=()

  [[ -z "$query" ]] && return 0

  local item
  for item in "${_my_source_data[@]}"; do
    if [[ "$item" == "$query"* ]]; then
      _ghost_results+=("$item")
      _ghost_result_metadata+=("kind=cmd;source=custom")
      (( ${#_ghost_results} >= 10 )) && break
    fi
  done

  (( ${#_ghost_results} > 0 ))
}
```

### Built-in Sources Baseline

| Source Name | Weight | Kind | Strategy | Purpose |
|---|:---:|:---:|:---:|---|
| `zoxide` | 35 | `path` | `primary` | Frecency directory targets from zoxide (highest in path-context per D7) |
| `completions` | 30 | `cmd` | `primary` | Bridge to zsh-completions `#compdef` definitions (`sources/completions.source.zsh`) |
| `subcommand` | 25 | `cmd` | `primary` | Static CLI tables + dynamic subcommand extraction (`sources/subcommand.source.zsh`) |
| `history` | 25 | `history` | `primary` | Shell command history with frecency scoring |
| `project` | 20 | `project` | `primary` | Contextual commands from project markers |
| `folder` | 15 | `dir` | `primary` | Filesystem path completions |
| `lang_help` | 10 | `cmd` | `primary` | Builtin/keyword documentation hints |
| `sys_comment` | 8 | `cmd` | `primary` | System package/service hints |
| `typo` | 5 | `typo` | `fallback` | Damerau + Levenshtein + keyboard + static map (`static_map`) |

> **توجه در مورد وزن‌ها (D7)**: وزن‌ها بر اساس D7 بازتوزیع شدند: در context مسیر (buffer بعد از `cd `, `ls `, یا ختم به `/`)، zoxide → completions → history. خارج از context مسیر، ترتیب عادی بر اساس وزن.

---

## 7. Strategy Engine

The Strategy Engine coordinates execution order and conditional dependency trees across all sources.

### R13 — Shorthand Strategies
1. **`primary`**: Standard source. Always queried on every keystroke.
2. **`fallback`**: Runs if and only if **all** primary sources produce zero candidates (e.g. `typo`).
3. **`alternative`**: Runs if `strategy_target` is disabled or absent (e.g. `zoxide` runs if `z` is missing).
4. **`recovery`**: Runs if `strategy_target` encountered a runtime failure or timeout.
5. **`dependent`**: Runs if and only if `strategy_target` succeeded and returned matches.

### R14 — Explicit Conditional Rules
Sources can declare granular condition lists in Layer 6:
```toml
[sources.project_scripts]
enabled = true
handler = "_ghost_project_scripts_query"
weight = 35
strategy = "dependent"
strategy_target = "project"
requires_present = ["project"]
requires_success = ["project"]
requires_absent = ["plain_scripts"]
on_condition_unmet = "skip"
```

### R15 — Runtime Source Status Tracking
During query execution, the engine records source execution state into `_ghost_source_status`:
- `success`: Query executed and returned one or more candidates.
- `empty`: Query executed cleanly but found zero matches.
- `timeout`: Handler exceeded `timeout_ms`.
- `crash`: Handler returned non-zero exit code.
- `skipped`: Strategy conditions were not satisfied.
- `disabled`: Source is set to `enabled = false`.

### R16 — Condition Evaluation Pipeline
For each source scheduled in order of descending weight:
1. Verify `enabled == true`.
2. Check `requires_present`: all named sources must be registered and enabled.
3. Check `requires_absent`: all named sources must NOT be enabled.
4. Check `requires_success`: all named sources must have status `success`.
5. Check `requires_failed`: all named sources must have status `empty`, `timeout`, or `crash`.
6. If conditions fail, assign `status = "skipped"` and trigger `on_condition_unmet`.

### R17 — Strategy Expansion Mapping
Shorthand strategies are compiled into explicit condition filters:

| Strategy | Compiles To Condition |
|---|---|
| `primary` | *(no prerequisite conditions)* |
| `fallback` | `requires_failed = ["$ALL_PRIMARY_SOURCES"]` |
| `alternative` (target=X) | `requires_absent = ["X"]` |
| `recovery` (target=X) | `requires_failed = ["X"]` |
| `dependent` (target=X) | `requires_success = ["X"]` |

### R18 — Static Contradiction Analysis
At configuration initialization time, the engine validates dependency graphs:
- Detects circular dependencies (`A depends on B`, `B depends on A`).
- Detects self-contradictions (`requires_present = ["foo"]` and `requires_absent = ["foo"]`).
- Reports warnings cleanly during `ziro doctor` without causing shell crashes.

### R19 — Layer-Aware Execution
- **Ghost Line**: Evaluates primary sources first; queries fallback sources only if primary yields zero results.
- **Focus Mode**: Inherits ranked candidates from Layer 1, maintaining consistent candidate identity across modes.

### 7.2b — Defer-Integrated Lifecycle

When loaded via Defer (recommended):
- **T+0.0ms (Stage 0)**: `ghost.plugin.zsh` sourced by Defer Stage 1. Registers stubs only.
- **T+0.5ms (end of Stage 0)**: Prompt rendered. Defer Stage 5 (precmd) fires.
- **T+0.5ms to T+8.5ms**: Defer Stage 5 dispatches Ghost task at slot=`a`. All core loaded. First compute against empty buffer.
- **T+8.5ms+**: User types. Every keystroke is hot-path compute (<2ms). No lazy-init.
- **T+idle (Stage 2)**: Defer Stage 6 loads auxiliary sources.
- **T+Tab (Stage 3)**: Ghost's Tab widget spawns Rust sidecar. Defer not involved.

Standalone users see §7.2; integrated users see §7.2b.

---

## 8. Complete Configuration Schema

File location: `~/.config/ziro/ghost.conf`  
Format: Standard TOML

```toml
[meta]
config_version = "2.0.0"

[conflicts]
# Per GG-14: same POSTDISPLAY ownership breaks autosuggestions
with = ["zsh-autosuggestions", "zsh-autocomplete", "atuin"]
warn_only = false                  # hard conflict — refuse to install simultaneously

# ─── Ghost Line (Layer 1 — Inline Suggestion) ───
[ghost.line]
enabled = true
color = "auto"                     # auto | theme | fg=8 | #6c6c6c | none
max_length = 200                   # truncate long suggestions

[ghost.preview]
enabled = true
format = "{N} more suggestions (Tab to expand)"
position = "below"                 # below | inline

# ─── Focus Mode (Layer 2 — Interactive Rust Overlay) ───
[ghost.focus]
enabled = true
cycle_key = "^I"                   # Tab — enter + cycle
next_key = "^I"                    # Tab (alias)
prev_key = "^[[Z"                  # Shift-Tab
exit_keys = ["^[", "^G"]           # Esc, Ctrl-G
accept_mode = "typing"             # typing | enter | both (default: typing per D6/D8)
max_items = 10
partial_render = true
mouse_support = true
animation = "slide-fade"
animation_ms = 100
border = "rounded"
show_counter = true
show_preview = true
show_footer = true
only_when_candidates = true        # Tab falls through if no candidates
native_popup = true                # zsh-native fallback if Rust unavailable

# ─── Theme Configuration ───
[theme]
preset = "catppuccin-mocha"        # see theme list below
follow_terminal = true
auto_detect = true
custom_path = ""                   # path to custom TOML theme file

# ─── Rust Companion Binary ───
[rust]
enabled = true                     # sidecar optional per D5
binary = "$GHOST_HOME/bin/ghost-popup"
prewarm = false                    # if true, spawn at Stage 2 instead of first Tab
fallback_native = true
log_to = "$XDG_CACHE_HOME/ziro/ghost/popup.log"
spawn_timeout_ms = 5000
auto_install = "prompt"            # prompt | prebuilt-only | never (per D9)

# ─── Engine Behavior ───
[behavior]
debounce_ms = 0                    # debounce keystrokes (ms)
max_suggestions_total = 50
timeout_total_ms = 200
trigger_on_paste = false
trigger_on_chpwd = true

# ─── Typo Correction ───
[correction]
enabled = true
mode = "suggest"                    # suggest | auto | off
confidence_threshold = 0.7

[correction.levenshtein]
enabled = true
max_distance = 2

[correction.damerau]
enabled = true                     # sl → ls, teh → the

[correction.keyboard]
enabled = true
layout = "qwerty"                  # qwerty | dvorak | colemak | custom:<path>

[correction.static_map]
enabled = true
source = "$GHOST_HOME/config/typo_map.toml"   # user-overridable per D10

# ─── Built-in Sources ───

[sources.history]
enabled = true
weight = 40
kind = "history"
max_suggestions = 20
timeout_ms = 50
label_type = "badge"
label_position = "right"
label_text = "hist"
label_icon = "󰋚"
color_mode = "theme"
docs_enabled = true
docs_source = "builtin"
docs_show_on = "focus"
strategy = "primary"

[sources.project]
enabled = true
weight = 30
kind = "project"
label_type = "badge"
label_position = "right"
label_text = "proj"
label_icon = "◉"
color_mode = "theme"
strategy = "primary"

[sources.zoxide]
enabled = true
weight = 15
kind = "path"
label_type = "icon+text"
label_position = "right"
label_icon = ""
color_mode = "kind"
strategy = "alternative"
strategy_target = "z"
requires_absent = ["z"]

[sources.lang_help]
enabled = true
weight = 15
kind = "cmd"
label_type = "badge"
label_text = "help"
color_mode = "theme"
strategy = "primary"

[sources.sys_comment]
enabled = true
weight = 10
kind = "cmd"
label_type = "text"
strategy = "primary"

[sources.folder]
enabled = true
weight = 10
kind = "dir"
label_type = "icon"
label_icon = ""
color_mode = "kind"
strategy = "primary"

[sources.typo]
enabled = true
weight = 5
kind = "typo"
max_suggestions = 5
timeout_ms = 30
strategy = "fallback"

# ─── Custom User Sources (Example) ───

[sources.my_scripts]
enabled = false
handler = "_ghost_source_my_scripts"
weight = 25
kind = "cmd"
label_type = "badge"
label_position = "left"
label_text = "SCRIPTS"
color_mode = "custom"
color_custom = "#fab387"
docs_enabled = true
docs_source = "inline"
docs_inline = "Personal workflow automations"
strategy = "dependent"
strategy_target = "project"
requires_success = ["project"]
```

---

## 9. Integration with ziro-shell

### R20 — ziro-defer Lifecycle Staging
To guarantee shell bootstrap remains strictly under the **5ms** budget, `ziro-ghost` initialization is divided into four stages:

| Stage | Trigger | Components | Budget |
|:---:|---|---|:---:|
| **Stage 0** | Shell Bootstrap (Defer Stage 1, direct source) | Register ZLE stubs only | < 0.5ms |
| **Stage 1** | Post-prompt (Defer Stage 5, precmd, BEFORE first keystroke) | Full core: version, config, kinds, registry, engine, primary sources | < 8.0ms |
| **Stage 2** | Background idle (Defer Stage 6) | Auxiliary sources, docs cache warmup | background |
| **Stage 3** | On-demand Tab press — **EXTERNAL ZLE widget, NOT a Defer task** | Spawn Rust sidecar (first Tab only), then live in it | < 30ms first, < 2ms subsequent |

In standalone mode (no Defer), Stage 1 fires at `line-pre-redraw` (first keystroke). In Defer-integrated mode, Defer Stage 5 (precmd) loads Ghost BEFORE first keystroke; `_ghost_lazy_init` becomes a no-op stub. Stage 3 is ALWAYS Ghost's own Tab widget; Defer does NOT manage it.

See §7.2b for the full Defer-integrated lifecycle.

### R21 — Plugin Manifest Compliance (Spec 012)
`ziro-ghost` provides a root `ziro-plugin.toml` manifest:
```toml
[plugin]
name = "ziro-ghost"
version = "2.0.0"
description = "LSP-like autocomplete for Zsh"
authors = ["Pakrohk"]
license = "MIT"
repository = "https://github.com/Pakrohk/ziro-ghost"
keywords = ["autocomplete", "suggestions", "zsh", "lsp", "ratatui"]

[plugin.compat]
ziro = ">=1.2.0"
zsh = ">=5.8"
os = ["linux", "macos", "wsl"]

[load]
main = "ghost.plugin.zsh"

[[load.stages]]
id = 0
name = "bootstrap"
trigger = "startup"
budget_ms = 1
files = []

[[load.stages]]
id = 1
name = "core"
trigger = "after-prompt"   # D2: matches Defer Stage 5 (precmd)
budget_ms = 10
files = [
  "core/ghost-version.zsh", "core/ghost-config.zsh", "core/ghost-kinds.zsh",
  "core/ghost-registry.zsh", "core/ghost-strategy.zsh", "core/ghost-core.zsh",
  "sources/history.source.zsh", "sources/project.source.zsh", "sources/zoxide.source.zsh",
  "sources/completions.source.zsh", "sources/subcommand.source.zsh"
]

[[load.stages]]
id = 2
name = "aux"
trigger = "after-prompt"
files = [
  "sources/lang_help.source.zsh", "sources/sys_comment.source.zsh",
  "sources/folder.source.zsh", "sources/typo.source.zsh"
]

[[load.stages]]
id = 3
name = "sidecar"
trigger = "on-demand"
note = "external ZLE widget owned by Ghost; NOT managed by ziro-defer (D2)"
files = ["ui/popup.ui.zsh"]

[depends]
plugins = [
  { name = "ziro-defer", version = ">=2.0.0", required = false, purpose = "staged loading (strongly recommended)" }
]
external = [
  { name = "zoxide", required = false, purpose = "directory suggestions" },
  { name = "fzf", required = false, purpose = "optional native history search" }
]

[provides]
sources = ["zoxide", "completions", "subcommand", "history", "project", "folder", "lang_help", "sys_comment", "typo"]
commands = []
keybindings = { cycle = "^I", prev = "^[[Z", exit_esc = "^[", exit_ctrl_g = "^G" }

[conflicts]
with = ["zsh-autosuggestions", "zsh-autocomplete", "atuin"]
reason = "POSTDISPLAY ownership conflict"
```

### R22 — Declarative Registry Definition (`tools_factory.toml`)
```toml
[[tool]]
name = "ziro-ghost"
type = "plugin"
category = "auto_suggest"
load_method = "clone-source"
load_timing = "defer"
load_order = 6
guard = "none"
source = "Pakrohk/ziro-ghost"
conflicts_with = ["zsh-autosuggestions"]
github = "https://github.com/Pakrohk/ziro-ghost"
description = "LSP-like autocomplete for Zsh (v2.0.0)"
```

### R23 — Standalone Portability
`ziro-ghost` remains completely functional outside of `ziro-shell`:
```zsh
# Pure standalone sourcing
source /path/to/ghost.plugin.zsh

# Znap package manager
znap source Pakrohk/ziro-ghost
```
When running standalone, default configuration paths automatically resolve to `$XDG_CONFIG_HOME/ziro/ghost.conf` or fallback to built-in defaults.

### R23b — Binary Install Flow (D9)

`ziro ghost install-popup` (or first-run auto-prompt) executes:

1. **Detect architecture**: `uname -sm` → map to one of:
   - `x86_64-linux` → `ghost-popup-x86_64-unknown-linux-gnu`
   - `aarch64-linux` → `ghost-popup-aarch64-unknown-linux-gnu`
   - `aarch64-darwin` → `ghost-popup-aarch64-apple-darwin`
   - Otherwise → skip to step 5
2. **Prompt user** (D9):
   ```
   ghost-popup binary needed for interactive popup.
   Install method:
     [1] Download pre-built binary (recommended, ~2MB)
     [2] Compile from source (requires cargo; ~5 min)
     [3] Skip (use Ghost Line only — no popup)
   Choice [1]: _
   ```
3. **Download** from `https://github.com/Pakrohk/ziro-ghost/releases/download/v2.0.0/<binary>.tar.gz`, verify SHA256, extract to `$GHOST_HOME/bin/ghost-popup`, `chmod +x`.
4. **Compile** (if [2]): `cargo build --release --manifest-path $GHOST_HOME/bin/ghost-popup/Cargo.toml`, copy to `$GHOST_HOME/bin/`.
5. **Fallback** (D9): If architecture unsupported OR download fails OR cargo missing, log warning to `$XDG_CACHE_HOME/ziro/ghost/errors.log`, set `[rust] enabled = false` in user config, continue with Ghost Line only. Shell is NEVER blocked.

### R24 — Health Checks & Diagnostics (`ziro doctor`)
Diagnostic output integrated into `ziro doctor --plugins`:
```
ziro-ghost v2.0.0
  ✅ manifest: ziro-plugin.toml valid
  ✅ compatibility: ziro 1.2.0 >= 1.2.0, zsh 5.9 >= 5.8
  ✅ staged loading: stage 0 (<0.5ms), stage 1 ready
  ✅ sources: 7 registered (6 active, 1 fallback)
  ✅ focus mode binary: /home/ali/.ziro/vendor/ziro-ghost/bin/ghost-popup (ratatui 0.28)
  ✅ hot-path performance: 1.84ms avg keystroke latency
```

---

## 10. Performance Budgets & Strict Limits

All timing constraints follow the `min-of-11` benchmarking methodology:

| Metric | Target | Hard Ceiling | Consequence of Breach |
|---|:---:|:---:|---|
| **Shell Startup (Stage 0)** | `< 0.3ms` | `0.5ms` | Blocks merge |
| **Keystroke Latency (Layer 1)** | `< 1.8ms` | `3.0ms` | Blocks merge |
| **Color Resolution** | `< 0.05ms` | `0.2ms` | Mandatory optimization |
| **Source Query (per source)** | `< 5.0ms` | `timeout_ms` | Source skipped at runtime |
| **Focus Mode Spawn to Frame** | `< 25.0ms` | `40.0ms` | Blocks merge |
| **Differential Cell Render** | `< 8.0ms` | `16.0ms` | Animation dropped |
| **Memory Footprint** | `< 4.0MB` | `8.0MB` | Memory audit required |

---

## 11. Acceptance Criteria

### Ghost Line (Layer 1)
- **AC-GL-1**: Typing `git pu` displays `POSTDISPLAY="sh"` in dim gray without screen flicker.
- **AC-GL-2**: `POSTDISPLAY` contains zero ANSI escape sequences or trailing badges.
- **AC-GL-3**: Inline highlight offsets in `region_highlight` accurately span `${#BUFFER}` to `${#BUFFER} + ${#POSTDISPLAY}`.
- **AC-GL-4**: Typing continues seamlessly with zero input blocking or character dropping.
- **AC-GL-5**: Pressing `Esc` clears suggestion and leaves buffer untouched.
- **AC-GL-6**: Buffer edits dynamically invalidate the query cache.
- **AC-GL-7**: `chpwd` event invalidates directory-scoped caches.

### Focus Mode (Layer 2)
- **AC-FM-1**: Pressing `Tab` opens interactive overlay without activating alternate screen (`smcup`).
- **AC-FM-2**: Terminal prompt remains completely visible throughout popup interaction.
- **AC-FM-3**: Overlay displays configured border, item counter, selection cursor, and kind badges.
- **AC-FM-4**: Selection cursor (`▸`) moves up/down with Tab / Shift-Tab and arrow keys.
- **AC-FM-5**: Pressing `Enter` executes the current `BUFFER` in the shell (never accepts a suggestion). Focus mode exits on Enter without modifying `BUFFER`. Acceptance of a candidate occurs via **typing** any character, which sets `BUFFER=<highlighted_suggestion><typed_char>` and exits Focus; or via mouse left-click on a candidate.
- **AC-FM-5b**: Typing a character while in Focus accepts the currently highlighted suggestion and appends the typed character to BUFFER.
- **AC-FM-5c**: Enter always executes BUFFER; if BUFFER is unchanged and doesn't match the highlighted suggestion, the shell attempts to run the literal buffer text.
- **AC-FM-6**: Pressing `Esc` dismisses popup and restores exact pre-Tab buffer and cursor state.
- **AC-FM-7**: Left-clicking a candidate immediately selects and accepts it.
- **AC-FM-8**: Scroll wheel scrolls the list smoothly without leaving visual artifacts.
- **AC-FM-9**: Animation completes within configured `animation_ms`.
- **AC-FM-10**: Differential rendering redrawn only changed terminal cells.
- **AC-FM-11**: Missing Rust binary transparently triggers the Zsh native popup fallback with zero shell crashes.

### Sources & Strategy Engine
- **AC-S-1**: All 7 built-in sources register through the unified registration pipeline.
- **AC-S-2**: Custom sources added via `ghost.conf` execute identically to built-in sources.
- **AC-S-3**: Built-in sources can be disabled by setting `enabled = false` in `ghost.conf`.
- **AC-S-4**: Fallback sources (`typo`) execute if and only if all primary sources produce zero candidates.
- **AC-S-5**: Alternative sources execute if and only if their target source is absent.
- **AC-S-6**: Dependent sources execute if and only if their target source succeeded.
- **AC-S-7**: Contradictory source conditions emit a non-blocking warning.

### Integration & Sovereignty
- **AC-IS-1**: Startup contribution via `ziro-defer` Stage 0 measures `< 0.5ms`.
- **AC-IS-2**: Standalone execution in `zsh -f` succeeds with zero errors.
- **AC-IS-3**: `ziro doctor --plugins` accurately reports ghost registration, binary health, and latency metrics.

---

## 12. Out of Scope

The following capabilities are explicitly outside the scope of `ziro-ghost` v2.0.0:
- **Bash / Fish Shell Support**: Deep integration with Zsh ZLE hooks and data structures is mandatory; other shells are not supported.
- **Remote / Cloud Suggestions**: Network requests, remote APIs, and cloud telemetry are strictly forbidden. All intelligence runs locally.
- **AI / LLM In-Process Inference**: Local or remote neural model execution is excluded.
- **Persistent Background Daemon**: Global background worker daemons (systemd/services) are excluded in favor of a lightweight per-shell sidecar process.
- **Multi-Line Command Expansion**: Suggestions spanning multiple terminal lines are deferred to future revisions.
- **Package Manager / Plugin Store**: Remote source discovery and automatic script downloading are strictly out of scope.

---

## 13. Dependencies

### Runtime Requirements
| Component | Status | Purpose | Minimum Version |
|---|:---:|---|---|
| **Zsh** | Mandatory | Shell runtime & ZLE editor | 5.8+ |
| **`ghost-popup`** | Optional | Layer 2 Focus Mode graphical overlay | 2.0.0 |
| **`fzf`** | Optional | Fuzzy history enrichment | 0.40+ |
| **`zoxide`** | Optional | Directory frecency suggestions | 0.9+ |
| **Python** | Optional | Cold-path project marker analysis | 3.11+ |

### Build Requirements (Focus Mode Binary)
- Rust toolchain: `cargo` and `rustc` (1.75+)
- Target architectures: `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`, `x86_64-apple-darwin`, `aarch64-apple-darwin`.

---

## 14. Migration from v1.0.x

### 14.1 Breaking Changes Summary
1. **Configuration Paradigm**: Deprecated all scattered `zstyle` flags in favor of unified TOML (`ghost.conf`).
2. **Focus Mode Architecture**: Replaced experimental Zsh-only / fzf menus with the high-performance Rust Focus Mode overlay.
3. **Source Contracts**: Unified source signatures; obsolete `print -rl` output streams are eliminated in favor of structured array assignments (`_ghost_results`).

### 14.2 Configuration Migration Mapping

| Legacy v1.0.x Setting | Modern v2.0.0 Setting |
|---|---|
| `zstyle ':znap:ziro-ghost:*' color 'brightblack'` | `[ghost.line] color = "fg=8"` |
| `zstyle ':znap:ziro-ghost:*' popup-key '^G'` | `[ghost.focus] cycle_key = "^I"` (formerly `enter_key = "^I"`) |
| `zstyle ':znap:ziro-ghost:*' max-entries 50` | `[behavior] max_suggestions_total = 50` |
| `zstyle ':znap:ziro-ghost:typo' max-distance 2` | `[correction.levenshtein] max_distance = 2` |

**BREAKING CHANGE 1 — Popup trigger key**: v1.0.x used `^G` (Ctrl-G). v2.0.0 uses `^I` (Tab) for enter/cycle, with `^G` and `^[` (Esc) as exit keys. Users who preferred `^G` as the trigger should reconfigure via `[ghost.focus] cycle_key = "^G"` (then exit keys become `^I` and `^[`).

**BREAKING CHANGE 2 — Accept mechanism**: v1.0.x accepted via Enter. v2.0.0 accepts via TYPING (Enter always executes buffer). The `[ghost.focus] accept_mode = "both"` config preserves v1.0.x behavior if desired.

**Migration script** (`ziro ghost migrate-config`): emits explicit warnings for both breaking changes; does NOT auto-modify user choices.

### 14.3 Automated Migration Command
```bash
ziro ghost migrate-config
```
- Reads existing v1.0.x configuration files.
- Generates valid `~/.config/ziro/ghost.conf`.
- Archives the previous configuration to `~/.config/ziro/ghost.conf.v1.backup`.

---

## 15. Open Architectural Questions

The following questions will be finalized during the detailed implementation phase:
1. **Binary Distribution Model**: Evaluate shipping pre-compiled binaries via GitHub Releases vs automatic compilation during `ziro install`.
2. **UNIX Domain Socket vs Stdin Pipes**: Benchmark potential latency savings of persistent UNIX domain sockets against process spawn overhead.
3. **Advanced Shader FX**: Quantify rendering overhead of complex `tachyonfx` matrix animations on lower-end hardware.
4. **Mouse Coordinate Translation**: Calibrate mouse tracking offsets when the command prompt wraps across multiple lines.

---

## 16. References

### Internal Specifications & Decisions
- `Spec 000`: System Architecture & Layered Model (`.specify/specs/000-architecture/spec.md`)
- `Spec 001`: Plugin Static Analyzer (`.specify/specs/001-plugin-analyzer-layer1/spec.md`)
- `Spec 004`: Shell Bootstrap Layer 0 (`.specify/specs/004-shell-bootstrap/spec.md`)
- `Spec 011`: Zsh Optimization Specification (`.specify/specs/011-zsh-optimization/spec.md`)
- `Spec 012`: Optional Plugin Manifest Format (`.specify/specs/012-plugin-manifest/spec.md`)
- `ADR-006`: Ghost Configuration Architecture (`.specify/decisions/ADR-006-ghost-architecture.md`)
- `ADR-007`: Versioning Policy & Release Tier Discipline (`.specify/decisions/ADR-007-versioning-policy.md`)
- `ADR-011`: Optional Plugin Manifest Format (`.specify/decisions/ADR-011-plugin-manifest.md`)

### External Technical References
- **Neovim `nvim-cmp`**: Extmark virtual text rendering and floating window completion architecture.
- **Ratatui Project**: Dual-buffered terminal user interface library for Rust (`https://github.com/ratatui-org/ratatui`).
- **TachyonFX**: Micro-animation and cell shader framework (`https://github.com/junkdog/tachyonfx`).
- **Zsh Documentation**: Zsh Line Editor (`man zshzle`), Completion System (`man zshcompsys`), and Parameter Expansion (`man zshexpn`).
