#!/usr/bin/env bash
set -euo pipefail

GAP_HELPER="$HOME/.local/bin/hypr-gap-state.sh"
# shellcheck source=$HOME/.local/bin/hypr-gap-state.sh
# shellcheck disable=SC1091
source "$GAP_HELPER"

THEME="$HOME/.config/rofi/themes/apps-grid.rasi"
WAYBAR_CTL="$HOME/.local/bin/waybar-toggle"
WAYBAR_WAS_RUNNING=0

getopt_int() { hyprctl getoption "$1" | awk '/int:/ {print $2; exit}'; }

OLD_SIZE="$(getopt_int decoration:blur:size)"
OLD_PASSES="$(getopt_int decoration:blur:passes)"
OLD_IGNORE="$(getopt_int decoration:blur:ignore_opacity)"

restore() {
  hyprctl keyword decoration:blur:size "$OLD_SIZE" >/dev/null 2>&1 || true
  hyprctl keyword decoration:blur:passes "$OLD_PASSES" >/dev/null 2>&1 || true
  hyprctl keyword decoration:blur:ignore_opacity "$OLD_IGNORE" >/dev/null 2>&1 || true

  if (( WAYBAR_WAS_RUNNING )); then
    "$WAYBAR_CTL" start
  fi
}
trap restore EXIT INT TERM

prepare_rofi_grid_overlay() {
  hypr_stop_conky_rails_and_restore
  hypr_close_overview
}

# Keep the Launchpad blur soft; the global theme already provides the glass.
hyprctl keyword decoration:blur:size 6 >/dev/null 2>&1

hypr_with_ui_lock prepare_rofi_grid_overlay

if "$WAYBAR_CTL" status; then
  WAYBAR_WAS_RUNNING=1
  "$WAYBAR_CTL" stop
fi

# Grid is a global launcher overlay; it hides Waybar but does not push gaps.
rofi -show drun -theme "$THEME"
