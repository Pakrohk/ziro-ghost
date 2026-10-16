#!/usr/bin/env zsh
# ziro-ghost — Kind system
# Layer: Core · Spec: 009 v0.2.0 (R11)
# Manages semantic icons, labels, colors, and Nerd Font fallbacks.

# Guard: typeset associative structures
typeset -gA _ghost_kinds_icon
typeset -gA _ghost_kinds_ascii
typeset -gA _ghost_kinds_color
typeset -gA _ghost_kinds_label

# ANSI color codes
typeset -gA _ghost_ansi_colors=(
  red     $'\e[31m'
  green   $'\e[32m'
  yellow  $'\e[33m'
  blue    $'\e[34m'
  magenta $'\e[35m'
  cyan    $'\e[36m'
  white   $'\e[37m'
  gray    $'\e[90m'
  reset   $'\e[0m'
)

# Register or update a suggestion kind
ghost_kind_register() {
  emulate -L zsh
  local name="$1"
  shift

  local icon=""
  local ascii=""
  local color="white"
  local label="$name"

  while (( $# )); do
    case "$1" in
      --icon)       icon="$2"; shift 2 ;;
      --ascii-icon) ascii="$2"; shift 2 ;;
      --color)      color="$2"; shift 2 ;;
      --label)      label="$2"; shift 2 ;;
      *)            shift ;;
    esac
  done

  _ghost_kinds_icon[$name]="${icon:-$name}"
  _ghost_kinds_ascii[$name]="${ascii:-$name}"
  _ghost_kinds_color[$name]="$color"
  _ghost_kinds_label[$name]="$label"
}

# Check if Nerd Font is active
ghost_has_nerd_font() {
  emulate -L zsh
  if (( ${+ZIRO_NERD_FONT} )) && (( ZIRO_NERD_FONT == 1 )); then
    return 0
  fi
  if [[ "${GHOST_NERD_FONT:-}" == "1" || "${GHOST_NERD_FONT:-}" == "true" ]]; then
    return 0
  fi
  return 1
}

# Retrieve raw metadata: icon color label
ghost_kind_get() {
  emulate -L zsh
  local name="${1:-cmd}"
  local icon
  if ghost_has_nerd_font; then
    icon="${_ghost_kinds_icon[$name]:-${_ghost_kinds_ascii[$name]:-$name}}"
  else
    icon="${_ghost_kinds_ascii[$name]:-$name}"
  fi
  local color="${_ghost_kinds_color[$name]:-white}"
  local label="${_ghost_kinds_label[$name]:-$name}"

  print -r -- "$icon" "$color" "$label"
}

# Render formatted kind with color escapes
ghost_kind_render() {
  emulate -L zsh
  local name="${1:-cmd}"
  local icon
  if ghost_has_nerd_font; then
    icon="${_ghost_kinds_icon[$name]:-${_ghost_kinds_ascii[$name]:-$name}}"
  else
    icon="${_ghost_kinds_ascii[$name]:-$name}"
  fi

  # Respect NO_COLOR standard (https://no-color.org)
  if [[ -n "${NO_COLOR:-}" ]]; then
    REPLY="$icon"
    print -rn -- "$icon"
    return 0
  fi

  local color_name="${_ghost_kinds_color[$name]:-white}"
  local c_code="${_ghost_ansi_colors[$color_name]:-${_ghost_ansi_colors[white]}}"
  local reset="${_ghost_ansi_colors[reset]}"

  REPLY="${c_code}${icon}${reset}"
  print -rn -- "${c_code}${icon}${reset}"
}

# Return ASCII fallback for a kind
ghost_kind_fallback() {
  emulate -L zsh
  local name="${1:-cmd}"
  print -r -- "${_ghost_kinds_ascii[$name]:-$name}"
}

# Initialize 12 default kinds per Spec 009 v0.2.0
_ghost_kinds_init() {
  emulate -L zsh
  ghost_kind_register git      --icon "󰊢" --ascii-icon "*"  --color green   --label "git"
  ghost_kind_register cmd      --icon "" --ascii-icon "$"  --color blue    --label "cmd"
  ghost_kind_register path     --icon "󰉋" --ascii-icon "~"  --color yellow  --label "path"
  ghost_kind_register dir      --icon "" --ascii-icon "/"  --color cyan    --label "dir"
  ghost_kind_register file     --icon "󰈔" --ascii-icon "#"  --color white   --label "file"
  ghost_kind_register alias    --icon "󰌷" --ascii-icon "@"  --color magenta --label "alias"
  ghost_kind_register var      --icon "$" --ascii-icon "$"  --color red     --label "var"
  ghost_kind_register func     --icon "󰊕" --ascii-icon "ƒ"  --color cyan    --label "func"
  ghost_kind_register history  --icon "󰋚" --ascii-icon "h"  --color gray    --label "hist"
  ghost_kind_register project  --icon "◉" --ascii-icon "p"  --color blue    --label "proj"
  ghost_kind_register typo     --icon "🔧" --ascii-icon "!"  --color red     --label "typo"
  ghost_kind_register snippet  --icon "󰩫" --ascii-icon "&"  --color magenta --label "snip"
}

_ghost_kinds_init
