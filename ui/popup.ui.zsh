#!/usr/bin/env zsh
# ziro-ghost — Popup UI
# Layer: UI · Spec: 009 v0.2.0 (FR-002, R11, R13) · Version: 0.2.0
# Interactive selection menu with fzf / native fallback.

# Check if interactive popup engine is available
ghost_ui_popup_available() {
  # 1. fzf in commands
  (( $+commands[fzf] )) && return 0
  return 1
}

# Open interactive popup with candidate lines
ghost_ui_popup_open() {
  local candidates=("$@")
  (( ${#candidates} == 0 )) && return 0

  if ! ghost_ui_popup_available; then
    # Fallback if no fzf
    return 1
  fi

  # Format candidate list with kind icons
  local formatted=()
  local line score kind text icon
  for line in "${candidates[@]}"; do
    score="${line%%:*}"
    local rest="${line#*:}"
    kind="${rest%%:*}"
    text="${rest#*:}"

    if (( ${+functions[ghost_kind_render]} )); then
      icon="$(ghost_kind_render "$kind")"
    else
      icon="[$kind]"
    fi

    formatted+=("$(printf "%-3s %-45s [%s]" "$icon" "$text" "$kind")")
  done

  # Run fzf in popup / height mode
  local selected
  selected="$(
    print -rl -- "${formatted[@]}" | fzf \
      --height=40% \
      --reverse \
      --prompt="Ghost> " \
      --header="Tab: navigate · Enter: select · Esc: cancel" \
      --ansi 2>/dev/null
  )"

  if [[ -n "$selected" ]]; then
    # Extract text (between icon and trailing bracket)
    local chosen="${selected#* }"
    chosen="${chosen%%[[:space:]]\[*}"
    chosen="${chosen#"${chosen%%[![:space:]]*}"}"
    chosen="${chosen%"${chosen##*[![:space:]]}"}"
    if [[ -n "$chosen" ]]; then
      BUFFER="$chosen"
      CURSOR=${#BUFFER}
    fi
  fi

  zle -R 2>/dev/null || true
}

# Close / dismiss popup
ghost_ui_popup_close() {
  return 0
}

# Register popup UI in IOP registry
if (( ${+functions[ghost_register_ui]} )); then
  ghost_register_ui popup \
    --intent "render interactive floating selection menu via fzf" \
    --handler ghost_ui_popup_open
fi
