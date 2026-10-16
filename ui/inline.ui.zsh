#!/usr/bin/env zsh
# ziro-ghost — Inline UI (POSTDISPLAY)
# Layer: UI · Spec: 009 v0.2.0 (FR-001, R11) · Version: 0.2.0
# Native ZLE inline ghost text rendering with semantic kind tags.

# Render inline ghost completion
ghost_ui_inline_render() {
  local suggestion="$1"
  local kind="${2:-cmd}"

  [[ -z "$suggestion" ]] && { ghost_ui_inline_clear; return 0; }

  # Calculate suffix beyond current buffer
  local suffix=""
  if [[ "$suggestion" == "$BUFFER"* ]]; then
    suffix="${suggestion#$BUFFER}"
  else
    # If not prefix (e.g. fuzzy match), don't break cursor position in inline mode
    ghost_ui_inline_clear
    return 0
  fi

  [[ -z "$suffix" ]] && { ghost_ui_inline_clear; return 0; }

  # Retrieve formatted kind icon and label
  local kind_badge=""
  if (( ${+functions[ghost_kind_render]} )); then
    local icon
    icon="$(ghost_kind_render "$kind")"
    kind_badge=" ${icon}"
  fi

  # Apply subtle formatting to POSTDISPLAY
  typeset -g POSTDISPLAY="${suffix}${kind_badge}"
}

# Clear inline ghost text
ghost_ui_inline_clear() {
  typeset -g POSTDISPLAY=""
}

# Register inline UI in IOP registry
if (( ${+functions[ghost_register_ui]} )); then
  ghost_register_ui inline \
    --intent "render inline ghost text using native ZLE POSTDISPLAY" \
    --handler ghost_ui_inline_render
fi
