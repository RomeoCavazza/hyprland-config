#!/usr/bin/env bash
set -euo pipefail

GAP_HELPER="$HOME/.local/bin/hypr-gap-state.sh"
# shellcheck source=$HOME/.local/bin/hypr-gap-state.sh
# shellcheck disable=SC1091
source "$GAP_HELPER"

THEME="$HOME/.config/rofi/themes/apps-grid.rasi"
WAYBAR_CTL="$HOME/.local/bin/waybar-toggle"
WAYBAR_WAS_RUNNING=0

restore() {
  hypr_restore_rofi_blur_state

  if (( WAYBAR_WAS_RUNNING )); then
    "$WAYBAR_CTL" start
  fi
}
trap restore EXIT INT TERM

prepare_rofi_grid_overlay() {
  hypr_stop_conky_rails_and_restore
  hypr_close_overview
}

hypr_capture_rofi_blur_state
hypr_apply_rofi_blur

hypr_with_ui_lock prepare_rofi_grid_overlay

if "$WAYBAR_CTL" status; then
  WAYBAR_WAS_RUNNING=1
  "$WAYBAR_CTL" stop
fi

rofi -show drun -theme "$THEME"
