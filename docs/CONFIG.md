# Configuration Reference

> Comprehensive guide for configuring Ziro Ghost via TOML or zstyle.

---

## 1. Configuration File Locations

Ghost searches for configuration in the following order:

1. `${XDG_CONFIG_HOME:-$HOME/.config}/ziro/ghost.conf`
2. `${ZIRO_CONFIG:-$HOME/.config/ziro}/ghost.conf`
3. `zstyle` directives in `.zshrc`
4. Compiled internal defaults

---

## 2. TOML Configuration Example

```toml
# ~/.config/ziro/ghost.conf

[ui]
# Enable Nerd Font glyphs (false falls back to ASCII icons)
nerd_font = true

# Visual color scheme
color_scheme = "auto"

# Kind overrides
[ui.kinds.git]
color = "green"

[ui.kinds.cmd]
color = "blue"

# Source weights and enabling
[sources]
history.enabled = true
history.weight = 40

project.enabled = true
project.weight = 30
```

---

## 3. zstyle Configuration Fallback

For minimal `.zshrc` setups without external TOML files, standard `zstyle` parameters are supported:

```zsh
# Set Nerd Font preference
zstyle ':ghost:ui-nerd-font' value 'true'

# Set history source weight
zstyle ':ghost:sources-history-weight' value '50'
```
