#!/usr/bin/env zsh
# ziro-ghost — Popup UI
# Layer: UI · Spec: 009 v0.2.0 (FR-002, R11, R13) · Version: 0.3.0
# Interactive selection menu with fzf / native ZLE fallback and Tab navigation.

typeset -g _ghost_popup_index=1
typeset -ga _ghost_popup_items=()
typeset -gA _ghost_popup_raw_items

# Check if interactive fzf engine is available
ghost_ui_popup_available() {
  emulate -L zsh
  (( $+commands[fzf] )) && return 0
  return 1
}

# Native ZLE popup: step selection (Tab / S-Tab)
ghost_ui_popup_native_step() {
  emulate -L zsh
  local dir="${1:-down}"
  local total=${#_ghost_popup_items}
  (( total == 0 )) && return 0

  if [[ "$dir" == "down" || "$dir" == "tab" ]]; then
    (( _ghost_popup_index = _ghost_popup_index % total + 1 ))
  else
    (( _ghost_popup_index = (_ghost_popup_index - 2 + total) % total + 1 ))
  fi
}

# Native ZLE popup: render menu text
ghost_ui_popup_native_render() {
  emulate -L zsh
  local total=${#_ghost_popup_items}
  (( total == 0 )) && return 0

  local menu="Ghost Candidates (Tab: next · S-Tab: prev · Enter: select · Esc: cancel):"$'\n'
  local i item prefix
  for (( i = 1; i <= total; i++ )); do
    item="${_ghost_popup_items[$i]}"
    if (( i == _ghost_popup_index )); then
      prefix="> $i. "
    else
      prefix="  $i. "
    fi
    menu+="${prefix}${item}"$'\n'
  done

  if [[ -o zle ]]; then
    zle -M "$menu" 2>/dev/null || true
  fi
  print -rn -- "$menu"
}

# Native ZLE popup: select current item and update buffer
ghost_ui_popup_native_select() {
  emulate -L zsh
  local chosen="${_ghost_popup_raw_items[$_ghost_popup_index]:-}"
  if [[ -n "$chosen" ]]; then
    BUFFER="$chosen"
    CURSOR=${#BUFFER}
  fi
  if [[ -o zle ]]; then
    zle -M "" 2>/dev/null || true
    zle redisplay 2>/dev/null || zle -R 2>/dev/null || true
  fi
}

# Native ZLE popup menu runner
ghost_ui_popup_native() {
  emulate -L zsh
  local candidates=("$@")
  (( ${#candidates} == 0 )) && return 0

  _ghost_popup_items=()
  _ghost_popup_raw_items=()
  _ghost_popup_index=1

  local line rest kind text icon count=0
  for line in "${candidates[@]}"; do
    rest="${line#*:}"
    kind="${rest%%:*}"
    text="${rest#*:}"

    if (( ${+functions[ghost_kind_render]} )); then
      ghost_kind_render "$kind" >/dev/null
      icon="$REPLY"
    else
      icon="[$kind]"
    fi

    (( ++count ))
    _ghost_popup_items+=("${icon}  ${text}  │ ${kind}")
    _ghost_popup_raw_items[$count]="$text"
    (( count >= 9 )) && break
  done

  ghost_ui_popup_native_render >/dev/null

  # Non-interactive or test environment guard
  if ! [[ -o zle ]] || ! [[ -t 0 ]]; then
    return 0
  fi

  # Interactive key loop
  local key
  while true; do
    ghost_ui_popup_native_render >/dev/null
    read -k 1 key 2>/dev/null || break

    case "$key" in
      $'\t'|$'\x0e') # Tab or Ctrl-N
        ghost_ui_popup_native_step down
        ;;
      $'\x10')       # Ctrl-P
        ghost_ui_popup_native_step up
        ;;
      $'\r'|$'\n')   # Enter
        ghost_ui_popup_native_select
        break
        ;;
      $'\x1b')       # Esc / Alt sequence
        local next_key
        read -t 0.1 -k 2 next_key 2>/dev/null || true
        if [[ "$next_key" == "[Z" ]]; then
          # Shift-Tab (Backtab)
          ghost_ui_popup_native_step up
          continue
        fi
        # Esc cancel
        zle -M "" 2>/dev/null || true
        zle -R 2>/dev/null || true
        break
        ;;
      [1-9])         # Numeric quick selection
        if (( key <= ${#_ghost_popup_items} )); then
          _ghost_popup_index=$key
          ghost_ui_popup_native_select
          break
        fi
        ;;
      $'\x03'|$'\x07') # Ctrl-C or Ctrl-G
        zle -M "" 2>/dev/null || true
        zle -R 2>/dev/null || true
        break
        ;;
      *)
        # Unknown key closes popup and passes through
        zle -M "" 2>/dev/null || true
        zle -R 2>/dev/null || true
        break
        ;;
    esac
  done
}

# Open interactive popup with candidate lines (fzf or native fallback)
ghost_ui_popup_open() {
  emulate -L zsh
  local candidates=("$@")
  (( ${#candidates} == 0 )) && return 0

  if ! ghost_ui_popup_available; then
    ghost_ui_popup_native "${candidates[@]}"
    return 0
  fi

  # Format candidate list with kind icons and tab-delimited raw text
  local formatted=()
  local line rest kind text icon
  for line in "${candidates[@]}"; do
    rest="${line#*:}"
    kind="${rest%%:*}"
    text="${rest#*:}"

    if (( ${+functions[ghost_kind_render]} )); then
      ghost_kind_render "$kind" >/dev/null
      icon="$REPLY"
    else
      icon="[$kind]"
    fi

    formatted+=("${icon}  ${text}  │ ${kind} │ history"$'\t'"${text}")
  done

  # Run fzf with Tab/S-Tab navigation and clear instructions
  local selected
  selected="$(
    print -rl -- "${formatted[@]}" | fzf \
      --height=40% \
      --reverse \
      --prompt="Ghost> " \
      --header="Tab: next · S-Tab: prev · Enter: select · Esc: cancel" \
      --bind="tab:down,btab:up" \
      --with-nth=1 \
      --delimiter=$'\t' \
      --ansi 2>/dev/null
  )"

  if [[ -n "$selected" ]]; then
    # Extract exact raw text after the tab character (POP-2)
    local chosen="${selected#*$'\t'}"
    if [[ -n "$chosen" ]]; then
      BUFFER="$chosen"
      CURSOR=${#BUFFER}
    fi
  fi

  if [[ -o zle ]]; then
    zle redisplay 2>/dev/null || zle -R 2>/dev/null || true
  fi
}

# Close / dismiss popup
ghost_ui_popup_close() {
  emulate -L zsh
  if [[ -o zle ]]; then
    zle -M "" 2>/dev/null || true
    zle -R 2>/dev/null || true
  fi
}

# Register popup UI in IOP registry
if (( ${+functions[ghost_register_ui]} )); then
  ghost_register_ui popup \
    --intent "render interactive floating selection menu via fzf with native ZLE fallback" \
    --handler ghost_ui_popup_open
fi
