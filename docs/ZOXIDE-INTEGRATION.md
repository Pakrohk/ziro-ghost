# Zoxide Integration

## Overview

Ghost v0.9.0 seamlessly integrates with [zoxide](https://github.com/ajeetdsouza/zoxide), a smarter `cd` command that tracks your most frequently and recently accessed directories.

The integration provides two capabilities:
1. **Zoxide Suggestion Source**: Proposes directories from your zoxide database when typing `cd <query>`.
2. **`j` (Jump) Helper Shortcut**: Fast directory jumping with interactive `fzf` preview.

## Zoxide Suggestion Source (`sources/zoxide.source.zsh`)

- **Weight**: 15 (relative to history 40, project 30, subcommand 10).
- **Kind**: `path` (styled with path color and icon).
- **Trigger**: Activates when the command line begins with `cd ` or is bare `cd`.
- **Query Strategy**: Reads top-ranked directories from `zoxide query -ls` matching the typed argument.

### Example

When typing:
```zsh
cd proj
```
Ghost inline suggestion and popup menu (`Ctrl-G`) propose:
```
󰉋  cd /home/ali/Projects/ziro-ghost  │ path │ zoxide
```

## Helper Shortcut: `j` (Jump)

Ghost bundles the `j` helper function in `lib/helpers.zsh`:

```zsh
# Interactive jump with directory file preview:
j

# Direct jump matching a term:
j ghost
```

### Features

- When `fzf` is available, `j` opens a fuzzy search window showing your zoxide directory history with a real-time `ls -la` directory preview pane.
- When `fzf` is not available, `j` gracefully falls back to jumping to the best zoxide query match.
- If zoxide is not installed, `j` prints a friendly warning without crashing.
