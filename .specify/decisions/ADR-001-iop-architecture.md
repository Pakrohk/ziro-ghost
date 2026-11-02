# ADR-001: Intent-Oriented Programming (EVOID IOP) Architecture for Ghost v2.0.0

- **Status**: Accepted
- **Date**: 2026-11-02
- **Author**: Pakrohk
- **Scope**: `ziro-ghost v2.0.0`
- **Spec Reference**: Spec 009 & Spec 010 (EVOID IOP)

## Context
`ziro-ghost` v1.x was built as a monolithic inline suggestion script. As part of modernizing towards a Two-Layer architecture with an out-of-process Rust Focus Mode TUI and multiple pluggable suggestion sources, tight coupling between components risks shell freezes, latency degradation, and complex state management.

## Decision
Adopt the EVOID Intent-Oriented Programming (IOP) architecture:
1. **Gateway**: `ziro` CLI and Zsh ZLE frontend.
2. **Intent Bus**: Standardized NDJSON streaming over stdio connecting in-process Zsh modules and out-of-process Rust sidecars.
3. **Intent Envelope**: Every message is an Intent `{id, name, level, metadata}` returning an `IntentResult {id, status, value, error}`.
4. **Intent Levels**:
   - `ephemeral`: Latency-critical keystroke queries; validated only (timeout budget: 5s, target <3ms).
   - `standard`: Interactive UI state and cache updates; validated and authorized (timeout budget: 10s, target <50ms).
   - `critical`: Security and configuration operations; validated, authorized, audited, and protected (timeout budget: 30s).
5. **Decoupled Namespaces**: Each module owns a dedicated namespace (`ghost.suggest.*`, `ghost.popup.*`, `ghost.cache.*`, `ghost.strategy.*`). No module calls another directly.
6. **Infrastructure as Plugins**: Caching, persistent storage, and suggestion sources operate as subscribers to the Intent Bus.

## Consequences
- **Positive**: Complete fault isolation; a slow or crashing source/binary cannot deadlock the user's interactive shell.
- **Positive**: Strict binary size and latency controls enforced per intent level.
- **Negative**: Minor serialization overhead across stdio streams (mitigated by compact NDJSON and Serde).
