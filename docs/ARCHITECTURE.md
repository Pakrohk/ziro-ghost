# Ziro Ghost Architecture

> Design principles, modular components, and IOP registry specification.

---

## 1. Architectural Principles

Ghost is architected around two core foundations:

1. **Constitution Principle XIV (Plugin Sovereignty)**:
   Ghost contains zero couplings to any specific framework or wrapper. It can run independently in vanilla Zsh with no assumptions about `~/.ziro/` or Python.
2. **Intent-Oriented Programming (IOP)**:
   Components declare their **intent**, capabilities, and metadata (such as weights, kinds, and handlers) to a central in-memory registry rather than relying on hardcoded calls or rigid class hierarchies.

---

## 2. Directory Layout

```text
ziro-ghost/
├── ghost.plugin.zsh          # Standalone entry point & boot orchestrator
├── core/
│   ├── ghost-kinds.zsh       # Semantic kind system (icons, colors, fallbacks)
│   ├── ghost-registry.zsh    # Central IOP module registry
│   ├── ghost-config.zsh      # TOML config & zstyle fallback reader
│   └── ghost-core.zsh        # ZLE lifecycle, hooks, and widget definitions
├── engine/
│   ├── matcher.zsh           # Matching algorithms (prefix, fuzzy)
│   └── comparator.zsh        # Ranking comparator & scoring
├── ui/
│   ├── inline.ui.zsh         # Inline POSTDISPLAY ghost text renderer
│   └── popup.ui.zsh          # Interactive selection popup menu
├── sources/
│   └── history.source.zsh    # History-based suggestion provider
├── kinds/                    # Per-kind specialized formatters
├── lib/                      # Optional cold-path enrichment tools
├── tests/                    # Standalone test suites
└── docs/                     # Documentation & user guides
```

---

## 3. Component Interaction Flow

```text
User Types in BUFFER
         │
         ▼
 ZLE line-pre-redraw Hook
         │
         ▼
 _ghost_compute()
   ├── Query Registered Sources (history, project, etc.)
   ├── Filter via engine/matcher.zsh (prefix, fuzzy)
   └── Score & Sort via engine/comparator.zsh
         │
         ▼
 Top Candidate Selected
         │
         ▼
 ui/inline.ui.zsh (Renders suggestion + Kind Icon into POSTDISPLAY)
```

---

## 4. The IOP Module Registry

Ghost provides dynamic registration functions for all subsystem layers:

- `ghost_register_source <name> --intent <desc> --handler <fn> --weight <num> --kind <kind> --enabled <bool>`
- `ghost_register_ui <name> --intent <desc> --handler <fn>`
- `ghost_register_matcher <name> --intent <desc> --handler <fn>`
- `ghost_register_comparator <name> --intent <desc> --handler <fn>`
- `ghost_kind_register <name> --icon <nerd> --ascii-icon <ascii> --color <color> --label <label>`

This open architecture enables third-party extensions to add custom data sources (e.g. AI completions, cloud CLI caches, team bookmarks) with zero modifications to the core engine.
