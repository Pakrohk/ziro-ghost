# Ghost v2.0.1 — Two-Layer Autosuggest Architecture

**Ghost is now a plugin runtime, not just a plugin.** Built on Intent-Oriented Programming (IOP) — the same architectural paradigm as the Evoid reference runtime.

## What's New

- **Intent Bus**: Core modules communicate via structured Intent envelopes (`ghost_protocol`) over stdio NDJSON streams rather than direct procedural calls.
- **Rust Focus Mode**: Dedicated interactive TUI popup binary (`ghost-popup`, 613KB stripped) powered by Ratatui and Tachyonfx.
- **Zero Input Lag**: Suggest hot-path latency strictly `<1.0ms` median with zero forks.
- **6 Cache Types**: Asynchronous caching for `history`, `project`, `eval`, `completions`, `zoxide`, and `stats`.
- **Declarative Manifest (`ziro-plugin.toml`)**: Follows Spec 012 and External Tools Observability Protocol v1.
- **Observability**: Metrics stream (`metrics.jsonl`), `ghost stats` CLI with P50/P95/P99 latency calculations, and `ghost health` diagnostic checks.
- **MCP Endpoint**: `ghost-popup mcp` speaks JSON-RPC 2.0 over stdio for AI agent discovery and interaction.

## Milestones (M1–M10)

- **M1**: Rust workspace setup + Intent Protocol definitions (`ghost-protocol`).
- **M2**: Zsh Intent Bus coprocess + Ghost Line subscription adapter.
- **M3**: Focus Mode popup TUI (`ghost-popup`).
- **M4**: Cache Intent Service with 6 pluggable cache stores.
- **M5**: Intent Gateway with Kahn topological sort dependency resolver.
- **M6**: Everything-async modular sources (`history`, `typo`, `project`, `zoxide`).
- **M7**: Deferred cache warmup using `ziro-defer` stage 5.
- **M8**: Observability engine (`metrics.jsonl`, `ghost stats`, `ghost doctor`).
- **M9**: Declarative plugin manifest + Protocol v1 health integration.
- **M10**: Release packaging, multi-arch CI matrix, standalone `install.sh`, and MCP server mode.

## Binaries

- `ghost-popup-linux-x86_64` — Linux x86_64
- `ghost-popup-linux-aarch64` — Linux ARM64
- `ghost-popup-darwin-x86_64` — macOS Intel
- `ghost-popup-darwin-arm64` — macOS Apple Silicon

Each binary is compiled with `opt-level = "z"`, fat LTO, stripped symbols, and panic abort (`<2.5MB` strict budget). `SHA256SUMS` included.

## Compatibility

- **ziro-shell v1.2.10+**: Full observability support (`ziro stats ghost`, `ziro health ghost`).
- **ziro-shell v1.3.0+**: Native runtime integration.
- **Standalone**: Fully functional without ziro-shell via `ghost.plugin.zsh`.

## Installation

### With ziro-shell (Recommended)
```bash
ziro plugin add Pakrohk/ziro-ghost
```

### Standalone (One-Liner)
```bash
curl -fsSL https://raw.githubusercontent.com/Pakrohk/ziro-ghost/v2.0.1/install.sh | bash
```

Add to your `~/.zshrc`:
```bash
source "$HOME/.local/share/ziro/vendor/Pakrohk/ziro-ghost/ghost.plugin.zsh" # or custom clone path
```
